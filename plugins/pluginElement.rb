#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require 'yaml'

class PluginElement < PluginNicknameResponserBase
	NAME = '化学元素插件'
	AUTHOR = 'BR'
	VERSION = '1.0'
	DESCRIPTION = '食我方块达人门捷列夫'
	MANUAL = <<MANUAL.strip!
化学元素 <元素名|元素序号>
MANUAL
	PRIORITY = 0

	COMMAND_PATTERN = /^化学元素\s*(?<element>.+)/

	FILE_DATA = file_path __FILE__, 'pluginElement.yaml'

	def on_load
		data = YAML.load_file(FILE_DATA)
		@元素数据 = data[:元素数据]
		@原子序号索引 = data[:原子序号索引]
	end

	def join_element_data(element)
		string = "No.#{element[:原子序数]} #{element[:符号]}（"
		string << (element[:中文名] << '，' if element[:中文名])
		string << element[:英文名] << "）\n"
		string << "第#{element[:周期]}周期 #{element[:区]}区 #{element[:族]}族\n"
		string << "相对原子质量：#{element[:相对原子质量]}"
		string << "室温状态：#{element[:室温状态]}\n"
		string << "熔点：#{element[:摄氏熔点]}℃（#{element[:开氏熔点]}Ｋ）\n"
		string << (element[:是否升华] ? "沸点：升华\n" : "沸点：#{element[:摄氏沸点]}℃（#{element[:开氏沸点]}Ｋ）\n")
		string << "氧化价：#{element[:氧化价].join(',')}\n"
		string
	end

	def get_response(uin, sender_qq, sender_nickname, message, time)
		if COMMAND_PATTERN =~ message
			element_name = $~[:element]
			element_index = @原子序号索引[element_name]
			if element_index
				join_element_data(@元素数据[element_index])
			else
				"无效的元素：#{element_name}"
			end
		end
	end
end