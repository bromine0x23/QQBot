# -*- coding: utf-8 -*-

require 'json'
require 'logger'
require 'uri'
require 'net/http'
require 'net/https'
require 'webrick/cookie'

# WebQQ客户端
module WebQQProtocol
	APPID = 1003903
	JS_VER = 10071
	JS_TYPE = 0
	LOGIN_SIG = 'EDCv9dZdzXo5FchLpEEgEk-coa77jI5yM8L7rEhPWJCYGQlEMBdf5fRmccPqtHKt'

	HOST_SSL_PTLOGIN2_QQ = 'ssl.ptlogin2.qq.com'
	HOST_D_WEB2_QQ       = 'd.web2.qq.com'
	HOST_S_WEB2_QQ       = 's.web2.qq.com'

	JSON_KEY_ACCOUNT    = 'account'
	JSON_KEY_CARD       = 'card'
	JSON_KEY_CARDS      = 'cards'
	JSON_KEY_CODE       = 'code'
	JSON_KEY_FRIENDS    = 'friends'
	JSON_KEY_GID        = 'gid'
	JSON_KEY_GNAMELIST  = 'gnamelist'
	JSON_KEY_INFO       = 'info'
	JSON_KEY_MARKNAME   = 'markname'
	JSON_KEY_MARKNAMES  = 'marknames'
	JSON_KEY_MINFO      = 'minfo'
	JSON_KEY_MUIN       = 'muin'
	JSON_KEY_NAME       = 'name'
	JSON_KEY_NICK       = 'nick'
	JSON_KEY_PSESSIONID = 'psessionid'
	JSON_KEY_RETCODE    = 'retcode'
	JSON_KEY_RESULT     = 'result'
	JSON_KEY_TUIN       = 'tuin'
	JSON_KEY_UIN        = 'uin'
	JSON_KEY_VFWEBQQ    = 'vfwebqq'


	COOKIE_KEY_PTWEBQQ = 'ptwebqq'

	HEADER_KEY_USER_AGENT = 'User-Agent'
	HEADER_KEY_COOKIE     = 'Cookie'
	HEADER_KEY_REFERER    = 'Referer'
	HEADER_USER_AGENT = 'Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/33.0.1750.154 Safari/537.36'
	HEADER_REFERER    = 'https://d.web2.qq.com/cfproxy.html?v=20110331002&callback=1'

	# 网络通信辅助类
	class NetClient
		KEY_COOKIE = 'Cookie'
		KEY_SET_COOKIE = 'Set-Cookie'
		DEFAULT_PATH = '/'
		DEFAULT_QUERIES = {}
		SCHEME_HTTPS = 'https'

		# Cookie处理辅助类
		class Cookie
			def initialize
				@cookies = {}
			end

			# 更新Cookie
			def update!(str)
				time = Time.now
				@cookies.delete_if { |_, cookie| cookie.expires and cookie.expires < time }
				WEBrick::Cookie.parse_set_cookies(str).each { |cookie| @cookies[cookie.name] = cookie if not cookie.expires or cookie.expires > time }
			end

			def [](key)
				@cookies[key].value
			end

			def to_s
				@cookies.map{|_, cookie| "#{cookie.name}=#{cookie.value}"}.join('; ')
			end
		end

		attr_reader :header, :cookies

		def initialize(logger)
			@header = {}
			@cookies = Cookie.new
			@logger = logger
		end

		def add_header(key, value)
			@header[key] = value
		end

		def get(uri)
			log("HTTP GET: #{uri}", Logger::DEBUG) if $-d
			#noinspection RubyResolve
			Net::HTTP.start(uri.host, uri.port, read_timeout: 10, use_ssl: uri.scheme == SCHEME_HTTPS, verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
				@header[KEY_COOKIE] = @cookies.to_s
				response = http.request(Net::HTTP::Get.new(uri, @header))
				log("BODY: #{response.body.strip}", Logger::DEBUG) if $-d
				@cookies.update!(response[KEY_SET_COOKIE]) if response[KEY_SET_COOKIE]
				return response.body
			end
		end

		def post(uri, data)
			log("HTTP POST: #{uri}\nDATA: #{data}", Logger::DEBUG) if $-d
			#noinspection RubyResolve
			Net::HTTP.start(uri.host, uri.port, read_timeout: 10, use_ssl: uri.scheme == SCHEME_HTTPS, verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
				@header[KEY_COOKIE] = @cookies.to_s
				response = http.request(Net::HTTP::Post.new(uri, @header), data)
				log("BODY: #{response.body.strip}", Logger::DEBUG) if $-d
				@cookies.update!(response[KEY_SET_COOKIE]) if response[KEY_SET_COOKIE]
				return response.body
			end
		end

		private

		def log(message, level = Logger::INFO)
			@logger.log(level, message, self.class.name)
		end
	end

	# 异常类：WebQQ通信错误码
	class ErrorCode < Exception
		attr_reader :error_code, :raw_data

		def initialize(error_code, raw_data = nil)
			super()
			@error_code = error_code
			@raw_data = raw_data
		end

		def message
			"WebQQ return code: #{@error_code}, raw_data: #{@raw_data}"
		end
	end

	# 异常类：WebQQ登录失败
	class LoginFailed < Exception
		attr_reader :state, :info

		def initialize(state, info)
			super()
			@state = state
			@info = info
		end

		def message
			"WebQQ login failed: state => #{@state}, info => #{@info}"
		end
	end

	# 哈希算法
	module Encrypt
		# 密码加密
		def self.encrypt_password(password, verify_code, key)
			md5(md5(hex2ascii(md5(password) + key.gsub!(/\\x/, ''))) + verify_code)
		end

		# 腾讯迷の哈希
		def self.hash_friends(b, i)
			a = [0, 0, 0, 0]
			i.bytes.each_with_index { |c, s| a[s % 4] ^= c.ord }
			d = [
				b >> 24 & 255 ^ 69, # 69 => E
				b >> 16 & 255 ^ 67, # 67 => C
				b >>  8 & 255 ^ 79, # 79 => O
				b >>  0 & 255 ^ 75  # 75 => K
			]
			j = Array.new(8) {|s| s % 2 == 0 ? a[s >> 1] : d[s >> 1]}
			a = '0123456789ABCDEF'
			d = ''
			j.each do |c|
				d += a[c >> 4 & 15] + a[c & 15]
			end
			d
		end

		private

		# 将十六进制数字串每两个编码为ASCII码对应的字符
		def self.hex2ascii(hex_str)
			hex_str.scan(/\w{2}/).map { |byte_str| byte_str.to_i(16).chr }.join
		end

		# MD5哈希
		#noinspection RubyResolve
		def self.md5(src)
			Digest::MD5.hexdigest(src).upcase
		end
	end

	# 封装消息接收线程
	class MessageReceiver
		TIMEOUT = 120
		REDO_LIMIT = 10

		attr_reader :thread

		# 创建接收线程
		def initialize(client_id, p_session_id ,cookies, logger)
			@logger = logger
			@messages= Queue.new
			@thread = Thread.new do
				log('线程启动……', Logger::DEBUG)
				redo_count = 0
				begin
					http = Net::HTTP.start(HOST_D_WEB2_QQ, read_timeout: TIMEOUT)
					request = Net::HTTP::Post.new(
						'/channel/poll2',
						HEADER_KEY_USER_AGENT => HEADER_USER_AGENT,
						HEADER_KEY_REFERER => HEADER_REFERER,
						HEADER_KEY_COOKIE => cookies
					)
					request.set_form_data(
						r: JSON.fast_generate(clientid: client_id, psessionid: p_session_id, key: 0, ids: []),
						clientid: client_id,
						psessionid: p_session_id
					)
					loop do
						begin
							json_data = JSON.parse(http.request(request).body)
							raise ErrorCode.new(json_data[JSON_KEY_RETCODE], json_data) unless json_data[JSON_KEY_RETCODE] == 0
							@messages.push json_data[JSON_KEY_RESULT]
						rescue WebQQProtocol::ErrorCode => ex
							case ex.error_code
							when 102, 116
								next
							when 103, 108, 114, 120, 121
								log("poll时遭遇错误代码：#{ex.error_code}", Logger::ERROR)
								raise ex
							else
								log("poll时遭遇未知代码：#{ex.error_code}", Logger::FATAL)
								raise ex
							end
						end
					end
				rescue Exception => ex
					log(<<LOG.strip, Logger::ERROR)
捕获到异常：#{ex.message}
调用栈：
#{ex.backtrace.join("\n")}
LOG
					redo_count += 1
					if redo_count > REDO_LIMIT
						log("重试超过#{REDO_LIMIT}次，退出", Logger::FATAL)
						raise ex
					end
					log('重试', Logger::ERROR)
					redo
				end
			end
		end

		# 读取数据
		def data
			@messages.pop
		end

		private

		def log(message, level = Logger::INFO)
			@logger.log(level, message, self.class.name)
		end
	end

	# 封装消息发送线程
	class MessageSender
		STRING_FONT = 'font'
		DEFAULT_FONT_FACE = '宋体'
		DEFAULT_COLOR = '000000'
		REDO_LIMIT = 10

		attr_reader :thread

		# 创建发送线程
		def initialize(out_client_id, out_p_session_id, cookies, logger)
			@logger = logger
			@messages= Queue.new
			@thread = Thread.new(
				out_client_id,
				out_p_session_id,
				HEADER_KEY_USER_AGENT => HEADER_USER_AGENT,
				HEADER_KEY_REFERER => HEADER_REFERER,
				HEADER_KEY_COOKIE => cookies
			) do |client_id, p_session_id, init_header|
				log('线程启动……', Logger::DEBUG)
				redo_count = 0
				begin
					#noinspection RubyResolve
					https = Net::HTTP.start(HOST_D_WEB2_QQ, 443, use_ssl: true, verify_mode: OpenSSL::SSL::VERIFY_NONE)
					request_buddy = Net::HTTP::Post.new('/channel/send_buddy_msg2', init_header)
					request_qun   = Net::HTTP::Post.new('/channel/send_qun_msg2', init_header)
					message_counter = Random.rand(1000...10000) * 10000
					raw_data = {
						to: nil,
						group_uin: nil,
						content: nil,
						msg_id: nil,
						clientid: client_id,
						psessionid: p_session_id
					}
					data = {
						r: nil,
						clientid: client_id,
						psessionid: p_session_id
					}
					loop do
						message = @messages.pop
						begin
							case message[:type]
							when :group_message
								raw_data[:group_uin] = message[:uin]
								request = request_qun
							when :message
								raw_data[:to] = message[:uin]
								request = request_buddy
							else
								next
							end

							message_counter += 1

							raw_data[:content] = encode_content(message[:message], message[:font])
							raw_data[:msg_id]  = message_counter

							data[:r] = JSON.fast_generate(raw_data)

							request.set_form_data(data)
							log("HTTP POST：#{request.path} BODY：#{request.body}", Logger::DEBUG) if $-d

							json_data = JSON.parse(https.request(request).body)
							log("RESPONSE：#{json_data}", Logger::DEBUG) if $-d

							raise ErrorCode.new(json_data[JSON_KEY_RETCODE], json_data) unless json_data[JSON_KEY_RETCODE] == 0
						rescue EOFError
							log('网络异常，无法发送消息，重试……', Logger::ERROR)
							retry
						end
					end
				rescue Exception => ex
					log(<<LOG.strip, Logger::ERROR)
捕获到异常：#{ex.message}
调用栈：
#{ex.backtrace.join("\n")}
LOG
					redo_count += 1
					if redo_count > REDO_LIMIT
						log("重试超过#{REDO_LIMIT}次，退出", Logger::FATAL)
						raise ex
					end
					log('重试', Logger::ERROR)
					redo
				end
			end
		end

		# 发送消息
		def send_message(uin, message, font)
			@messages.push(
				type: :message,
				uin: uin,
				message: message,
				font: font
			)
			self
		end

		# 发送群消息
		def send_group_message(uin, message, font)
			@messages.push(
				type: :group_message,
				uin: uin,
				message: message,
				font: font
			)
			self
		end

		private

		def log(message, level = Logger::INFO)
			@logger.log(level, message, self.class.name)
		end

		# 编码内容数据
		def encode_content(message, font)
			JSON.fast_generate(
				[
					message,
					'',
					[
						STRING_FONT,
						{
							name: font[:name] || DEFAULT_FONT_FACE,
							size: font[:size] || 10,
							style: [
								font[:bold] ? 1 : 0,
								font[:italic] ? 1 : 0,
								font[:underline] ? 1 : 0
							],
							color: font[:color] || DEFAULT_COLOR
						}
					]
				]
			)
		end
	end

	class QQEntity
		TYPE = 'QQ实体'

		attr_reader :uin, :number, :name

		def initialize(uin, number, name)
			@uin    = uin
			@number = number
			@name   = name
		end

		def to_s
			"#{self.class::TYPE} #{@name}(#{@number})"
		end
	end

	# QQ好友类
	class QQFriend < QQEntity
		TYPE = 'QQ好友'
	end

	class QQGroupMember < QQEntity
		TYPE = 'QQ群成员'
	end

	# QQ群类
	class QQGroup < QQEntity
		TYPE = 'QQ群'

		attr_reader :code, :members

		# @param [WebQQProtocol::Client] client
		def initialize(client, group)
			@code = group[JSON_KEY_CODE]
			super(group[JSON_KEY_GID], client.fetch_group_number(@code), group[JSON_KEY_NAME])
			info = client.fetch_group_info(@code)
			member_names = Hash[info[JSON_KEY_MINFO].map!{ |minfo| [minfo[JSON_KEY_UIN], minfo[JSON_KEY_NICK]] }]
			member_names.merge!(Hash[info[JSON_KEY_CARDS].map!{ |card| [card[JSON_KEY_MUIN], card[JSON_KEY_CARD]] }]) if info[JSON_KEY_CARDS]
			@members = Hash.new{ |hash, key| hash[key] = QQGroupMember.new(key, client.fetch_qq_number(key), member_names[key]) }
		end

		# @return [WebQQProtocol::QQGroupMember]
		def member(uin)
			@members[uin]
		end
	end

	#noinspection RubyTooManyInstanceVariablesInspection
	class Client
		GET_FRIENDS_HELLO_MESSAGE = 'hello'

		PATH_LOGOUT2 = '/channel/logout2'
		PATH_GET_GROUP_NAME_LIST_MASK2 = '/api/get_group_name_list_mask2'
		PATH_GET_USER_FRIENDS2 = '/api/get_user_friends2'
		PATH_GET_FRIEND_UIN2 = '/api/get_friend_uin2'
		PATH_GET_FRIEND_INFO2 = '/api/get_friend_info2'
		PATH_GET_GROUP_INFO_EXT2 = '/api/get_group_info_ext2'
		PATH_ALLOW_AND_ADD2 = '/api/allow_and_add2'

		URI_GET_GROUP_NAME_LIST_MASK2 = URI::HTTP.build(
			host: HOST_S_WEB2_QQ,
			path: PATH_GET_GROUP_NAME_LIST_MASK2
		)
		URI_GET_USER_FRIENDS2 = URI::HTTP.build(
			host: HOST_S_WEB2_QQ,
			path: PATH_GET_USER_FRIENDS2
		)
		URI_ALLOW_AND_ADD2 = URI::HTTP.build(
			host: HOST_S_WEB2_QQ,
			path: PATH_ALLOW_AND_ADD2
		)

		attr_reader :qq, :nickname
		attr_reader :receiver, :sender
		attr_reader :groups, :friends

		def initialize(qq, nickname, client_id, random_key, ptwebqq, p_session_id, uin, verify_webqq, net_client, logger)
			@qq = qq
			@nickname = nickname
			@client_id = client_id
			@random_key = random_key
			@verify_webqq = verify_webqq
			@p_session_id = p_session_id
			@uin = uin
			@ptwebqq = ptwebqq
			@net_client = net_client

			@receiver = MessageReceiver.new(@client_id, @p_session_id, @net_client.cookies.to_s, logger)
			@sender   = MessageSender.new(@client_id, @p_session_id, @net_client.cookies.to_s, logger)

			group_list = Hash[fetch_groups[JSON_KEY_GNAMELIST].map!{ |gname| [gname[JSON_KEY_GID], gname] }]
			@groups = Hash.new{ |hash, key| hash[key] = QQGroup.new(self, group_list[key]) }

			json_data = fetch_friends
			friend_list = Hash[json_data[JSON_KEY_MARKNAMES].map!{|markname| [markname[JSON_KEY_UIN], markname[JSON_KEY_MARKNAME]] }].merge!(Hash[json_data[JSON_KEY_INFO].map!{|info| [info[JSON_KEY_UIN], info[JSON_KEY_NICK]]}])
			@friends = Hash.new{ |hash, key| hash[key] = QQFriend.new(key, fetch_qq_number(key), friend_list[key]) }
		end

		# @return [WebQQProtocol::QQGroup]
		def group(uin)
			@groups[uin]
		end

		# @return [WebQQProtocol::QQFriend]
		def friend(uin)
			@friends[uin]
		end

		# @return [WebQQProtocol::QQEntity]
		def entity(uin)
			group(uin) || friend(uin)
		end

		# 添加好友
		def add_friend(account)
			json_data = allow_add_friend(account)
			uin = json_data[JSON_KEY_TUIN]
			@friends[uin] = QQFriend.new(uin, json_data[JSON_KEY_ACCOUNT], fetch_friend_info(uin)[JSON_KEY_NICK])
		end

		# 登出
		def logout
			uri = URI::HTTPS.build(
				host: HOST_D_WEB2_QQ,
				path: PATH_LOGOUT2,
				query: URI.encode_www_form(
					ids: nil,
					clientid: @client_id,
					psessionid: @p_session_id,
					t: Time.now.to_i
				)
			)
			get_request(uri)
			true
		end

		# HTTP POST 请求，返回解析后的 json 数据的 result 键对应的值
		def post_request(raw_data, uri)
			data = URI.encode_www_form(
				r: raw_data,
				clientid: @client_id,
				psessionid: @p_session_id
			)
			json_data = JSON.parse(@net_client.post(uri, data))
			raise ErrorCode.new(json_data[JSON_KEY_RETCODE], json_data) unless json_data[JSON_KEY_RETCODE] == 0
			json_data[JSON_KEY_RESULT]
		end

		# HTTP GET 请求，返回解析后的 json 数据的 result 键对应的值
		def get_request(uri)
			json_data = JSON.parse(@net_client.get(uri))
			raise ErrorCode.new(json_data[JSON_KEY_RETCODE], json_data) unless json_data[JSON_KEY_RETCODE] == 0
			json_data[JSON_KEY_RESULT]
		end

		# 获取群信息
=begin
{
	"gmarklist": [],
	"gmasklist": [],
    "gnamelist": [ { "flag": 0, "name": "", "gid": 0, "code": 0 }, ...... ]
}
=end
		def fetch_groups
			post_request(JSON.fast_generate(vfwebqq: @verify_webqq), URI_GET_GROUP_NAME_LIST_MASK2)
		end

		# 获取好友信息
=begin
{
	# 分组信息
	"categories": [ { index: 0, sort: 0, name: "" }, ...... ]
	"friends": [ { "flag": 0,"uin": 0,"categories": 0 }, ...... ],
	# 备注
	"marknames": [ {"uin": 0, "markname": "", "type": 0 }, ...... ],
	# VIP信息
	"vipinfo": [ { "vip_level": 0, "u": 0, "is_vip": 0 }, ...... ],
	"info": [ { "face": 0, "flag": 0, "nick": "", "uin": 0 }, ...... ]
}
=end
		def fetch_friends
			post_request(
				JSON.fast_generate(
					h: GET_FRIENDS_HELLO_MESSAGE,
					hash: Encrypt.hash_friends(@uin, @ptwebqq),
					vfwebqq: @verify_webqq
				),
				URI_GET_USER_FRIENDS2
			)
		end

		# 通过 uin 获取 QQ 号
=begin
{ "uiuin": "", "account": 0, "uin": 0 }
=end
		def fetch_qq_number(uin)
			uri = URI::HTTP.build(
				host: HOST_S_WEB2_QQ,
				path: PATH_GET_FRIEND_UIN2,
				query: URI.encode_www_form(
					tuin: uin,
					verifysession: nil,
					type: 1,
					code: nil,
					vfwebqq: @verify_webqq,
					t: Time.now.to_i
				)
			)
			get_request(uri)[JSON_KEY_ACCOUNT]
		end

		# 通过 uin 获取群号
=begin
{ "uiuin": "", "account": 0, "uin": 0 }
=end
		def fetch_group_number(uin)
			uri = URI::HTTP.build(
				host: HOST_S_WEB2_QQ,
				path: PATH_GET_FRIEND_UIN2,
				query: URI.encode_www_form(
					tuin: uin,
					verifysession: nil,
					type: 4,
					code: nil,
					vfwebqq: @verify_webqq,
					t: Time.now.to_i
				)
			)
			get_request(uri)[JSON_KEY_ACCOUNT]
		end

		# 通过 uin 获取好友信息
=begin
{
	"face": 0,
	"birthday": { "month": 0, "year": 0, "day": 0 },
	"occupation": "",
	"phone": "",
	"allow": 0,
	"college": "",
	"uin": 0,
	"constel": 0,
	"blood": 0,
	"homepage": "",
	"stat": 0,
	"vip_info": 0,
	"country": "",
	"city": "",
	"personal": "",
	"nick": "XXX",
	"shengxiao": 0,
	"email": "",
	"client_type": 0,
	"province": "",
	"gender": "male",
	"mobile": ""
}
=end
		def fetch_friend_info(uin)
			uri = URI::HTTP.build(
				host: HOST_S_WEB2_QQ,
				path: PATH_GET_FRIEND_INFO2,
				query: URI.encode_www_form(
					tuin: uin,
					verifysession: nil,
					code: nil,
					vfwebqq: @verify_webqq,
					t: Time.now.to_i
				)
			)
			get_request(uri)
		end

		# 通过 uin 获取群信息
=begin
{
	# 在线成员列表
	"stats": [ { "client_type":, "uin":, "stat": }, ...... ]
	# 成员信息
	"minfo": [ { "nick":, "province":, "gender":, "male":, "uin":, "country":, "city": }, ...... ],
	# 群信息
	"ginfo":{
		"face":, "memo":, "class":, "fingermemo":, "code":, "createtime":, "flag":, "level":, "name":, "gid":, "owner":, "option":,
		"members": [ { "muin":, "mflag": }, ...... ]
	},
	# 群名片
	"cards":[ { "muin":, "card":"XXX" }, ...... ]
}
=end
		def fetch_group_info(group_code)
			uri = URI::HTTP.build(
				host: HOST_S_WEB2_QQ,
				path: PATH_GET_GROUP_INFO_EXT2,
				query: URI.encode_www_form(
					gcode: group_code,
					vfwebqq: @verify_webqq,
					t: Time.now.to_i
				)
			)
			get_request(uri)
		end

		# 同意添加好友
=begin
{ "result1": 0, "account": "10000" ,  "tuin": "uin", "stat": 10 }
=end
		def allow_add_friend(account)
			raw_data = JSON.fast_generate(
				account: account,
				gid: 0,
				mname: '',
				vfwebqq: @verify_webqq
			)
			post_request(raw_data, URI_ALLOW_AND_ADD2)
		end
	end

	# 登录
	def self.login(qq, password, logger, on_captcha_need = self.method(:default_on_captcha_need))
		log(logger, '开始登陆……', Logger::DEBUG) if $-d

		client_id  = Random.rand(10000000...100000000) # 客户端id
		random_key = Random.rand

		net_helper = NetClient.new(logger)
		net_helper.add_header(HEADER_KEY_USER_AGENT, HEADER_USER_AGENT)

		ptwebqq = nil
		p_session_id = nil
		uin = nil
		verify_webqq = nil
		begin
			# 第一次握手
			log(logger, '拉取验证信息……', Logger::DEBUG) if $-d
			uri = URI::HTTPS.build(
				host: HOST_SSL_PTLOGIN2_QQ,
				path: '/check',
				query: URI.encode_www_form(
					uin: qq,
					appid: APPID,
					js_ver: JS_VER,
					js_type: JS_TYPE,
					login_sig: LOGIN_SIG,
					u1: 'http://web2.qq.com/loginproxy.html',
					r: random_key
				)
			)
			need_verify, verify_code, key = net_helper.get(uri).scan(/'.*?'/).map{|str| str[1..-2]}
			log(logger, "是否需要验证码： #{need_verify}", Logger::DEBUG) if $-d
			log(logger, "密钥： #{key}", Logger::DEBUG) if $-d

			if need_verify != '0'
				# 需要验证码
				log(logger, '获取验证码……', Logger::DEBUG) if $-d
				uri = URI::HTTPS.build(
					host: 'ssl.captcha.qq.com',
					path: '/getimage',
					query: URI.encode_www_form(
						uin: qq,
						aid: APPID,
						r: random_key
					)
				)
				verify_code = on_captcha_need.call(net_helper.get(uri))
				log(logger, "验证码： #{verify_code}", Logger::DEBUG) if $-d
			end

			log(logger, "密码：#{password}", Logger::DEBUG) if $-d

			#加密密码
			log(logger, '加密密码……', Logger::DEBUG) if $-d
			password_encrypted = Encrypt.encrypt_password(password, verify_code, key)
			log(logger, "密码加密为：#{password_encrypted}", Logger::DEBUG) if $-d

			# 验证账号
			log(logger, '验证账号……', Logger::DEBUG) if $-d
			uri = URI::HTTPS.build(
				host: HOST_SSL_PTLOGIN2_QQ,
				path: '/login',
				query: URI.encode_www_form(
					u: qq,
					p: password_encrypted,
					verifycode: verify_code.upcase,
					webqq_type: 10,
					remember_uin: 1,
					login2qq: 1,
					aid: APPID,
					u1:  'http://web2.qq.com/loginproxy.html?login2qq=1&webqq_type=10',
					h: 1,
					ptredirect: 0,
					ptlang: 2052,
					daid: 164,
					from_ui: 1,
					pttype: 1,
					dumy: nil,
					fp: 'loginerroralert',
					action: '3-19-312901',
					mibao_css: 'm_webqq',
					t: 1,
					g: 1,
					js_ver: JS_VER,
					js_type: JS_TYPE,
					login_sig: LOGIN_SIG
				)
			)
			state, _, address, _, info, nickname = net_helper.get(uri).scan(/'.*?'/).map{|str| str[1..-2]}
			state = state.to_i
			nickname = nickname.force_encoding('utf-8')
			raise LoginFailed.new(state, info.force_encoding('utf-8')) unless state.zero?
			log(logger, "账号验证成功，昵称：#{nickname}", Logger::DEBUG) if $-d

			# 连接给定地址获得cookie
			log(logger, '获取cookie……', Logger::DEBUG) if $-d
			net_helper.get(URI(address))
			ptwebqq = net_helper.cookies[COOKIE_KEY_PTWEBQQ]

			net_helper.add_header(HEADER_KEY_REFERER, HEADER_REFERER)

			# 获取会话数据
			log(logger, '正在登陆……', Logger::DEBUG) if $-d
			json_data = JSON.parse(
				net_helper.post(
					URI('https://d.web2.qq.com/channel/login2'),
					URI.encode_www_form(
						r: JSON.generate(
							status: 'online',
							ptwebqq: ptwebqq,
							passwd_sig: '',
							clientid: client_id,
							psessionid: nil
						),
						clientid: client_id
					)
				)
			)
			raise ErrorCode.new(json_data[JSON_KEY_RETCODE], json_data) unless json_data[JSON_KEY_RETCODE] == 0
			session_data  = json_data[JSON_KEY_RESULT]
			p_session_id = session_data[JSON_KEY_PSESSIONID]
			uin = session_data[JSON_KEY_UIN]
			verify_webqq = session_data[JSON_KEY_VFWEBQQ]
			log(logger, '登陆成功', Logger::DEBUG) if $-d
		rescue LoginFailed => ex
			case ex.state
			when 3
				log(logger, "账号验证失败，账号密码不正确。(#{ex.info})", Logger::ERROR)
				raise
			when 4
				log(logger, "账号验证失败，验证码不正确。(#{ex.info})")
				retry
			when 7
				log(logger, "账号验证失败，参数不正确。(#{ex.info})", Logger::ERROR)
				raise
			else
				log(logger, "账号验证失败，未知错误。(#{ex.info})", Logger::FATAL)
				raise
			end
		end

		Client.new(qq, nickname, client_id, random_key, ptwebqq, p_session_id, uin, verify_webqq, net_helper, logger)
	end

	def self.log(logger, message, level = Logger::INFO)
		logger.log(level, message, self.name)
	end
end