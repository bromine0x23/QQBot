#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require_relative 'plugin'

class PluginRandom < PluginNicknameResponserBase
	NAME = '人品插件'
	AUTHOR = 'BR'
	VERSION = '1.2'
	DESCRIPTION = '人品测试'
	MANUAL = <<MANUAL
掷骰子
<ACT>还是不<ACT>呢
MANUAL
	PRIORITY = 0

	COMMAND_DICE = '掷骰子'
	COMMAND_CHOOSE = /^(?<act>.+?)(还是)?不\k<act>/

	def get_response(uin, sender_qq, sender_nickname, message, time)
		super
		if COMMAND_DICE == message
			"#{@nickname} 掷出了 #{rand(1..6)}"
		elsif COMMAND_CHOOSE =~ message
			if rand(0..1).zero?
				"#{$~[:act]}！"
			else
				"不#{$~[:act]}……"
			end
		end
	end
end