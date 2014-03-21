#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require_relative 'webqq'
require 'yaml'
require 'set'

# $DEBUG = true

class QQBot
	FILE_CONFIG = 'config.yaml'
	FILE_PLUGIN_RULES = 'plugin_rules.yaml'
	LOAD_PLUGINS_PATH = './plugins/plugin*.rb'

	class PluginAdministrator
		PATH_PLUGINS = './plugins/plugin*.rb'
		FILE_RULES = 'plugin_rules.yaml'

		attr_reader :plugins

		def initialize(qqbot, logger)
			@qqbot  = qqbot
			@logger = logger
			@plugins = []
		end

		def load_plugins
			Dir.glob(PATH_PLUGINS) { |file_name| load file_name }
			@plugins = []
			PluginBase.instance_plugins.each { |plugin_class|
				begin
					@plugins << plugin_class.new(@qqbot, @logger)
				rescue Exception => ex
					log(<<LOG, Logger::ERROR)
载入插件 #{plugin_class::NAME} 时发生异常：#{ex}
调用栈：
#{ex.backtrace.join("\n")}
LOG
				end
			}
			@plugins.sort_by! { |plugin| -plugin.priority }
			load_rules
			log('插件载入完毕', Logger::DEBUG) if $-d
			@plugins.size
		end

		def unload_plugins
			save_rules
			@plugins.pop.on_unload until @plugins.empty?
			PluginBase.plugins.each do |plugin|
				Object.send(:remove_const, plugin.name.to_sym)
			end
			Object.send(:remove_const, :PluginBase)
			log('插件卸载完毕', Logger::DEBUG) if $-d
			true
		end

		def reload_plugins
			unload_plugins
			load_plugins
			log('插件重载完毕', Logger::DEBUG) if $-d
			@plugins.size
		end

		def load_rules
			@rules = YAML.load_file FILE_RULES
			@rules.default_proc = proc do |hash, key|
				hash[key] = {
					forbidden_list: Set.new,
					administrators: Set.new
				}
			end
		end

		def save_rules
			File.open(FILE_RULES, 'w') do |file|
				file << YAML.dump(@rules)
			end
		end

		def administrator?(group_number, qq_number)
			@qqbot.master?(qq_number) or @rules[group_number][:administrators].include?(qq_number)
		end

		def enable_plugin(uin, qq_number, plugin)
			entity = @qqbot.entity(uin)
			if entity.is_a? WebQQClient::QQGroup
				group_number = entity.number
				@rules[group_number][:forbidden_list].delete(plugin.class.name) if administrator?(group_number, qq_number)
			end
			save_rules
		end

		def disable_plugin(uin, qq_number, plugin)
			entity = @qqbot.entity(uin)
			if entity.is_a? WebQQClient::QQGroup
				group_number = entity.number
				@rules[group_number][:forbidden_list].add(plugin.class.name) if administrator?(group_number, qq_number)
			end
			save_rules
		end

		def forbidden?(plugin_name, group_number)
			@rules[group_number][:forbidden_list].include? plugin_name
		end

		def filtered_plugins(group_number)
			@plugins.select do |plugin|
				not forbidden?(plugin.class.name, group_number)
			end
		end

		def on_event(data)
			poll_type = data[KEY_POLL_TYPE]
			value     = data[KEY_VALUE]
			event     = :"on_#{poll_type}"
			from_uin  = value[KEY_FROM_UIN]
			from_entity = @qqbot.entity(from_uin)

			@plugins.each do |plugin|
				next if from_entity.is_a?(WebQQClient::QQGroup) and forbidden?(plugin.class.name, from_entity.number)
				begin
					break if plugin.send(event, value)
				rescue Exception => ex
					log(<<LOG, Logger::ERROR)
