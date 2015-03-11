# -*- coding: utf-8 -*-

require 'logger'
require 'net/http'
require 'net/https'
require 'thread'
require 'uri'
require 'time'

class HttpClient < Mutex
	# 单条Cookie
	class Cookie
		attr_reader :name
		attr_accessor :value, :domain, :path, :expires, :secure

		class << self
			def parse(string)
				value_field, *other_fields = string.split(/; ?/)
				new(*value_field.split('=', 2).map(&:strip)).tap do |cookie|
					other_fields.each do |filed|
						key, val = filed.split(/=/, 2)
						case key.downcase
						when 'domain'  then cookie.domain  = val.strip
						when 'path'    then cookie.path    = val.strip
						when 'expires' then cookie.expires = Time.parse(val)
						when 'secure'  then cookie.secure  = true
						else # do nothing
						end
					end
				end
			end
		end

		def initialize(name, value, domain = nil, path = nil, expires = nil, secure = nil)
			@name, @value, @domain, @path, @expires, @secure = name, value, domain, path, expires, secure
		end

		def expired?
			@expires && @expires <= Time.now
		end

		def to_s
			"#{@name}=#{@value}"
		end
	end

	# Cookie管理
	class CookieJar
		include Enumerable

		def initialize
			@mutex = Mutex.new
			@cookies_by_domain = Hash.new do |cookies_by_domain, domain|
				cookies_by_domain[domain] = Hash.new do |cookies_by_path, path|
					cookies_by_path[path] = {}
				end
			end
		end

		# 获取Cookie
		def [](domain, path, name)
			mutex.synchronize do
				@cookies_by_domain[domain][path][name]
			end
		end

		# 更新Cookie
		def update!(strings)
			clear_expired
			(strings || []).each do |string|
				self << Cookie.parse(string)
			end
			self
		end

		def each(&block)
			mutex.synchronize do
				@cookies_by_domain.each_value do |cookies_by_path|
					cookies_by_path.each_value do |cookies_by_name|
						cookies_by_name.each_value(&block)
					end
				end
			end
			self
		end

		# @param [Cookie] cookie
		def <<(cookie)
			mutex.synchronize do
				@cookies_by_domain[cookie.domain][cookie.path][cookie.name] = cookie
			end
			self
		end

		# @param [Net::HTTPGenericRequest] request
		def filter(request)
			cookies = []
			mutex.synchronize do
				@cookies_by_domain.each_pair do |domain, cookies_by_path|
					next unless request.uri.host.end_with?(domain)
					cookies_by_path.each_pair do |path, cookies_by_name|
						next unless request.uri.path.start_with?(path)
						cookies_by_name.each_value do |cookie|
							cookies << cookie unless cookie.secure && request.uri.scheme != 'https' || cookie.expired?
						end
					end
				end
			end
			cookies
		end

		def clear_expired
			each do |cookie|
				clear(cookie.domain, cookie.path, cookie.name) if cookie.expired?
			end
		end

		def to_s(request)
			filter(request).join('; ')
		end

		protected

		attr_reader :mutex

		private

		def clear(domain, path, name)
			if name
				raise 'domain and path must be given to remove a cookie by name' unless domain && path
				@cookies_by_domain[domain][path].delete(name)
			elsif path
				raise 'domain must be given to remove cookies by path' unless domain
				@cookies_by_domain[domain].delete(path)
			elsif domain
				@cookies_by_domain.delete(domain)
			else
				@cookies_by_domain = {}
			end
		end
	end

	include Logger::Severity

	attr_reader :header, :cookies

	DEFAULT_TIMEOUT = 3

	def initialize
		@http_client_logger = Logger.new("#{File.dirname(__FILE__)}/http_client.log", 1)
		@http_client_logger.formatter = proc do |severity, datetime, program_name, message|
			<<FORMAT % {datetime: datetime, program_name: program_name, severity: severity, message: message}
[%<datetime>s][%<severity>5s][%<program_name>s]
%<message>s
FORMAT
		end
		@header = {}
		@cookies = CookieJar.new
	end

	# @param [URI] uri
	# @param [Hash] header
	# @param [Numeric] timeout
	# @return [String]
	def get(uri, header = nil, timeout = nil)
		synchronize do
			request = Net::HTTP::Get.new(uri, (header || {}).merge(@header))
			send_request(request, (timeout || DEFAULT_TIMEOUT))
		end
	end

	# @param [URI] uri
	# @param [String] data
	# @param [Hash] header
	# @param [Numeric] timeout
	# @return [String]
	def post(uri, data, header = nil, timeout = nil)
		synchronize do
			request = Net::HTTP::Post.new(uri, (header || {}).merge(@header))
			request.set_form_data(data)
			send_request(request, (timeout || DEFAULT_TIMEOUT))
		end
	end

	protected

	attr_writer :header, :cookies

	private

	self.class_eval do
		log_request = ->(logger, request){
			logger.add(DEBUG, <<REQUEST, Thread.current)
Request #{request} #{request.method} #{request.uri}
#{request.to_hash.map{|key, value| "#{key}: #{value}"}.join("\n") }
data:
#{request.body.inspect}
REQUEST
		}

		log_response = ->(logger, request, response){
			logger.add(DEBUG, <<RESPONSE, Thread.current)
Response #{response} to #{request} #{request.method} #{request.uri}
#{response.to_hash.map{|key, value| "#{key}: #{value}"}.join("\n")}
data:
#{response.body.inspect}
RESPONSE
		}

		define_method :send_request do |request, timeout|
			request['Cookie'] = cookies.to_s(request)
			response = nil

			log_request[@http_client_logger, request] if $-d

			#noinspection RubyResolve
			Net::HTTP.start(
				request.uri.host,
				request.uri.port,
				read_timeout: timeout,
				use_ssl: request.uri.scheme == 'https',
				verify_mode: OpenSSL::SSL::VERIFY_NONE,
			) do |http|
				response = http.request(request)
			end

			log_response[@http_client_logger, request, response] if $-d

			cookies.update!((response['Set-Cookie'] || '').split(';, '))

			response.body

		end
	end
end