#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require_relative 'plugin'

class PluginMC < PluginNicknameResponserBase
	NAME = 'MC插件'
	AUTHOR = 'Bromine'
	VERSION = '1.2'
	DESCRIPTION = 'MC合成表查询'
	MANUAL = <<MANUAL
== 合成表查询 ==
MC 合成 <物品>（用逗号(,，)分割）
MANUAL
	PRIORITY = 0

	CONFIG_FILE = File.expand_path(File.dirname(__FILE__) + '/pluginMC.yaml')

	COMMAND_PATTERN = /^MC\s*(?<command>.+)$/i
	RECIPE_PATTERN = /^合成\s*(?<item_names>.+)$/i

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
		if COMMAND_PATTERN =~ message
			command = $~[:command]
			if RECIPE_PATTERN =~ command
				$~[:item_names].split(/,|，/).map { |item_name|
					item_name = @alias[item_name] if @alias.has_key? item_name
					(@recipes.has_key? item_name) ? @recipes[item_name] : RESPONSE_NO_ITEM % item_name
				}.join("\n")
				response
			end
		end
	end
end