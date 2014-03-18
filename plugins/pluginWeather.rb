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
	VERSION = '1.0'
	DESCRIPTION = '天气查询'
	MANUAL = <<MANUAL
天气 <城市>
MANUAL
	PRIORITY = 0

	URI_FORMAT = 'http://api.map.baidu.com/telematics/v3/weather?location=%s&output=json&ak=TnChRGR56PhGC0mjA1rG0ueG'

	COMMAND_PATTERN = /^天气\s*(?<city>.+)$/

	KEY_ERROR = 'error'
	KEY_RESULTS = 'results'
	KEY_CURRENT_CITY = 'currentCity'
	KEY_WEATHER_DATA = 'weather_data'
	KEY_DATE = 'date'
	KEY_WEATHER = 'weather'
	KEY_WIND = 'wind'
	KEY_TEMPERATURE = 'temperature'

	RESPONSE_ERROR = '查询天气时遭遇错误，错误代码 %d'

	def get_response(uin, sender_qq, sender_nickname, message, time)
		super
		if COMMAND_PATTERN =~ message
			data = JSON.parse(Net::HTTP.get(URI(URI_FORMAT % URI.encode_www_form_component($~[:city]))))
			if data[KEY_ERROR] == 0
				response = ''
				data[KEY_RESULTS].each do |result|
					response << "#{result[KEY_CURRENT_CITY ]} 天气\n"
					result[KEY_WEATHER_DATA].each do |weather_data|
						response << <<WEATHER
#{weather_data[KEY_DATE]}：#{weather_data[KEY_WEATHER]}，#{weather_data[KEY_TEMPERATURE]}，#{weather_data[KEY_WIND]}
WEATHER
					end
				end
				response
			else
				RESPONSE_ERROR % data[KEY_ERROR]
			end
		end
	end
end