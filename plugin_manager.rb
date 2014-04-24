# -*- coding: utf-8 -*-

require 'set'
require 'yaml'

#noinspection RubyTooManyMethodsInspection
class PluginManager
	FILE_RULES = 'plugin_rules.yaml'
	KEY_POLL_TYPE = 'poll_type'
	KEY_VALUE = 'value'
	KEY_FROM_UIN = 'from_uin'
	KEY_SEND_UIN = 'send_uin'
	KEY_CONTENT  = 'content'
	KEY_TIME     = 'time'

	attr_reader :plugins

	def initialize(qqbot, logger)
		@qqbot  = qqbot
		@logger = logger
		@plugins = []
	end

	def on_event(data)
		poll_type = data[KEY_POLL_TYPE]
		value     = data[KEY_VALUE]
		event     = :"on_#{poll_type}"
		send(event, value)
	end

	def load_plugins
		init_plugin_list
		load_plugin_file
		registry_plugins
		sort_plugin_list
		load_rules
		log('插件载入完毕', Logger::DEBUG) if $-d
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
		log('插件卸载完毕', Logger::DEBUG) if $-d
		true
	end

	# @return [Integer]
	def reload_plugins
		return -1 unless unload_plugins
		load_plugins
		log('插件重载完毕', Logger::DEBUG) if $-d
		@plugins.size
	end

	# @return [PluginBase]
	def plugin(plugin_name)
		@plugins.find{ |plugin| plugin.name == plugin_name }
	end

	# @param [WebQQProtocol::QQGroup] group
	# @param [WebQQProtocol::QQGroupMember] member
	def group_manager?(group, member)
		@rules[group.number][:group_managers].include?(member.number)
	end

	# @param [WebQQProtocol::QQGroup] group
	# @param [WebQQProtocol::QQGroupMember] member
	# @param [PluginBase] plugin
	def enable_plugin(group, member, plugin)
		@rules[group.number][:forbidden_list].delete(plugin.class.name) if group_manager?(group, member)
		save_rules
	end

	# @param [WebQQProtocol::QQGroup] group
	# @param [WebQQProtocol::QQGroupMember] member
	# @param [PluginBase] plugin
	def disable_plugin(group, member, plugin)
		@rules[group.number][:forbidden_list].add(plugin.class.name) if group_manager?(group, member)
		save_rules
	end

	# @param [WebQQProtocol::QQGroup] group
	def forbidden?(plugin_name, group)
		@rules[group.number][:forbidden_list].include? plugin_name
	end

	# @param [WebQQProtocol::QQGroup] group
	def filtered_plugins(group)
		@plugins.select do |plugin|
			not forbidden?(plugin.class.name, group)
		end
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

	def registry_plugin(plugin)
		@message_plugins        << plugin if plugin.respond_to? :on_message
		@group_message_plugins  << plugin if plugin.respond_to? :on_group_message
		@system_message_plugins << plugin if plugin.respond_to? :on_system_message
	end

	def registry_plugins
		PluginBase.instance_plugins.each do |plugin_class|
			begin
				plugin = plugin_class.new(@qqbot, @logger)
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

	def on_message(value)
		sender = @qqbot.friend(value[KEY_FROM_UIN])
		content = value[KEY_CONTENT]
		time = Time.at(value[KEY_TIME])
		@message_plugins.each do |plugin|
			begin
				return if plugin.on_message(sender, content, time)
			rescue Exception => ex
				log(<<LOG, Logger::ERROR)
执行插件 #{plugin.name} 时发生异常：#{ex}
调用栈：
#{ex.backtrace.join("\n")}
LOG
			end
		end
	end

	def on_group_message(value)
		from = @qqbot.group(value[KEY_FROM_UIN])
		sender = from.member(value[KEY_SEND_UIN])
		content = value[KEY_CONTENT]
		time = Time.at(value[KEY_TIME])
		@group_message_plugins.each do |plugin|
			next if forbidden?(plugin.class.name, from)
			begin
				return if plugin.on_group_message(from, sender, content, time)
			rescue Exception => ex
				log(<<LOG, Logger::ERROR)
执行插件 #{plugin.name} 时发生异常：#{ex}
调用栈：
#{ex.backtrace.join("\n")}
LOG
			end
		end
	end

	def on_system_message(value)
		@system_message_plugins.each do |plugin|
			plugin.on_system_message(value)
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