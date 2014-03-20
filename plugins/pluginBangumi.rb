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
	NAME = '新番插件'
	AUTHOR = 'BR'
	VERSION = '1.2'
	DESCRIPTION = '提供bilibili新番查询支持'
	MANUAL = <<MANUAL.strip
[日期][次元]新番
　[日期]→周一~周日，前天~后天，昨日~明日
　[次元]→二次元|三次元
MANUAL
	PRIORITY = 0

	COMMAND_PATTERN = /^((?<day>[前后]天|[昨今明][日天])|(?<week>周[一二三四五六日]))?\s*(?<type>[二三]次元)?\s*新番$/

	DAY_STR_TO_NUM = {
		'前天' => -2,
		'昨天' => -1,
		'今天' =>  0,
		'明天' =>  1,
		'后天' =>  2,
		'昨日' => -1,
		'今日' =>  0,
		'明日' =>  1,
	}

	DEFAULT_DAY = '今日'

	WEEK_STR_TO_NUM = {
		'周日' => 0,
		'周一' => 1,
		'周二' => 2,
		'周三' => 3,
		'周四' => 4,
		'周五' => 5,
		'周六' => 6
	}

	WEEK_NUM_TO_STR = WEEK_STR_TO_NUM.invert

	TYPE_STR_TO_NUM = {
		'二次元' => 2,
		'三次元' => 3
	}

	DEFAULT_TYPE = '二次元'

	JSON_KEY_LIST = 'list'
	JSON_KEY_NEW = 'new'
	JSON_KEY_TITLE = 'title'
	JSON_KEY_BGMCOUNT = 'bgmcount'
	JSON_KEY_LASTUPDATE = 'lastupdate'

	TIME_FORMAT = '%H:%M'

	RESPONSE_NOT_UPDATED = '尚未更新'

	def get_response(uin, sender_qq, sender_nickname, message, time)
		# super # FOR DEBUG

		if COMMAND_PATTERN =~ message
			day_str  = $~[:day]
			week_str = $~[:week]
			type_str = $~[:type]
			day_str  = DEFAULT_DAY unless day_str
			week_str = WEEK_NUM_TO_STR[Time.now.wday] unless week_str
			type_str = DEFAULT_TYPE unless type_str
			week_num = (7 + DAY_STR_TO_NUM[day_str] + WEEK_STR_TO_NUM[week_str]) % 7
			type_num = TYPE_STR_TO_NUM[type_str]
			header   = "#{day_str}（#{ WEEK_NUM_TO_STR[week_num]}）#{type_str}新番：\n"
			response = ''
			json_data = JSON.parse(Net::HTTP.get(URI("http://api.bilibili.tv/bangumi?btype=#{type_num}&weekday=#{week_num}&appkey=876fe0ebd0e67a0f")))
			json_data[JSON_KEY_LIST].each do |key, value|
				if value[JSON_KEY_NEW]
					response << <<RESPONSE
#{value[JSON_KEY_TITLE]}→#{value[JSON_KEY_BGMCOUNT]} 于 #{Time.at(value[JSON_KEY_LASTUPDATE]).strftime(TIME_FORMAT)}
RESPONSE
				end
			end
			response << RESPONSE_NOT_UPDATED if response.empty?
			header << response
		end
	end
end