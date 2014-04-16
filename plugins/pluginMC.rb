#!/usr/bin/ruby
# -*- coding: utf-8 -*-

class PluginMC < PluginNicknameResponserBase
	NAME = 'MC插件'
	AUTHOR = 'BR'
	VERSION = '1.6'
	DESCRIPTION = 'MC合成表查询'
	MANUAL = <<MANUAL.strip
== 合成表查询 ==
MC 合成 <物品>（用逗号(,，)分割）
MANUAL
	PRIORITY = 0

	CONST_数据文件 = file_path __FILE__, 'pluginMC.data'

	# COMMAND_PATTERN = /^MC\s*(?<command>.+)/i
	# RECIPE_PATTERN = /^合成\s*(?<item_names>.+)/i

	CONST_命令格式 = /^MC\s*合成\s*(?<item_names>.+)/i

	CONST_物品名分隔符 = /,|，/

	def on_load
		# super # FOR DEBUG
		yaml数据 = YAML.load_file CONST_数据文件
		@别名表 = yaml数据['alias']
		@合成表 = yaml数据['recipe']
		@别名表.default_proc = proc { |hash, key| hash[key] = key }
		@合成表.default_proc = proc { |hash, key| hash[key] = "不存在物品：#{key} 的合成公式" }
		log('合成表数据加载完毕', Logger::DEBUG) if $-d
	end

	def get_response(uin, 发送者Q号, 发送者昵称, 消息, 时间)
		# super # FOR DEBUG
		if CONST_命令格式 =~ 消息
			回应 = response_header_with_nickname 发送者昵称
			$~[:item_names].split(CONST_物品名分隔符).each do |item_name|
				回应 << @合成表[@别名表[item_name]] << "\n"
			end
			回应
		end
	end
end