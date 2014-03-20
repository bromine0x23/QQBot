#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require_relative 'plugin'

require 'json'
require 'net/http'
require 'uri'

=begin
使用bilibili 的新番API
参见：
=end
class PluginBangumi < PluginNicknameResponserBase
	NAME = 'bilibili新番插件'
	AUTHOR = 'BR'
	VERSION = '1.1'
	DESCRIPTION = '提供bilibili新番查询支持'
	MANUAL = <<MANUAL.strip
[日期][次元]新番
[日期] => 周一~周日，前天~后天，昨日~明日
[次元] => 二次元 | 三次元
MANUAL
	PRIORITY = 0

	URI_FORMAT = 'http://api.bilibili.tv/bangumi?btype=%d&weekday=%d&appkey=876fe0ebd0e67a0f'

	COMMAND_PATTERN = /^((?<day>[前后]天|[昨今明][日天])|(?<week>周[一二三四五六日]))?\s*(?<type>[二三]次元)?\s*新番$/

	DAY_TO_NUM = {
		'前天' => -2,
		'昨天' => -1,
		'今天' =>  0,
		'明天' =>  1,
		'后天' =>  2,
		'昨日' => -1,
		'今日' =>  0,
		'明日' =>  1,
	}

	WEEK_TO_NUM = {
		'周日' => 0,
		'周一' => 1,
		'周二' => 2,
		'周三' => 3,
		'周四' => 4,
		'周五' => 5,
		'周六' => 6
	}

	TYPE_TO_NUM = {
		'二次元' => 2,
		'三次元' => 3
	}

	def get_response(uin, sender_qq, sender_nickname, message, time)
		# super # FOR DEBUG

		if COMMAND_PATTERN =~ message
			day  = $~[:day]
			week = $~[:week]
			type = $~[:type]
			response = ''
			weekday = if day
						  response << day
						  (7 + DAY_TO_NUM[day] + Time.now.wday) % 7
					  elsif week
						  response << week
						  WEEK_TO_NUM[week]
					  else
						  response << '今日'
						  Time.now.wday
					  end
			btype = if type
						response << type
						TYPE_TO_NUM[type]
					else
						response << '二次元'
						2
					end
			response << "新番：\n"
			json_data = JSON.parse(Net::HTTP.get(URI(URI_FORMAT % [btype, weekday])))
			json_data['list'].each do |key, value|
				if value['new']
					response << <<RESPONSE
#{value['title']} -> #{value['count']} 于 #{Time.at(value['lastupdate']).strftime('%H:%M')}
RESPONSE
				end
			end
			response
		end
	end
end