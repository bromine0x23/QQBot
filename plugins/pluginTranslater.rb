#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require 'json'
require 'net/http'
require 'uri'

=begin
使用了有道翻译API
参见 http://fanyi.youdao.com/openapi
=end
class PluginTranslater < PluginNicknameResponserBase
	NAME = '翻译插件'
	AUTHOR = 'BR'
	VERSION = '1.6'
	DESCRIPTION = '妈妈再也不用担心我的英语了！'
	MANUAL = <<MANUAL.strip
翻译 <翻译内容>
MANUAL
	PRIORITY = 0

	URI_FORMAT = [
		'http://fanyi.youdao.com/openapi.do?keyfrom=bakachu&key=340119877&type=data&doctype=json&version=1.1&q=%s',
		'http://fanyi.youdao.com/openapi.do?keyfrom=Idol-CHU&key=211173787&type=data&doctype=json&version=1.1&q=%s',
		'http://fanyi.youdao.com/openapi.do?keyfrom=ShiningCo&key=1178023468&type=data&doctype=json&version=1.1&q=%s'
	]

	COMMAND_PATTERN = /^翻译\s*(?<text>.+)/

	KEY_ERRORCODE = 'errorCode'
	KEY_TRANSLATE = 'translation'

	RESPONSE_TOOLONG     = '那太长了'
	RESPONSE_FAILED      = '无法进行有效的翻译'
	RESPONSE_UNSUPPORT   = '不支持的语言类型'
	RESPONSE_INVALID_KEY = '无效的key'
	RESPONSE_UNKNOWN     = '未知错误'

	def get_response(uin, sender_qq, sender_nickname, message, time)
		# super # FOR DEBUG
		if COMMAND_PATTERN =~ message
			json_data = JSON.parse(Net::HTTP.get(URI(URI_FORMAT.sample % URI.encode_www_form_component($~[:text]))))
			case json_data[KEY_ERRORCODE]
			when 0
				json_data[KEY_TRANSLATE].join("\n")
			when 20
				RESPONSE_TOOLONG
			when 30
				RESPONSE_FAILED
			when 40
				RESPONSE_UNSUPPORT
			when 50
				RESPONSE_INVALID_KEY
			else
				RESPONSE_UNKNOWN
			end
		end
	end
end