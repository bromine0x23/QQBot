#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require_relative 'plugin'

class PluginFriend < PluginBase
	NAME = '好友认证插件'
	AUTHOR = 'BR'
	VERSION = '1.0'
	DESCRIPTION = '大概……可以自动认证吧'
	MANUAL = <<MANUAL
加好友你都不会？！
MANUAL
	PRIORITY = 8

	def on_system_message(value)
		super
		if value['type'] == 'verify_required'
			puts @qqbot.add_friend(value['account'])
		end
	end
end