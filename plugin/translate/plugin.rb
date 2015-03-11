# -*- coding: utf-8 -*-

require 'English'
require 'open-uri'
require 'yajl'

# noinspection RubyStringKeysInHashInspection
to_id = {
	'中' => :zh,
	'中文' => :zh,
	'汉' => :zh,
	'汉语' => :zh,
	'英' => :en,
	'英语' => :en,
	'日' => :jp,
	'日语' => :jp,
	'韩' => :kor,
	'韩语' => :kor,
	'法' => :fra,
	'法语' => :fra,
	'俄' => :ru,
	'俄语' => :ru,
	'粤' => :yue,
	'粤语' => :yue,
	'文' => :wyw,
	'文言' => :wyw,
	'文言文' => :wyw,
	'西班牙语' => :spa,
	'葡萄牙语' => :pt,
	'阿拉伯语' => :ara
}
to_id.default = :auto

# noinspection RubyStringKeysInHashInspection
to_name = {
	'zh' => :中文,
	'en' => :英语,
	'jp' => :日语,
	'kor' => :韩语,
	'fra' => :法语,
	'th' => :泰语,
	'ru' => :俄语,
	'spa' => :西班牙语,
	'pt' => :葡萄牙语,
	'ara' => :阿拉伯语,
	'yue' => :粤语,
	'wyw' => :文言文,
}

install_hooks << lambda do
	fail 'Config file\'s field "client_id" not set.' unless config[:client_id]
end

functions << lambda do  |_from, _sender, command, _time|
	return unless command =~ /\A(?:翻译|(?<from>\S*?)\s*翻?译成?\s*(?<to>\S*?))\s*(?<content>.+)\Z/m
	uri = URI('http://openapi.baidu.com/public/2.0/bmt/translate')
	uri.query = URI.encode_www_form(
		client_id: config[:client_id],
		q: $LAST_MATCH_INFO[:content],
		from: to_id[$LAST_MATCH_INFO[:from]],
		to: to_id[$LAST_MATCH_INFO[:to]]
	)

	# noinspection RubyResolve
	response = Yajl.load(uri.read)

	if response['error_code']
		format(
			config[:display][:error],
			code: response['error_code'],
			message: response['error_msg']
		)
	else
		format(
			config[:display][:normal],
			from: to_name[response['from']],
			to: to_name[response['to']],
			result: response['trans_result'].map{|result| result['dst']}.join("\n")
		)
	end
end