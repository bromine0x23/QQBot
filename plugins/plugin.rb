#!/usr/bin/ruby
# -*- coding: utf-8 -*-

class PluginBase
	NAME = '插件基类'
	AUTHOR = 'BR'
	VERSION = '0.0'
	DESCRIPTION = '用于派生其他插件'
	MANUAL = <<MANUAL
MANUAL
	PRIORITY = 0

	@@plugins = []
	@@sub_plugins = []

	def self.plugins
		@@plugins
	end

	def self.sub_plugins
		@@sub_plugins
	end

	# @param [QQBot] qqbot
	# @param [Logger] logger
	def initialize(qqbot, logger)
		@qqbot = qqbot
		@logger = logger
		@send_message = @qqbot.method(:send_message)
		@send_group_message = @qqbot.method(:send_group_message)

		on_load
		log('初始化完毕', Logger::DEBUG) if $-d
	end

	def name
		self.class::NAME
	end

	def author
		self.class::AUTHOR
	end

	def version
		self.class::VERSION
	end

	def description
		self.class::DESCRIPTION
	end

	def manual
		self.class::MANUAL
	end

	def priority
		self.class::PRIORITY
	end

	def info
		{
			name: name,
			author: author,
			version: version,
			description: description,
			manual: manual,
			priority: priority
		}
	end

	def on_load
		# 桩方法
	end

	def on_unload
		# 桩方法
	end

	def on_enter_loop
		# 桩方法
	end

	def on_exit_loop
		# 桩方法
	end

	def on_message(value)
		log("message #{value}", Logger::DEBUG) if $-d
		# 桩方法，处理 message 消息
		nil
	end

	def on_group_message(value)
		log("group_message #{value}", Logger::DEBUG) if $-d
		# 桩方法，处理 group_message 事件
		nil
	end

	def on_input_notify(value)
		log("input_notify #{value}", Logger::DEBUG) if $-d
		# 桩方法，处理 input_notify 消息
		true # 暂时忽略
	end

	def on_buddies_status_change(value)
		log("buddies_status_change #{value}", Logger::DEBUG) if $-d
		# 桩方法，处理 buddies_status_change 消息
		nil
	end

	def on_sess_message(value)
		log("sess_message #{value}")
		# 桩方法，处理 sess_message 消息
		nil
	end

	def on_kick_message(value)
		log("kick_message #{value}")
		# 桩方法，处理 kick_message 消息
		true
	end

	def on_group_web_message(value)
		log("group_web_message #{value}")
		# 桩方法，处理 group_web_message 消息
		true
	end

	def on_system_message(value)
		log("system_message #{value}")
		# 桩方法，处理 system_message 消息
		true
	end

	def on_sys_g_msg(value)
		log("sys_g_msg #{value}")
		# 桩方法，处理 sys_g_msg 消息
		true
	end

	def on_buddylist_change(value)
		log("buddylist_change #{value}")
		# 桩方法，处理 buddylist_change 消息
		true
	end

	protected

	def log(message, level = Logger::INFO)
		@logger.log(level, message, self.class.name)
	end

	def self.file_path(source_path, file_name)
		File.expand_path "#{File.dirname(source_path)}/#{file_name}"
	end

	private

	STR_BASE = 'Base'

	def self.inherited(subclass)
		@@sub_plugins.unshift subclass
		@@plugins << subclass unless subclass.name.end_with? STR_BASE
	end
end

class PluginResponserBase < PluginBase
	NAME = '消息回应插件基类'

	KEY_FROM_UIN = 'from_uin'
	KEY_SEND_UIN = 'send_uin'
	KEY_CONTENT = 'content'
	KEY_TIME = 'time'
	
	def response_header_with_nickname(nickname)
		response = <<RESPONSE
回 #{nickname} 大人：
RESPONSE
	end

	def on_message(value)
		# super # FOR DEBUG
		uin = value[KEY_FROM_UIN]
		friend = @qqbot.friend(uin)
		deal_message(uin, friend.number, friend.name, value[KEY_CONTENT], value[KEY_TIME])
	end

	def on_group_message(value)
		# super # FOR DEBUG
		guin, uin = value[KEY_FROM_UIN], value[KEY_SEND_UIN]
		member = @qqbot.group_member(guin, uin)
		deal_group_message(guin, member.number, member.name, value[KEY_CONTENT], value[KEY_TIME])
	end

	def deal_message(uin, sender_qq, sender_nickname, content, time)
		log("来自#{sender_nickname}(#{sender_qq})的消息", Logger::DEBUG) if $-d
		# 桩方法，处理事件响应
	end

	def deal_group_message(guin, sender_qq, sender_nickname, content, time)
		log("来自#{sender_nickname}(#{sender_qq})的群消息", Logger::DEBUG) if $-d
		# 桩方法，处理群事件响应
	end
end

class PluginNicknameResponserBase < PluginResponserBase
	NAME = '昵称呼叫型消息回应插件基类'

	def bot_name
		@qqbot.bot_name
	end

	def deal_message(uin, sender_qq, sender_nickname, content, time)
		# super # FOR DEBUG
		response_or_ingnore(uin, sender_qq, sender_nickname, QQBot.message(content), time, @send_message)
	end

	def deal_group_message(guin, sender_qq, sender_nickname, content, time)
		# super # FOR DEBUG
		response_or_ingnore(guin, sender_qq, sender_nickname, $~[:message].strip, time, @send_group_message) if /^\s*@?#{bot_name}(?<message>.*)/ =~ QQBot.message(content)
	end

	def response_or_ingnore(uin, sender_qq, sender_nickname, message, time, sender)
		response = get_response(uin, sender_qq, sender_nickname, message, time)
		sender.call(uin, response) if response
	end

	def get_response(uin, sender_qq, sender_nickname, message, time)
		log("处理指令：#{message}", Logger::DEBUG) if $-d
		# 桩方法，处理消息响应
		nil
	end
end