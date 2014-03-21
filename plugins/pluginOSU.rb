#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require 'json'
require 'net/http'
require 'uri'

class PluginOSU < PluginNicknameResponserBase
	NAME = 'OSU插件'
	AUTHOR = 'BR'
	VERSION = '1.0'
	DESCRIPTION = 'osu!相关信息查询'
	MANUAL = <<MANUAL.strip
MANUAL
	PRIORITY = 0

	MODE_STR_TO_NUM = {
		nil => 0,
		'太鼓' => 1,
		'接水果' => 2,
		'钢琴' => 3
	}

	MODE_STR = %w(osu osu太鼓 osu接水果 osu钢琴)

	STRING_NOT_FOUND = '查无此人'

	COMMAND_PATTERN = /^OSU\s*(?<mode>太鼓|接水果|钢琴)?\s*(?<user_name>\w+)/i

	def get_response(uin, sender_qq, sender_nickname, message, time)
		# super # FOR DEBUG

		if COMMAND_PATTERN =~ message
			mode_num = MODE_STR_TO_NUM[$~[:mode]]
			user_name = URI.encode_www_form_component($~[:user_name])
			json_data = JSON.parse(Net::HTTP.get(URI("https://osu.ppy.sh/api/get_user?k=400009972952a1ab3ef069447925787ac7d8e9dd&u=#{user_name}&m=#{mode_num}&event_days=31")))
			if json_data.empty?
				STRING_NOT_FOUND
			else
				json_data = json_data[0]
				response = <<RESPONSE
[#{MODE_STR[mode_num]}] Lv.#{json_data['level'].to_i} #{json_data['username']}
总游戏次数：#{json_data['playcount']}
pp：#{json_data['pp_raw']} 排名：#{json_data['pp_rank']}
准确率：#{json_data['accuracy'].round(2)}％
A/S/SS次数：#{json_data['count_rank_a']}/#{json_data['count_rank_s']}/#{json_data['count_rank_ss']}
RESPONSE
			end
		end
	end
end