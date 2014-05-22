# -*- coding: utf-8 -*-

require 'uri'
require 'net/http'
require 'net/https'
#noinspection SpellCheckingInspection
require 'webrick/cookie'
require 'logger'

module WebQQProtocol
	class Net
		KEY_COOKIE = 'Cookie'
		KEY_SET_COOKIE = 'Set-Cookie'
		DEFAULT_PATH = '/'
		DEFAULT_QUERIES = {}
		SCHEME_HTTPS = 'https'

		LOG_FILE = 'net.log'

		LOGON = false

		TIMEOUT = 5

		def logger
			@logger ||= Logger.new(LOG_FILE, File::WRONLY | File::APPEND | File::CREAT)
		end

		# Cookie处理辅助类
		class Cookies
			def initialize
				@cookies = {}
			end

			# 更新Cookie
			def set!(str)
				return unless str
				time = Time.now
				@cookies.delete_if { |_, cookie| cookie.expires and cookie.expires < time }
				WEBrick::Cookie.parse_set_cookies(str).each do |cookie|
					@cookies[cookie.name] = cookie unless cookie.expires and cookie.expires < time
				end
			end

			def [](key)
				@cookies[key].value
			end

			def to_s
				@cookies.map{|_, cookie| "#{cookie.name}=#{cookie.value}"}.join('; ')
			end
		end

		attr_accessor :header, :cookies

		def initialize
			@header = {}
			@cookies = Cookies.new
		end

		def send(request)
			header['Cookie'] = cookies.to_s
			uri = request.uri
			response = nil
			#noinspection RubyResolve
			Net::HTTP.start(
				uri.host,
				uri.port,
				read_timeout: TIMEOUT,
				use_ssl: uri.scheme == SCHEME_HTTPS,
				verify_mode: OpenSSL::SSL::VERIFY_NONE
			) do |http|
				if $-d
					log("Request URL: #{request.uri}", Logger::DEBUG)
					log("Request Method: #{request.method}", Logger::DEBUG)
					log("Request Header: #{request.to_hash}")
					log("Request Body: #{request.body}")
				end
				response = http.request(request)
				if $-d
					log("Response Header: #{response.to_hash}")
					log("Response Body: #{response.body}")
				end
			end
			cookies.set!(response['Set-Cookie'])
			response
		end

		def get(host, path, query = {})
			request = Net::HTTP::Get.new(
				URI::HTTPS.build(
					host: host,
					path: path,
					query: URI.encode_www_form(query)
				),
				header
			)
			send(request).body
		end

		def get2(uri)
			request = Net::HTTP::Get.new(
				uri,
				header
			)
			request.body = data
			send(request).body
		end

		def post(host, path, data)
			request = Net::HTTP::Get.new(
				URI::HTTPS.build(
					host: host,
					path: path,
				),
				header
			)
			request.body = data
			send(request).body
		end

		def post2(uri, data)
			request = Net::HTTP::Get.new(
				uri,
				header
			)
			request.body = data
			send(request).body
		end

		private

		def log(message, level = Logger::INFO)
			@logger.log(level, message, self.class.name)
		end
	end
end