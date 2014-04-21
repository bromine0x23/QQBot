#!/usr/bin/ruby
# -*- coding: utf-8 -*-

class PluginMC < PluginNicknameResponserBase
	NAME = 'MC插件'
	AUTHOR = 'BR'
	VERSION = '1.8'
	DESCRIPTION = 'MC合成表查询'
	MANUAL = <<MANUAL.strip
== 合成表查询 ==
MC 合成 <物品>（用逗号(,，)分割）
MANUAL
	PRIORITY = 0

	COMMAND_PATTERN = /^MC\s*合成\s*(?<item_names>.+)/i

	SEPARATORS = /,|，/

	def on_load
		super
		@alias = @data['alias']
		@recipe = @data['recipe']
		@alias .default_proc = proc { |hash, key| hash[key] = key }
		@recipe.default_proc = proc { |hash, key| hash[key] = "不存在物品：#{key} 的合成公式" }
	end

	def get_response(uin, sender_qq, sender_nickname, message, time)
		# super # FOR DEBUG
		if COMMAND_PATTERN =~ message
			<<RESPONSE
#{response_header_with_nickname(sender_nickname)}#{$~[:item_names].split(SEPARATORS).map{|item_name| @recipe[@alias[item_name]]}.join("\n")}
RESPONSE
		end
	end
end