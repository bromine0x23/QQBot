# -*- coding: utf-8 -*-

require 'base64'
require 'digest'
require 'English'
require 'net/http'
require 'uri'

uri_buddy = URI('http://yufolunchan.com/fyq/fo.php')

functions << lambda do |_, _, command, _|
	return unless command =~ /\A(?<action>问佛|参悟)\s*(?<source>.+)\Z/m
	action, source = $LAST_MATCH_INFO[:action], $LAST_MATCH_INFO[:source]
	case action
	when '问佛'
		Net::HTTP.post_form(uri_buddy, 'fo1' => source, 'submit' => 'submit').body.force_encoding('utf-8')
	when '参悟'
		Net::HTTP.post_form(uri_buddy, 'fo2' => source, 'submit2' => 'submit2').body.force_encoding('utf-8')
	else
		fail 'Invalid Action'
	end
end

encode = lambda do |type, source|
	case type
	when /^base64/i
		Base64.strict_encode64(source)
	else
		fail 'Invalid Type'
	end
end

decode = lambda do |type, source|
	case type
	when /^base64/i
		Base64.strict_decode64(source)
	else
		fail 'Invalid Type'
	end
end

functions << lambda do |_, _, command, _|
	return unless command =~ /\A(?<action>编码|解码)\s*(?<type>base64)\s*(?<source>.+)\Z/mi
	action, type, source = $LAST_MATCH_INFO[:action], $LAST_MATCH_INFO[:type], $LAST_MATCH_INFO[:source]
	case action
	when '编码'
		format(config[:display][:encode], type: type, source: source, result: encode[type, source])
	when '解码'
		format(config[:display][:decode], type: type, source: source, result: decode[type, source])
	else
		fail 'Invalid Action'
	end
end

digest = lambda do |type, source|
	# noinspection RubyResolve
	case type
	when /^md5/i
		Digest::MD5.hexdigest(source).upcase
	when /^sha1/i
		Digest::SHA1.hexdigest(source).upcase
	when /^sha256/i
		Digest::SHA256.hexdigest(source).upcase
	when /^sha384/i
		Digest::SHA384.hexdigest(source).upcase
	when /^sha512/i
		Digest::SHA512.hexdigest(source).upcase
	else
		fail 'Invalid Type'
	end
end

functions << lambda do |_, _, command, _|
	return unless command =~ /\A计算\s*(?<type>MD5|SHA1|SHA256|SHA384|SHA512)\s*(?<source>.+)\Z/mi
	type, source = $LAST_MATCH_INFO[:type], $LAST_MATCH_INFO[:source]
	format(config[:display][:digest], type: type, source: source, result: digest[type, source])
end