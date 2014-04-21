#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require 'json'
require 'net/http'
require 'uri'

=begin
使用了百度翻译API
参见 http://developer.baidu.com/wiki/index.php?title=%E5%B8%AE%E5%8A%A9%E6%96%87%E6%A1%A3%E9%A6%96%E9%A1%B5/%E7%99%BE%E5%BA%A6%E7%BF%BB%E8%AF%91API
=end
class PluginTranslater < PluginNicknameResponserBase
	NAME = '翻译插件'
	AUTHOR = 'BR'
	VERSION = '1.8'
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

	STRING_翻译 = '翻译'
	STRING_AUTO = 'auto'
	STRING_52001 = '52001'
	STRING_52002 = '52002'
	STRING_52003 = '52003'


	HASH_缩写_TO_标识符 = {
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

	HASH_标识符_TO_缩写 = {
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

	COMMAND_PATTERN = /^(?<翻译方向>#{STRING_翻译}|(?<源语言>.)译(?<目标语言>.))\s*(?<待翻译内容>.+)/

	JSON_KEY_ERROR_CODE   = 'error_code'
	JSON_KEY_ERROR_MSG    = 'error_msg'
	JSON_KEY_FROM         = 'from'
	JSON_KEY_TO           = 'to'
	JSON_KEY_TRANS_RESULT = 'trans_result'
	JSON_KEY_DST          = 'dst'

	def get_response(uin, sender_qq, sender_nickname, message, time)
		# super # FOR DEBUG
		if COMMAND_PATTERN =~ message
			if $~[:翻译方向] == STRING_翻译
				目标语言 = 源语言 = STRING_AUTO
			else
				源语言 = HASH_缩写_TO_标识符[$~[:源语言]]
				目标语言 = HASH_缩写_TO_标识符[$~[:目标语言]]
			end

			待翻译内容 = $~[:待翻译内容]

			json_data = JSON.parse(Net::HTTP.get(URI("http://openapi.baidu.com/public/2.0/bmt/translate?client_id=TnChRGR56PhGC0mjA1rG0ueG&q=#{URI.encode_www_form_component(待翻译内容)}&from=#{源语言}&to=#{目标语言}")))

			case json_data[JSON_KEY_ERROR_CODE]
			when STRING_52001
				'翻译错误：超时'
			when STRING_52002
				'翻译错误：翻译系统错误'
			when STRING_52003
				'翻译错误：未授权的用户'
			else
				<<RESPONSE
#{HASH_标识符_TO_缩写[json_data[JSON_KEY_FROM]]} → #{HASH_标识符_TO_缩写[json_data[JSON_KEY_TO]]}：
#{json_data[JSON_KEY_TRANS_RESULT].map {|result| result[JSON_KEY_DST]}.join("\n")}
RESPONSE
			end
		end
	end
end