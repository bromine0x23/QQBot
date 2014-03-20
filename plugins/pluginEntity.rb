#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require_relative 'plugin'

class PluginEntity < PluginBase
	NAME = 'UIN管理'
	AUTHOR = 'BR'
	VERSION = '1.0'
	DESCRIPTION = '这模型好烦啊'
	MANUAL = <<MANUAL.strip
无
MANUAL
	PRIORITY = 16

	STATUS_ONLINE  = 'online'
	STATUS_OFFLINE = 'offline'
	STATUS_AWAY    = 'away'
	STATUS_SILENT  = 'silent'


	def on_buddies_status_change(value)
		super # FOR DEBUG
		uin = value['uin']
		status = value['status']
		case status
		when STATUS_ONLINE
			friend = @qqbot.friend(uin)
			log("#{friend.nickname}(#{friend.qq_number}) 上线了")
			# @send_message.call(uin, '正面上我！')
		when STATUS_OFFLINE
			log("#{friend.nickname}(#{friend.qq_number}) 下线了")
			# @send_message.call(uin, '正面上我！')
		when STATUS_AWAY
			log("#{friend.nickname}(#{friend.qq_number}) 暂时离开")
		when STATUS_SILENT
			log("#{friend.nickname}(#{friend.qq_number}) 开始工作")
		else
			log("未处理的状态 #{status}")
		end
		true
	end
end