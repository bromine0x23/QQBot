#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require_relative 'plugin'

class PluginRandom < PluginNicknameResponserBase
	NAME = '随机数插件'
	AUTHOR = 'BR'
	VERSION = '1.0'
	DESCRIPTION = '人品测试'
	MANUAL = <<MANUAL
掷骰子
MANUAL
	PRIORITY = 0

	COMMAND = '掷骰子'

	def get_response(uin, sender_qq, sender_nickname, message, time)
		super
		if message == COMMAND
			"#{@nickname} 掷出了 #{rand(1..6)}"
		end
	end
end