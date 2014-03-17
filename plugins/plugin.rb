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

	def self.plugins
		@@plugins
	end

	# @param [QQBot] qqbot
	# @param [Logger] logger
	def initialize(qqbot, logger)
		@qqbot = qqbot
		@logger = logger
		@send_message = @qqbot.method(:send_message)
		@send_group_message = @qqbot.method(:send_group_message)

		log('初始化……')
		on_load
		log('初始化完毕')
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
		debug('message 消息')
		# 桩方法，处理 message 消息
	end

	def on_group_message(value)
		debug('group_message 消息')
		# 桩方法，处理 group_message 事件
	end

	def on_input_notify(value)
		debug('input_notify 消息')
		# 桩方法，处理 input_notify 消息
	end

	def on_buddies_status_change(value)
		debug('buddies_status_change 事件')
		# 桩方法，处理 buddies_status_change 消息
	end

	def on_sess_message(value)
		debug('sess_message 消息')
		# 桩方法，处理 sess_message 消息
	end

	def on_kick_message(value)
		debug('kick_message 消息')
		# 桩方法，处理 kick_message 消息
	end

	def on_group_web_message(value)
		debug('group_web_message 消息')
		# 桩方法，处理 group_web_message 消息
	end

	protected

	def log(message, level = Logger::INFO)
		@logger.log(level, message, self.class.name)
	end

	def debug(message)
		log(message, Logger::DEBUG) if $DEBUG
	end

	private

	def self.inherited(subclass)
		@@plugins << subclass unless subclass.name.end_with? 'Base'
	end
end

class PluginResponserBase < PluginBase
	NAME = '消息回应插件基类'

	def on_message(value)
		super
		uin = value['from_uin']
		deal_message(uin, @qqbot.qq_number(uin), @qqbot.friend_nickname(uin), value['content'], Time.at(value['time']))
	end

	def on_group_message(value)
		super
		guin = value['from_uin']
		uin = value['send_uin']
		deal_group_message(guin, @qqbot.qq_number(uin), @qqbot.group_nickname(guin, uin), value['content'], Time.at(value['time']))
	end

	def deal_message(uin, sender_qq, sender_nickname, content, time)
		debug("来自#{sender_nickname}(#{sender_qq})的消息")
		# 桩方法，处理事件响应
	end

	def deal_group_message(guin, sender_qq, sender_nickname, content, time)
		debug("来自#{sender_nickname}(#{sender_qq})的群消息")
		# 桩方法，处理群事件响应
	end
end

class PluginNicknameResponserBase < PluginResponserBase
	NAME = '昵称呼叫型消息回应插件基类'

	def on_load
		super
		@nickname = @qqbot.bot_name
	end

	def deal_message(uin, sender_qq, sender_nickname, content, time)
		super
		response_or_ingnore(uin, sender_qq, sender_nickname, QQBot.message(content), time, @send_message)
	end

	def deal_group_message(guin, sender_qq, sender_nickname, content, time)
		super
		response_or_ingnore(guin, sender_qq, sender_nickname, $~[:message].strip, time, @send_group_message) if /\s*@?#{@nickname}(?<message>.*)/ =~ QQBot.message(content)
	end

	def response_or_ingnore(uin, sender_qq, sender_nickname, message, time, sender)
		response = get_response(uin, sender_qq, sender_nickname, message, time)
		sender.call(uin, response) if response
	end

	def get_response(uin, sender_qq, sender_nickname, message, time)
		debug("处理指令：#{message}")
		# 桩方法，处理消息响应
	end
end