执行插件 #{plugin.name} 时发生异常：#{ex}
调用栈：
#{ex.backtrace.join("\n")}
LOG
				end
			end
		end

		private

		def log(message, level = Logger::INFO)
			@logger.log(level, message, self.class.name)
		end
	end

	KEY_POLL_TYPE = 'poll_type'
	KEY_VALUE = 'value'
	KEY_FROM_UIN = 'from_uin'

	attr_reader :bot_name
	attr_reader :groups
	attr_reader :friends
	attr_reader :masters
	attr_reader :plugin_adminsrator

	def initialize
		load_config
		init_logger
		@client = WebQQClient.new(@qq, @password, @logger, self.method(:on_captcha_need))
		@plugin_adminsrator = PluginAdministrator.new(self, @logger)
	end

	def load_config
		config = YAML.load_file(FILE_CONFIG)
		common_config = config[:common]
		@log_file = common_config[:log_file] || 'qqbot.log'
		@captcha_file = common_config[:captcha_file] || 'captcha.jpg'
		@qq, @password = common_config[:qq], common_config[:password]
		raise Exception.new('未设置QQ号或密码') unless @qq and @password
		@bot_name = common_config[:bot_name]
		@masters = common_config[:masters]
		@font_config = config[:font]
	end

	def init_logger
		@logger = Logger.new(@log_file, File::WRONLY | File::APPEND | File::CREAT)
		@logger.formatter = proc do |severity, datetime, prog_name, msg|
			prog_name ? "[#{datetime}][#{severity}][#{prog_name}] #{msg}\n" : "[#{datetime}][#{severity}] #{msg}\n"
		end
		@logger
	end

	def run
		log('开始运行……')
		@client.login
		@message_receiver = @client.receiver
		@message_sender = @client.sender
		load_plugins
		refresh_entities
		begin
			log('登录成功！')
			puts 'QQBot已成功登录！'
			loop do
				datas = @message_receiver.data
				log("data => #{datas}") if $-d
				datas.each do |data|
					@plugin_adminsrator.on_event(data)
				end
			end
		ensure
			save_entities
			stop
		end
	end

	def stop
		@client.logout
		@message_receiver.thread.kill
		@message_receiver = nil
		@message_sender.thread.kill
		@message_sender = nil
		unload_plugins
	end

	def send_message(uin, message, font = {})
		@message_sender.send_message(uin, message.strip, @font_config.merge(font))
	end

	def send_group_message(uin, message, font = {})
		@message_sender.send_group_message(uin, message.strip, @font_config.merge(font))
	end

	def self.message(content)
		message = ''
		content.each do |item|
			message << item if item.is_a? String
		end
		message.strip
	end

	def plugin(plugin_name)
		@plugin_adminsrator.plugins.find{ |plugin| plugin.name == plugin_name }
	end

	def plugins(uin)
		entity = entity uin
		entity.is_a?(WebQQClient::QQGroup) ? @plugin_adminsrator.filtered_plugins(entity.number) : @plugin_adminsrator.plugins
	end

	def load_plugins
		@plugin_adminsrator.load_plugins
	end

	def unload_plugins
		@plugin_adminsrator.unload_plugins
	end

	def reload_plugins
		@plugin_adminsrator.reload_plugins
	end

	def enable_plugin(uin, qq_number, plugin)
		@plugin_adminsrator.enable_plugin(uin, qq_number, plugin)
		true
	end

	def disable_plugin(uin, qq_number, plugin)
		@plugin_adminsrator.disable_plugin(uin, qq_number, plugin)
		true
	end

	# @return [TrueClass or FalseClass]
	def forbidden?(plugin_name, uin)
		entity = entity uin
		entity.is_a?(WebQQClient::QQGroup) and @plugin_adminsrator.forbidden?(plugin_name, entity.number)
	end

	def administrator?(uin, qq_number)
		entity = entity uin
		entity.is_a?(WebQQClient::QQGroup) and @plugin_adminsrator.administrator?(entity.number, qq_number) or master?(qq_number)
	end

	def master?(qq_number)
		@masters.include? qq_number
	end

	# @return [WebQQClient::QQEntity]
	def entity(uin)
		@entities[uin]
	end

	# @return [WebQQClient::QQFriend]
	def friend(uin)
		@friends[uin]
	end

	# @return [WebQQClient::QQGroup]
	def group(guin)
		@groups[guin]
	end

	# @return [WebQQClient::QQGroupMember]
	def group_member(guin, uin)
		@groups[guin].member(uin)
	end

	def refresh_entities
		friends, groups = @client.friends, @client.groups
		@friends, @groups = {}, {}
		friends.each do |friend|
			@friends[friend.uin] = friend
		end
		groups.each do |group|
			@groups[group.uin] = group
		end

		@entities = @friends.merge @groups

		true
	end

	# @return [WebQQClient::QQFriend]
	def add_friend(qq_number)
		new_friend = @client.add_friend(qq_number)
		@friends[new_friend.uin] = new_friend
	end

	# @return [WebQQClient::QQFriend]
	def delete_friend(uin)
		@friends.delete(uin)
	end

	private

	def log(message, level = Logger::INFO)
		@logger.log(level, message, self.class.name)
	end

	def save_entities
		File.open('entities.txt', 'w') do |file|
			@entities.each do |uid, entity|
				if entity.is_a? WebQQClient::QQGroup
					file << <<ENTITY << <<MEMBERS
QQ群：#{entity} => #{uid}
ENTITY
#{entity.members.map{|member| "#{member} => #{member.uid}"}.join('\n') }
MEMBERS
				elsif entity.is_a? WebQQClient::QQFriend
					file << <<ENTITY
QQ用户：#{entity} => #{uid}
ENTITY
				end
			end
		end
	end

	def on_captcha_need(image_data)
		File.open(@captcha_file, 'wb') do |file|
			file << image_data
		end
		puts "验证码已保存到 #{@captcha_file}, 请输入验证码："
		`start #{@captcha_file}`
		gets.strip.upcase
	end
end

# qqbot.test
qqbot = QQBot.new
#=begin
loop do
	restart = 0
	begin
		qqbot.run
	rescue Exception => ex
		puts ex
		puts ex.backtrace
		puts 'WebQQ已掉线，将在10秒后重启……'

		sleep(10)

		restart += 1
		if restart > 10
			puts '重启超过10次，退出'
			break
		end

		retry
	end
end
#=end
# qqbot.logout_clean