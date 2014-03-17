# -*- coding: utf-8 -*-
require 'digest'

require 'uri'
require 'net/http'
require 'net/https'
require 'webrick/cookie'

module Util
	# Cookie处理辅助类
	class Cookie
		SEPARATOR = '; '
		FORMAT = '%s=%s'

		def initialize
			@cookies = {}
		end

		# 更新Cookie
		def update(str)
			@cookies.delete_if do |_, cookie|
				cookie.expires and cookie.expires < Time.now
			end
			WEBrick::Cookie.parse_set_cookies(str).each do |cookie|
				@cookies[cookie.name] = cookie if not cookie.expires or cookie.expires > Time.now
			end
		end

		def [](key)
			@cookies[key].value
		end

		def []=(key, value)
			@cookies[key].value = value
		end

		def to_s
			@cookies.values.map{|cookie| FORMAT % [cookie.name, cookie.value]}.join(SEPARATOR)
		end
	end

	# 网络通信辅助类
	class NetHelper
		KEY_COOKIE = 'Cookie'
		KEY_SET_COOKIE = 'Set-Cookie'
		DEFAULT_PATH = '/'
		DEFAULT_QUERIES = {}
		SCHEME_HTTPS = 'https'

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
			log("HTTP GET: #{uri}", Logger::DEBUG) if $-d
			Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == SCHEME_HTTPS, verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
				@header[KEY_COOKIE] = @cookies.to_s
				response = http.request(Net::HTTP::Get.new(uri, @header))
				@cookies.update(response[KEY_SET_COOKIE]) if response[KEY_SET_COOKIE]
				return response.body
			end
		end

		def post(uri, data)
			log("HTTP POST: #{uri}", Logger::DEBUG) if $-d
			Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == SCHEME_HTTPS, verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
				@header[KEY_COOKIE] = @cookies.to_s
				response = http.request(Net::HTTP::Post.new(uri, @header), data)
				@cookies.update(response[KEY_SET_COOKIE]) if response[KEY_SET_COOKIE]
				return response.body
			end
		end

		def self.uri_https(host, path = DEFAULT_PATH, queries = DEFAULT_QUERIES)
			URI::HTTPS.build(
				host: host,
				path: path,
				query: URI.encode_www_form(queries)
			)
		end

		def self.uri_http(host, path = DEFAULT_PATH, queries = DEFAULT_QUERIES)
			URI::HTTP.build(
				host: host,
				path: path,
				query: URI.encode_www_form(queries)
			)
		end

		def uri_https(host, path = DEFAULT_PATH, queries = DEFAULT_QUERIES)
			URI::HTTPS.build(
				host: host,
				path: path,
				query: URI.encode_www_form(queries)
			)
		end

		def uri_http(host, path = DEFAULT_PATH, queries = DEFAULT_QUERIES)
			URI::HTTP.build(
				host: host,
				path: path,
				query: URI.encode_www_form(queries)
			)
		end

		private

		def log(message, level = Logger::INFO)
			@logger.log(level, message, self.class.name)
		end
	end
end