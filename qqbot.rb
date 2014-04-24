#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require_relative 'webqq'
require_relative 'plugin_manager'
require 'yaml'

#noinspection RubyTooManyInstanceVariablesInspection
class QQBot
	FILE_CONFIG = 'config.yaml'

	attr_reader :name
	attr_reader :masters
	attr_reader :plugin_manager

	def initialize
		load_config
		init_logger
		@plugin_manager = PluginManager.new(self, @logger)
	end

	def load_config
		config = YAML.load_file(FILE_CONFIG)
		common_config = config[:common]
		@log_file = common_config[:log_file] || 'qqbot.log'
		@captcha_file = common_config[:captcha_file] || 'captcha.jpg'
		@qq, @password = common_config[:qq], common_config[:password]
		raise Exception.new('未设置QQ号或密码') unless @qq and @password
		@name = common_config[:name]
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
		begin
			@client = WebQQProtocol.login(@qq, @password, @logger, self.method(:on_captcha_need))
		rescue WebQQProtocol::LoginFailed
			puts '登录失败'
			raise
		end
		@message_receiver = @client.receiver
		@message_sender = @client.sender
		load_plugins
		begin
			log('登录成功！')
			puts 'QQBot已成功登录！'
			loop do
				datas = @message_receiver.data
				log("data => #{datas}") if $-d
				datas.each do |data|
					@plugin_manager.on_event(data)
				end
			end
		ensure
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

	def send_message(from, message, font = {})
		@message_sender.send_message(from.uin, message.strip, @font_config.merge(font))
	end

	def send_group_message(from, message, font = {})
		@message_sender.send_group_message(from.uin, message.strip, @font_config.merge(font))
	end

	# @return [String]
	def self.message(content)
		content.select { |item| item.is_a? String }.join.strip
	end

	# @return [PluginBase]
	def plugin(plugin_name)
		@plugin_manager.plugin(plugin_name)
	end

	# @param [WebQQProtocol::QQEntity] from
	def plugins(from)
		from.is_a?(WebQQProtocol::QQGroup) ? @plugin_manager.filtered_plugins(from) : @plugin_manager.plugins
	end

	def load_plugins
		@plugin_manager.load_plugins
	end

	def unload_plugins
		@plugin_manager.unload_plugins
	end

	def reload_plugins
		@plugin_manager.reload_plugins
	end

	# @param [WebQQProtocol::QQEntity] from
	# @param [WebQQProtocol::QQEntity] sender
	# @param [PluginBase] plugin
	def enable_plugin(from, sender, plugin)
		@plugin_manager.enable_plugin(from, sender, plugin) if from.is_a? WebQQProtocol::QQGroup
	end

	# @param [WebQQProtocol::QQEntity] from
	# @param [WebQQProtocol::QQEntity] sender
	# @param [PluginBase] plugin
	def disable_plugin(from, sender, plugin)
		@plugin_manager.disable_plugin(from, sender, plugin) if from.is_a? WebQQProtocol::QQGroup
	end

	# @param [WebQQProtocol::QQGroup] group
	# @param [WebQQProtocol::QQGroupMember] member
	def group_manager?(group, member)
		@masters.group_manager?(group, member) if group.is_a? WebQQProtocol::QQGroup
	end

	# @param [WebQQProtocol::QQEntity] sender
	def master?(sender)
		@masters.include? sender.number
	end

	# @return [WebQQProtocol::QQEntity]
	def entity(uin)
		@client.entity(uin)
	end

	# @return [WebQQProtocol::QQFriend]
	def friend(uin)
		@client.friend(uin)
	end

	# @return [WebQQProtocol::QQGroup]
	def group(guin)
		@client.group(guin)
	end

	# @return [WebQQProtocol::QQFriend]
	def add_friend(qq_number)
		@client.add_friend(qq_number)
	end

	private

	def log(message, level = Logger::INFO)
		@logger.log(level, message, self.class.name)
	end

	def on_captcha_need(image_data)
		File.open(@captcha_file, 'wb') do |file|
			file << image_data
		end
		puts "验证码已保存到 #{@captcha_file}, 请输入验证码："
		# `start #{@captcha_file}`
		gets.strip.upcase
	end
end