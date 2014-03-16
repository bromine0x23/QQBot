# -*- coding: utf-8 -*-
require 'digest'

require 'uri'
require 'net/http'
require 'net/https'
require 'webrick/cookie'

module Util
	# Cookie处理辅助类
	class Cookie
		def initialize
			@cookies = {}
		end

		# 更新Cookie
		def update(str)
			@cookies.delete_if do |_, cookie|
				cookie.expires and cookie.expires < Time.now
			end
			WEBrick::Cookie.parse_set_cookies(str).each do |cookie|
				if not cookie.expires or cookie.expires > Time.now
					@cookies[cookie.name] = cookie
				end
			end
		end

		def [](key)
			@cookies[key].value
		end

		def []=(key, value)
			@cookies[key].value = value
		end

		def to_s
			@cookies.values.map{|cookie| "#{cookie.name}=#{cookie.value}"}.join('; ')
		end
	end

	# 网络通信辅助类
	class NetHelper
		attr_reader :header, :cookies

		def initialize(logger)
			@header = {}
			@cookies = Util::Cookie.new
			@logger = logger
		end

		def add_header(key, value)
			@header[key] = value
			self
		end

		def delete_header(key)
			@header.delete(key)
			self
		end

		def get(uri)
			debug("HTTP GET: #{uri}")
			Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
				@header['Cookie'] = @cookies.to_s
				response = http.request(Net::HTTP::Get.new(uri, @header))
				@cookies.update(response['Set-Cookie']) if response['Set-Cookie']
				return response.body
			end
		end

		def post(uri, data)
			debug("HTTP POST: #{uri}")
			Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
				@header['Cookie'] = @cookies.to_s
				response = http.request(Net::HTTP::Post.new(uri, @header), data)
				@cookies.update(response['Set-Cookie']) if response['Set-Cookie']
				return response.body
			end
		end

		def self.uri_https(host, path = '/', queries = {})
			URI::HTTPS.build(
				host: host,
				path: path,
				query: URI.encode_www_form(queries)
			)
		end

		def self.uri_http(host, path = '/', queries = {})
			URI::HTTP.build(
				host: host,
				path: path,
				query: URI.encode_www_form(queries)
			)
		end

		def uri_https(host, path = '/', queries = {})
			URI::HTTPS.build(
				host: host,
				path: path,
				query: URI.encode_www_form(queries)
			)
		end

		def uri_http(host, path = '/', queries = {})
			URI::HTTP.build(
				host: host,
				path: path,
				query: URI.encode_www_form(queries)
			)
		end

		private

		def log(message, level = Logger::INFO)
			@logger.log(level, message, 'Util::NetHelper')
		end

		def debug(message)
			log(message, Logger::DEBUG) if $DEBUG
		end
	end
end