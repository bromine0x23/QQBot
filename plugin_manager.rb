# -*- coding: utf-8 -*-

require 'set'
require 'yaml'
require 'sqlite3'

require_relative 'webqq/webqq'

#noinspection RubyTooManyMethodsInspection
class PluginManager
	FILE_RULES = 'plugin_rules.yaml'

	DB_FILE = 'receive_data.db'

	SQL_CREATE_TABLE = <<SQL
CREATE TABLE IF NOT EXISTS "receive" (
	"id"        INTEGER PRIMARY KEY AUTOINCREMENT,
	"poll_type" TEXT,
	"value"     TEXT
)
SQL

	SQL_INSERT_DATA = <<SQL
INSERT OR IGNORE INTO "receive" ("poll_type", "value") VALUES (?, ?)
SQL

	attr_reader :plugins

	# @param [WebQQProtocol::Client] client
	# @param [Logger] logger
	def initialize(qqbot, client, logger)
		@qqbot = qqbot
		@client = client
		@logger = logger
		@plugins = []
		@db = SQLite3::Database.open DB_FILE
		@db.transaction do |db|
			db.execute SQL_CREATE_TABLE
		end
	end

	# @param [Hash] data
	def on_event(data)
		poll_type, value = data['poll_type'], data['value']
		event     = :"on_#{poll_type}"

		@db.transaction do |db|
			db.execute(SQL_INSERT_DATA, poll_type, JSON.fast_generate(value))
		end

		send(event, value)
	end

	def load_plugins
		init_plugin_list
		load_plugin_file
		registry_plugins
		sort_plugin_list
		load_rules
		log('插件载入完毕')
		true
	end

	def unload_plugins
		exception_at = nil
		@plugins.each_with_index do |plugin, index|
			unless unload_plugin(plugin)
				exception_at = index
				break
			end
		end

		if exception_at
			recover_plugins(exception_at)
			return false
		end

		remove_plugin_classes
		log('插件卸载完毕')
		true
	end

	# @return [Integer]
	def reload_plugins
		return -1 unless unload_plugins
		load_plugins
		log('插件重载完毕')
		@plugins.size
	end

	# @return [PluginBase]
	def plugin(plugin_name)
		@plugins.find{ |plugin| plugin.name == plugin_name }
	end

	# @param [WebQQProtocol::Group] group
	# @param [WebQQProtocol::GroupMember] member
	def group_manager?(group, member)
		@rules[group.number][:group_managers].include?(member.number)
	end

	# @param [WebQQProtocol::Group] group
	# @param [WebQQProtocol::GroupMember] member
	# @param [PluginBase] plugin
	def enable_plugin(group, member, plugin)
		@rules[group.number][:forbidden_list].delete(plugin.class.name) if group_manager?(group, member)
		save_rules
	end

	# @param [WebQQProtocol::Group] group
	# @param [WebQQProtocol::GroupMember] member
	# @param [PluginBase] plugin
	def disable_plugin(group, member, plugin)
		@rules[group.number][:forbidden_list].add(plugin.class.name) if group_manager?(group, member)
		save_rules
	end

	# @param [WebQQProtocol::Group] group
	def forbidden?(plugin_name, group)
		@rules[group.number][:forbidden_list].include? plugin_name
	end

	# @param [WebQQProtocol::Group] group
	def filtered_plugins(group)
		@plugins.select { |plugin| not forbidden?(plugin.class.name, group) }
	end

	private

	def init_plugin_list
		@plugins = []
		@message_plugins = []
		@group_message_plugins = []
		@system_message_plugins = []
	end

	#noinspection RubyResolve
	def load_plugin_file
		load './plugin.rb'
		Dir.glob('plugins/plugin?*.rb') { |file_name| load file_name }
	end

	# @param [PluginBase] plugin
	def registry_plugin(plugin)
		@message_plugins        << plugin if plugin.respond_to? :on_message
		@group_message_plugins  << plugin if plugin.respond_to? :on_group_message
		@system_message_plugins << plugin if plugin.respond_to? :on_system_message
	end

	def registry_plugins
		PluginBase.instance_plugins.each do |plugin_class|
			begin
				plugin = plugin_class.new(@qqbot, @client, @logger)
				plugin.on_load
				@plugins << plugin
				registry_plugin(plugin)
			rescue Exception => ex
				log(<<LOG, Logger::ERROR)
载入插件 #{plugin_class::NAME} 时发生异常：#{ex}
调用栈：
#{ex.backtrace.join("\n")}
LOG
			end
		end

	end

	def sort_plugin_list
		[@plugins, @message_plugins, @group_message_plugins, @system_message_plugins].each do |plugin_list|
			plugin_list.sort_by! { |plugin| -plugin.priority }
		end
	end

	def recover_plugins(exception_at)
		0.upto(exception_at) do |i|
			@plugins[i].on_load
		end
	end

	def remove_plugin_classes
		PluginBase.plugins.each { |plugin| Object.send(:remove_const, plugin.name.to_sym) }
		Object.send(:remove_const, :PluginBase)
	end

	# @param [PluginBase] plugin
	def unload_plugin(plugin)
		begin
			plugin.on_unload
		rescue Exception => ex
			log(<<LOG, Logger::ERROR)
卸载插件 #{plugin.name} 时发生异常：#{ex}
调用栈：
#{ex.backtrace.join("\n")}
LOG
			return false
		end
		true
	end

	def load_rules
		@rules = YAML.load_file FILE_RULES
		@rules.default_proc = proc do |hash, key|
			hash[key] = {
				forbidden_list: Set.new,
				administrators: Set.new,
				managers: Set.new,
			}
		end
	end

	def save_rules
		File.open(FILE_RULES, 'w') do |file|
			file << YAML.dump(@rules)
		end
	end


	# @param [Hash] value
	def on_message(value)
		sender, = @client.friend_by_uin(value['from_uin'])
		message = QQBot.message(value['content'])
		time = Time.at(value['time'])
		@message_plugins.each do |plugin|
			begin
				return if plugin.on_message(sender, message, time)
			rescue Exception => ex
				log(<<LOG, Logger::ERROR)
执行插件 #{plugin.name} 时发生异常：[#{ex}] #{ex.message}
调用栈：
#{ex.backtrace.join("\n")}
LOG
			end
		end
	end

	# @param [Hash] value
	def on_group_message(value)
		from = @client.group_by_uin(value['from_uin'])
		sender = from.member_by_uin(value['send_uin'])
		message = QQBot.message(value['content'])
		time = Time.at(value['time'])
		@group_message_plugins.each do |plugin|
			next if forbidden?(plugin.class.name, from)
			begin
				return if plugin.on_group_message(from, sender, message, time)
			rescue Exception => ex
				log(<<LOG, Logger::ERROR)
执行插件 #{plugin.name} 时发生异常：[#{ex.class}] #{ex.message}
调用栈：
#{ex.backtrace.join("\n")}
LOG
			end
		end
	end

	def method_missing(symbol, *args)
		if /^on_/ =~ symbol
			@plugins.each do |plugin|
				plugin.send(symbol, args[0]) if plugin.respond_to? symbol
			end
		end
	end

	def log(message, level = Logger::INFO)
		@logger.log(level, message, self.class.name)
	end
end