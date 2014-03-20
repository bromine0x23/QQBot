#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require_relative 'plugin'

class PluginFriend < PluginBase
	NAME = '好友认证插件'
	AUTHOR = 'BR'
	VERSION = '1.3'
	DESCRIPTION = '大概……可以自动认证吧'
	MANUAL = <<MANUAL
加好友你都不会？！
MANUAL
	PRIORITY = 8

	JSON_KEY_TYPE = 'type'
	JSON_KEY_ACCOUNT = 'account'
	STRING_VERIFY_REQUIRED = 'verify_required'

	def on_system_message(value)
		# super # FOR DEBUG
		if value[JSON_KEY_TYPE] == STRING_VERIFY_REQUIRED
			new_friend = @qqbot.add_friend value[JSON_KEY_ACCOUNT]
			log("和#{new_friend.nickname}(#{new_friend.qq_number})成为了好友")
			true
		end
	end
end