# -*- coding: utf-8 -*-

require 'English'
require 'open-uri'
require 'yajl'

install_hooks << lambda do
	fail 'Config file\'s field "client_id" not set.' unless config[:client_id]
end

functions << lambda do |_, sender, command, _|
	return unless command =~ /\A(?:天气\s*(?<location>.+)?|(?<location>.+)?\s*天气)\Z/
	location = $LAST_MATCH_INFO[:location] || sender.city

	uri = URI('http://api.map.baidu.com/telematics/v3/weather')
	uri.query = URI.encode_www_form(
		ak: config[:client_id],
		location: location,
		output: :json
	)

	# noinspection RubyResolve
	response = Yajl.load(uri.read)

	if response['error'].zero? # 正常
		response['results'].map { |result|
			format(
				config[:display][:weathers],
				city: result['currentCity'],
				pm25: result['pm25'] || '无数据',
				weathers: result['weather_data'].first(3).map { |weather_data|
					format(
						config[:display][:weather],
						date: weather_data['date'],
						weather: weather_data['weather'],
						temperature: weather_data['temperature'],
						wind: weather_data['wind']
					)
				}.join("\n"),
				indices: result['index'].map { |index|
					format(
						config[:display][:index],
						title: index['title'],
						index: index['zs'],
						meaning: index['tipt'],
						description: index['des'],
					)
				}.join("\n"),
			)
		}.join("\n")
	else
		format(
			config[:display][:error],
			code: response['error'],
			message: response['status']
		)
	end
end