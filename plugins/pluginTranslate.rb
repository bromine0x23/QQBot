# -*- coding: utf-8 -*-

require 'json'
require 'net/http'
require 'uri'

=begin
使用了百度翻译API
参见 http://developer.baidu.com/wiki/index.php?title=%E5%B8%AE%E5%8A%A9%E6%96%87%E6%A1%A3%E9%A6%96%E9%A1%B5/%E7%99%BE%E5%BA%A6%E7%BF%BB%E8%AF%91API
=end
class PluginTranslate < PluginNicknameResponderBase
	NAME = '翻译插件'
	AUTHOR = 'BR'
	VERSION = '1.9'
	DESCRIPTION = '妈妈再也不用担心我的外语了！'
	MANUAL = <<MANUAL.strip
<源语言>译<目标语言> <翻译内容>
支持语言：
中、汉：中文
英：英语
日：日文
韩：韩语
法：法语
泰：泰语
俄：俄罗斯语
西：西班牙语
葡：葡萄牙语
阿：阿拉伯语
粤：粤语
文：文言文
MANUAL
	PRIORITY = 0

	STRING_TRANSLATE = '翻译'
	STRING_AUTO = 'auto'
	STRING_52001 = '52001'
	STRING_52002 = '52002'
	STRING_52003 = '52003'


	HASH_NAME_TO_ID = {
		'中' => 'zh',
		'汉' => 'zh',
		'英' => 'en',
		'日' => 'jp',
		'韩' => 'kor',
		'法' => 'fra',
		'泰' => 'th',
		'俄' => 'ru',
		'西' => 'spa',
		'葡' => 'pt',
		'阿' => 'ara',
		'粤' => 'yue',
		'文' => 'wyw',
	}

	#noinspection RubyStringKeysInHashInspection
	HASH_ID_TO_NAME = {
		'zh' => '中文',
		'en' => '英语',
		'jp' => '日语',
		'kor' => '韩语',
		'fra' => '法语',
		'th' => '泰语',
		'ru' => '俄语',
		'spa' => '西班牙语',
		'pt' => '葡萄牙语',
		'ara' => '阿拉伯语',
		'yue' => '粤语',
		'wyw' => '文言文',
	}

	COMMAND_PATTERN = /^((?<auto>翻译)|(?<lang_src>.)译(?<lang_dest>.))\s*(?<content>.+)/m

	JSON_KEY_ERROR_CODE   = 'error_code'
	JSON_KEY_ERROR_MSG    = 'error_msg'
	JSON_KEY_FROM         = 'from'
	JSON_KEY_TO           = 'to'
	JSON_KEY_TRANS_RESULT = 'trans_result'
	JSON_KEY_DST          = 'dst'

	def get_response(_, _, command, _)
		if COMMAND_PATTERN =~ command
			if $~[:auto]
				lang_dest = lang_src = STRING_AUTO
			else
				lang_src  = HASH_NAME_TO_ID[$~[:lang_src]]
				lang_dest = HASH_NAME_TO_ID[$~[:lang_dest]]
			end

			content = $~[:content]

			json_data = JSON.parse(Net::HTTP.get(URI("http://openapi.baidu.com/public/2.0/bmt/translate?client_id=TnChRGR56PhGC0mjA1rG0ueG&q=#{URI.encode_www_form_component(content)}&from=#{lang_src}&to=#{lang_dest}")))

			case json_data[JSON_KEY_ERROR_CODE]
			when STRING_52001
				'翻译错误：超时'
			when STRING_52002
				'翻译错误：翻译系统错误'
			when STRING_52003
				'翻译错误：未授权的用户'
			else
				<<RESPONSE
#{HASH_ID_TO_NAME[json_data[JSON_KEY_FROM]]} → #{HASH_ID_TO_NAME[json_data[JSON_KEY_TO]]}：
#{json_data[JSON_KEY_TRANS_RESULT].map {|result| result[JSON_KEY_DST]}.join("\n")}
RESPONSE
			end
		end
	end
end