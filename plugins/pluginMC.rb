#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require_relative 'plugin'

class PluginMC < PluginNicknameResponserBase
	NAME = 'MC插件'
	AUTHOR = 'BR'
	VERSION = '1.2'
	DESCRIPTION = 'MC合成表查询'
	MANUAL = <<MANUAL
== 合成表查询 ==
MC 合成 <物品>（用逗号(,，)分割）
MANUAL
	PRIORITY = 0

	CONFIG_FILE = File.expand_path(File.dirname(__FILE__) + '/pluginMC.yaml')

	COMMAND_PATTERN = /^MC\s*(?<command>.+)/i
	RECIPE_PATTERN = /^合成\s*(?<item_names>.+)/i

	PATTERN_ITEM_NAMES_SEPARATOR = /,|，/

	RESPONSE_NO_ITEM = '不存在物品：%s 的合成公式'

	def on_load
		super
		log('加载数据……')
		config = YAML.load_file(CONFIG_FILE)
		@alias = config['alias']
		@recipes = config['recipe']
		log('加载完毕')
	end

	def get_response(uin, sender_qq, sender_nickname, message, time)
		super
		if COMMAND_PATTERN =~ message
			command = $~[:command]
			if RECIPE_PATTERN =~ command
				response = <<RESPONSE
回 #{sender_nickname} 大人：
RESPONSE
				$~[:item_names].split(PATTERN_ITEM_NAMES_SEPARATOR).each do |item_name|
					item_name = @alias[item_name] if @alias.has_key? item_name
					response << <<RESPONSE
#{(@recipes.has_key? item_name) ? @recipes[item_name] : "不存在物品：#{item_name} 的合成公式"}
RESPONSE
				end
				response
			end
		end
	end
end