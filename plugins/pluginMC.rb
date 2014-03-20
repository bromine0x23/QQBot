#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require_relative 'plugin'

class PluginMC < PluginNicknameResponserBase
	NAME = 'MC插件'
	AUTHOR = 'BR'
	VERSION = '1.5'
	DESCRIPTION = 'MC合成表查询'
	MANUAL = <<MANUAL.strip
== 合成表查询 ==
MC 合成 <物品>（用逗号(,，)分割）
MANUAL
	PRIORITY = 0

	CONFIG_FILE = file_path __FILE__, 'pluginMC.yaml'

	# COMMAND_PATTERN = /^MC\s*(?<command>.+)/i
	# RECIPE_PATTERN = /^合成\s*(?<item_names>.+)/i

	COMMAND_PATTERN = /^MC\s*合成\s*(?<item_names>.+)/i

	PATTERN_ITEM_NAMES_SEPARATOR = /,|，/

	def on_load
		# super # FOR DEBUG
		yaml_data = YAML.load_file CONFIG_FILE
		@alias, @recipes = yaml_data['alias'], yaml_data['recipe']
		log('合成表数据加载完毕', Logger::DEBUG) if $-d
	end

	def get_response(uin, sender_qq, sender_nickname, message, time)
		# super # FOR DEBUG

		if COMMAND_PATTERN =~ message
			response = response_header_with_nickname sender_nickname
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