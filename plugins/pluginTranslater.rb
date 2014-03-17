#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require_relative 'plugin'

require 'json'
require 'net/http'
require 'uri'

class PluginTranslater < PluginNicknameResponserBase
	NAME = '翻译插件'
	AUTHOR = 'BR'
	VERSION = '1.4'
	DESCRIPTION = 'My English is very good.'
	MANUAL = <<MANUAL
== 翻译 ==
翻译 <翻译内容>
MANUAL
	PRIORITY = 0

	URI_FORMAT = [
		'http://fanyi.youdao.com/openapi.do?keyfrom=bakachu&key=340119877&type=data&doctype=json&version=1.1&q=%s',
		'http://fanyi.youdao.com/openapi.do?keyfrom=Idol-CHU&key=211173787&type=data&doctype=json&version=1.1&q=%s'
	]

	COMMAND_PATTERN = /^翻译\s*(?<text>.+)$/

	KEY_ERRORCODE = 'errorCode'
	KEY_TRANSLATE = 'translation'

	RESPONSE_TOOLONG = '那太长了'
	RESPONSE_FAILED = '无法进行有效的翻译'
	RESPONSE_UNSUPPORT = '不支持的语言类型'
	RESPONSE_INVALID_KEY = '无效的key'
	RESPONSE_UNKNOWN = '未知错误'

	def get_response(uin, sender_qq, sender_nickname, message, time)
		if COMMAND_PATTERN =~ message
			data = JSON.parse(Net::HTTP.get(URI(URI_FORMAT.sample % URI.encode_www_form_component($~[:text]))))
			case data[KEY_ERRORCODE]
			when 0
				data[KEY_TRANSLATE].join("\n")
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