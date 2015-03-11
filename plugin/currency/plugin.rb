# -*- coding: utf-8 -*-

require 'English'
require 'open-uri'
require 'time'
require 'yajl'

install_hooks << lambda do
	local[:to_code] = to_code = {}
	local[:to_name] = to_name = {}
	config[:currencies].each_pair do |code, name|
		to_code[code] = to_code[name] = code
		to_name[code] = name
	end
end

functions << lambda do |_, _, command, _|
	return unless command =~ /\A(?:汇率\s*(?:(?<from_currency>.+?)(?:\s+(?<to_currency>.+))?)?|(?:(?<from_currency>.+?)(?:\s+(?<to_currency>.+))?)?\s*汇率)\Z/

	to_code = local[:to_code]

	uri = URI('http://apistore.baidu.com/microservice/currency')
	uri.query = URI.encode_www_form(
		fromCurrency: to_code.fetch($LAST_MATCH_INFO[:from_currency], :CNY),
		toCurrency: to_code.fetch($LAST_MATCH_INFO[:to_currency], :CNY),
		amount: config[:amount],
	)

	# noinspection RubyResolve
	response = Yajl.load(uri.read)

	to_name = local[:to_name]
	if response['errNum'].zero?
		data = response['retData']
		from_currency_code, to_currency_code = [data['fromCurrency'], data['toCurrency']]

		format(
			config[:display][:normal],
			time: Time.strptime(data['date'] << data['time'], '%m/%d/%Y%H:%M%P').strftime('纽约时间 %Y/%m/%d %H:%M'),
			from_currency_code: from_currency_code,
			from_currency_name: to_name[from_currency_code],
			to_currency_code: to_currency_code,
			to_currency_name: to_name[to_currency_code],
			rate: data['currency'],
			from_amount: config[:amount],
			to_amount: data['convertedamount'],
		)
	else
		format(
			config[:display][:error],
			code: response['errNum'],
			message: response['errMsg']
		)
	end
end