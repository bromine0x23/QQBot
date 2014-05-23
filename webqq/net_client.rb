# -*- coding: utf-8 -*-

require 'logger'
require 'uri'
require 'net/http'
require 'net/https'

#noinspection SpellCheckingInspection
require 'webrick/cookie'

module WebQQProtocol
	class NetClient
		TIMEOUT = 5

		# Cookie处理辅助类
		class Cookies
			def initialize
				@cookies = {}
			end

			# 更新Cookie
			def update!(str)
				time = Time.now
				@cookies.delete_if { |_, cookie| not cookie or (cookie.expires and cookie.expires < time) }
				return unless str
				WEBrick::Cookie.parse_set_cookies(str).each do |cookie|
					unless cookie.expires and cookie.expires < time
						@cookies[cookie.name] = cookie
					end
				end
			end

			def [](key)
				@cookies[key].value
			end

			def add!(cookie)
				@cookies[cookie.name] = cookie
			end

			def clean
				@cookies.delete_if { |_, cookie| not cookie or not cookie.expires }
			end

			def to_s(request)
				@cookies.select { |_, cookie|
					cookie and request.uri.host.end_with?(cookie.domain) and request.uri.path.start_with?(cookie.path)
				}.values.map! { |cookie|
					"#{cookie.name}=#{cookie.value}"
				}.join('; ')
			end
		end

		attr_accessor :header, :cookies

		def initialize(logger)
			@header = {}
			@cookies = Cookies.new
			@logger = logger
		end

		# @param [Net::HTTPGenericRequest] request
		# @return [Net::HTTPResponse]
		def send(request, timeout = TIMEOUT)
			request['cookie'] = cookies.to_s(request)
			response = nil

			if $-d
				log('======== send ========', Logger::DEBUG)
				log("Request URL: #{request.uri}", Logger::DEBUG)
				log("Request Method: #{request.method}", Logger::DEBUG)
				log("Request Header: \n#{request.to_hash.map { |key, value| "#{key}: #{value}" }.join("\n") }")
				log("Request Body: \n#{request.body}")
			end

			#noinspection RubyResolve
			Net::HTTP.start(
				request.uri.host,
				request.uri.port,
				read_timeout: timeout,
				use_ssl: request.uri.scheme == 'https',
				verify_mode: OpenSSL::SSL::VERIFY_NONE
			) do |http|
				response = http.request(request)
			end

			if $-d
				log("Response Header: \n#{response.to_hash.map { |key, value| "#{key}: #{value}" }.join("\n")}")
				log("Response Body: \n#{response.body}")
				log('======== end ========', Logger::DEBUG)
			end
			cookies.update!(response['set-cookie'])
			response
		end

		# @param [URI] uri
		# @return [String]
		def uri_get(uri)
			send(
				Net::HTTP::Get.new(
					uri,
					header
				)
			).body
		end

		# @param [URI] uri
		# @return [String]
		def uri_post(uri, data = {})
			request = Net::HTTP::Post.new(
				uri,
				header
			)
			request.set_form_data(data)
			send(request).body
		end

		# @param [String] host
		# @param [String] path
		# @param [Hash] query
		# @return [String]
		def get(generator, host, path, query = {})
			uri_get(
				generator.build(
					host: host,
					path: path,
					query: URI.encode_www_form(query)
				)
			)
		end

		# @param [String] host
		# @param [String] path
		# @param [String] data
		# @return [String]
		def post(generator, host, path, data = {})
			uri_post(
				generator.build(
					host: host,
					path: path,
				),
				data
			)
		end

		def http_get(host, path, query = {})
			get(URI::HTTP, host, path, query)
		end

		def https_get(host, path, query)
			get(URI::HTTPS, host, path, query)
		end

		def http_post(host, path, data)
			post(URI::HTTP, host, path, data)
		end

		def https_post(host, path, data)
			post(URI::HTTPS, host, path, data)
		end

		def self.json_result(data)
			json_data = JSON.parse(data)
			retcode = json_data['retcode']
			raise ErrorCode.new(retcode, json_data) unless retcode == 0 or retcode == 6
			json_data['result']
		end

		private

		def log(message, level = Logger::INFO)
			@logger.log(level, message, self.class.name)
		end
	end
end