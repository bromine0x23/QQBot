# -*- coding: utf-8 -*-

require 'net/http'
require 'base64'
require 'digest'

class PluginEncrypt < PluginNicknameResponderCombineFunctionBase
	NAME = '加密插件'
	AUTHOR = 'BR'
	VERSION = '1.1'
	DESCRIPTION = '字符串加密（哈希）'
	MANUAL = <<MANUAL.strip
加密 <加密方法> <源串>
==== 支持的加密方法 ====
Base64 佛曰 MD5
SHA1 SHA256 SHA384 SHA512
MANUAL
	PRIORITY = 0

	COMMAND_BUDDHA_ENCODE = /^问佛\s*(?<src>.+)/m
	COMMAND_BUDDHA_DECODE = /^参悟\s*(?<src>.+)/m
	COMMAND_BASE64_ENCODE = /^编码\s*BASE64\s*(?<src>.+)/mi
	COMMAND_BASE64_DECODE = /^解码\s*BASE64\s*(?<src>.+)/mi
	COMMAND_MD5    = /^计算\s*MD5\s*(?<src>.+)/mi
	COMMAND_SHA1   = /^计算\s*SHA1\s*(?<src>.+)/mi
	COMMAND_SHA256 = /^计算\s*SHA256\s*(?<src>.+)/mi
	COMMAND_SHA384 = /^计算\s*SHA384\s*(?<src>.+)/mi
	COMMAND_SHA512 = /^计算\s*SHA512\s*(?<src>.+)/mi

	URI_BUDDHA = URI('http://keyfc.laputachen.com/bbs/tools/tudou.aspx')

	BUDDHA_RESULT_PATTERN = /^<BUDDHIST><Message><!\[CDATA\[(?<res>.*)\]\]><\/Message><\/BUDDHIST>$/

	def function_buddha_encode(_, _, command, _)
		if COMMAND_BUDDHA_ENCODE =~ command
			Net::HTTP.post_form(URI_BUDDHA, 'orignalMsg' => $~[:src], 'action' => 'Encode')
				.body.force_encoding('utf-8')[BUDDHA_RESULT_PATTERN, :res]
		end
	end

	def function_buddha_decode(_, _, command, _)
		if COMMAND_BUDDHA_DECODE =~ command
			Net::HTTP.post_form(URI_BUDDHA, 'orignalMsg' => $~[:src], 'action' => 'Decode')
				.body.force_encoding('utf-8')[BUDDHA_RESULT_PATTERN, :res]
		end
	end

	def function_base64_encode(_, _, command, _)
		if COMMAND_BASE64_ENCODE =~ command
			<<RESPONSE
Base64 编码结果：
#{Base64.strict_encode64($~[:src])}
RESPONSE
		end
	end

	def function_base64_decode(_, _, command, _)
		if COMMAND_BASE64_DECODE =~ command
			<<RESPONSE
Base64 解码结果：
#{Base64.strict_decode64($~[:src])}
RESPONSE
		end
	end

	#noinspection RubyResolve
	def function_md5(_, _, command, _)
		if COMMAND_MD5 =~ command
			<<RESPONSE
MD5 计算结果：
#{Digest::MD5.hexdigest($~[:src]).upcase}
RESPONSE
		end
	end

	def function_sha1(_, _, command, _)
		if COMMAND_SHA1 =~ command
			<<RESPONSE
SHA1 计算结果：
#{Digest::SHA1.hexdigest($~[:src]).upcase}
RESPONSE
		end
	end

	#noinspection RubyResolve
	def function_sha256(_, _, command, _)
		if COMMAND_SHA256 =~ command
			<<RESPONSE
SHA256 计算结果：
#{Digest::SHA256.hexdigest($~[:src]).upcase}
RESPONSE
		end
	end

	#noinspection RubyResolve
	def function_sha384(_, _, command, _)
		if COMMAND_SHA384 =~ command
			<<RESPONSE
SHA384 计算结果：
#{Digest::SHA384.hexdigest($~[:src]).upcase}
RESPONSE
		end
	end

	#noinspection RubyResolve
	def function_sha512(_, _, command, _)
		if COMMAND_SHA512 =~ command
			<<RESPONSE
SHA512 计算结果：
#{Digest::SHA512.hexdigest($~[:src]).upcase}
RESPONSE
		end
	end
end