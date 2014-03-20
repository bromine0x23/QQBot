#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require_relative 'plugin'

=begin
使用了LBS开放平台API
参见：http://developer.baidu.com/map/carapi-7.htm
=end
class PluginWeather < PluginNicknameResponserBase
	NAME = '天气插件'
	AUTHOR = 'BR'
	VERSION = '1.2'
	DESCRIPTION = '天气查询'
	MANUAL = <<MANUAL.strip
天气 <城市>
MANUAL
	PRIORITY = 0

	COMMAND_PATTERN = /^天气\s*(?<city>.+)/

	KEY_ERROR = 'error'
	KEY_RESULTS = 'results'
	KEY_CURRENT_CITY = 'currentCity'
	KEY_WEATHER_DATA = 'weather_data'
	KEY_DATE = 'date'
	KEY_WEATHER = 'weather'
	KEY_WIND = 'wind'
	KEY_TEMPERATURE = 'temperature'

	def get_response(uin, sender_qq, sender_nickname, message, time)
		# super # FOR DEBUG
		if COMMAND_PATTERN =~ message
			json_data = JSON.parse(Net::HTTP.get(URI("http://api.map.baidu.com/telematics/v3/weather?location=#{URI.encode_www_form_component($~[:city])}&output=json&ak=TnChRGR56PhGC0mjA1rG0ueG")))

			# 正常
			if json_data[KEY_ERROR] == 0
				response = ''

				# 合成每个城市的天气数据
				json_data[KEY_RESULTS].each do |result|
					# <城市> 天气
					response << "#{result[KEY_CURRENT_CITY ]} 天气\n"

					# <日期>：<天气>，<温度>，<风力>
					result[KEY_WEATHER_DATA].first(3).each do |weather_data|
						response << <<WEATHER
#{weather_data[KEY_DATE]}：#{weather_data[KEY_WEATHER]}，#{weather_data[KEY_TEMPERATURE]}，#{weather_data[KEY_WIND]}
WEATHER
					end
				end
				response

			# 异常
			else
				"查询天气时遭遇错误，错误代码 #{data[KEY_ERROR]}"
			end
		end
	end
end