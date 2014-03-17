#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require_relative 'plugin'

require 'logger'

class PluginChatLogger < PluginResponserBase
	NAME = '消息记录插件'
	AUTHOR = 'BR'
	VERSION = '1.0'
	DESCRIPTION = '记记记记记'
	MANUAL = <<MANUAL
记记记记记
MANUAL
	PRIORITY = 16

	LOG_FILE = File.expand_path(File.dirname(__FILE__) + '/chat.log')

	MESSAGE = '好友消息'
	GROUP_MESSAGE = '群消息'

	def on_load
		@chat_logger = Logger.new(LOG_FILE, File::WRONLY | File::APPEND | File::CREAT)
		@chat_logger.formatter = proc do |_, datetime, prog_name, message|
			"[#{datetime}][#{prog_name}] #{message}\n"
		end
	end

	def on_unload
		@chat_logger.close
	end

	def deal_message(uin, sender_qq, sender_nickname, content, time)
		@chat_logger.log Logger::INFO, <<CHAT.strip, MESSAGE
#{sender_nickname}(#{sender_qq})
#{QQBot.message(content)}
CHAT
		nil
	end

	def deal_group_message(guin, sender_qq, sender_nickname, content, time)
		group = @qqbot.uin_map[guin]
		@chat_logger.log Logger::INFO, <<CHAT.strip, GROUP_MESSAGE
<#{group.group_name}(#{group.group_number})>#{sender_nickname}(#{sender_qq})
#{QQBot.message(content)}
CHAT
		nil
	end
end