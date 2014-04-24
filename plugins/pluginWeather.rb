# -*- coding: utf-8 -*-

=begin
使用了LBS开放平台API
参见：http://developer.baidu.com/map/carapi-7.htm
=end
class PluginWeather < PluginNicknameResponderBase
	NAME = '天气插件'
	AUTHOR = 'BR'
	VERSION = '1.4'
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

	def get_response(_, _, command, _)
		# super # FOR DEBUG
		if COMMAND_PATTERN =~ command
			json_data = JSON.parse(Net::HTTP.get(URI("http://api.map.baidu.com/telematics/v3/weather?location=#{URI.encode_www_form_component($~[:city])}&output=json&ak=TnChRGR56PhGC0mjA1rG0ueG")))
			if json_data[KEY_ERROR] == 0 # 正常
				response = ''
				# 合成每个城市的天气数据
				json_data[KEY_RESULTS].each do |result|
					# <城市> 天气
					response << "#{result[KEY_CURRENT_CITY ]} 天气\n"
					# <日期>：<天气>，<温度>，<风力>
					response << result[KEY_WEATHER_DATA].first(3).map! { |data| "#{data[KEY_DATE]}：#{data[KEY_WEATHER]}，#{data[KEY_TEMPERATURE]}，#{data[KEY_WIND]}" }.join("\n")
				end
				response
			else # 异常
				"查询天气时遭遇错误，错误代码 #{data[KEY_ERROR]}"
			end
		end
	end
end