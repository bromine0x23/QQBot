#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require 'thread'
require 'json'
require 'logger'
require 'uri'
require 'net/http'
require 'net/https'
require_relative 'util'

# WebQQ客户端
class WebQQClient
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

	HEADER_USER_AGENT = 'Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/33.0.1750.146 Safari/537.36'
	HEADER_REFERER    = 'https://d.web2.qq.com/cfproxy.html?v=20110331002&callback=1'

	# 异常类：WebQQ通信错误码
	class ErrorCode < Exception
		attr_reader :error_code, :raw_data

		def initialize(error_code, raw_data = nil)
			super()
			@error_code, @raw_data = error_code, raw_data
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
			@state, @info = state, info
		end

		def message
			"WebQQ login failed: state => #{@state}, info => #{@info}"
		end
	end

	# 密码加密算法模块
	module PasswordEncrypt
		def self.encrypt(password, verify_code, key)
			md5(md5(hex2ascii(md5(password) + key.gsub!(/\\x/, ''))) + verify_code)
		end

		private

		# 将十六进制数字串每两个编码为ASCII码对应的字符
		def self.hex2ascii(hex_str)
			hex_str.scan(/\w{2}/).map { |byte_str| byte_str.to_i(16).chr }.join
		end

		# MD5哈希
		def self.md5(src)
			Digest::MD5.hexdigest(src).upcase
		end
	end

	# 封装消息接收线程
	class MessageReceiver
		TIMEOUT = 120

		attr_reader :thread

		# 创建接收线程
		def initialize(client_id, p_session_id ,cookies, logger)
			@logger = logger
			@messages= Queue.new
			@thread = Thread.new do
				begin
					log('线程启动……')
					http = Net::HTTP.start(HOST_D_WEB2_QQ, read_timeout: TIMEOUT)
					request = Net::HTTP::Post.new(
						'/channel/poll2',
						HEADER_KEY_USER_AGENT => HEADER_USER_AGENT,
						HEADER_KEY_REFERER => HEADER_REFERER,
						HEADER_KEY_COOKIE => cookies
					)
					request.set_form_data(
						r: JSON.generate(clientid: client_id, psessionid: p_session_id, key: 0, ids: []),
						clientid: client_id,
						psessionid: p_session_id
					)
					loop do
						begin
							json_data = JSON.parse(http.request(request).body)
							raise ErrorCode.new(json_data[JSON_KEY_RETCODE], json_data) unless json_data[JSON_KEY_RETCODE] == 0
							@messages.push json_data[JSON_KEY_RESULT]
						rescue WebQQClient::ErrorCode => ex
							case ex.error_code
							when 102, 116
								next
							when 103, 108, 114, 120, 121
								log("poll时遭遇错误代码：#{ex.error_code}", Logger::ERROR)
								raise
							else
								log("poll时遭遇未知代码：#{ex.error_code}", Logger::FATAL)
								raise
							end
						end
					end
				rescue Exception => ex
					log(<<LOG.strip, Logger::ERROR)
捕获到异常：#{ex.message}
调用栈：\n#{ex.backtrace.join("\n")}
线程重启……
LOG
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

		attr_reader :thread

		# 创建发送线程
		def initialize(cookies, logger, client_id1, p_session_id1)
			@logger = logger
			@messages= Queue.new
			@thread = Thread.new(client_id1, p_session_id1) do |client_id, p_session_id|
				begin
					log('线程启动……')
					https = Net::HTTP.start(HOST_D_WEB2_QQ, 443, use_ssl: true, verify_mode: OpenSSL::SSL::VERIFY_NONE)
					init_header = {
						HEADER_KEY_USER_AGENT => HEADER_USER_AGENT,
						HEADER_KEY_REFERER => HEADER_REFERER,
						HEADER_KEY_COOKIE => cookies
					}
					qun_request   = Net::HTTP::Post.new('/channel/send_qun_msg2', init_header)
					qun_raw_data = {
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
					buddy_request = Net::HTTP::Post.new('/channel/send_buddy_msg2', init_header)
					buddy_raw_data = {
						to: nil,
						face: 0,
						content: nil,
						msg_id: nil,
						clientid: client_id,
						psessionid: p_session_id
					}
					message_counter = Random.rand(1000...10000) * 10000
					loop do
						data = @messages.pop
						begin
							case data[:type]
							when :group_message
								message_counter += 1
								qun_raw_data[:group_uin] = data[:uin]
								qun_raw_data[:content]   = encode_content(data[:message], data[:font])
								qun_raw_data[:msg_id]    = message_counter
								data[:r] = JSON.fast_generate(qun_raw_data)
								qun_request.set_form_data(data)
								post(https, qun_request)
							when :message
								message_counter += 1
								buddy_raw_data[:to]      = data[:uin]
								buddy_raw_data[:content] = encode_content(data[:message], data[:font])
								buddy_raw_data[:msg_id]  = message_counter
								data[:r] = JSON.fast_generate(buddy_raw_data)
								buddy_request.set_form_data(data)
								post(https, buddy_request)
							else
								next
							end
						rescue EOFError
							log('网络异常，无法发送消息，重试……')
							retry
						end
					end
				rescue Exception => ex
					log(<<LOG.strip, Logger::ERROR)
捕获到异常：#{ex.message}
调用栈：\n#{ex.backtrace.join("\n")}
线程重启……
LOG
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

		def post(https, request)
			log(<<LOG.strip, Logger::DEBUG) if $-d
HTTP POST：#{request.path}
　BODY：#{request.body}
LOG
			json_data = JSON.parse(https.request(request).body)
			log("RESPONSE：#{json_data}", Logger::DEBUG) if $-d
			raise ErrorCode.new(json_data[JSON_KEY_RETCODE], json_data) unless json_data[JSON_KEY_RETCODE] == 0
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

		attr_reader :uin, :name, :number

		def initialize(uin, name, number)
			@uin    = uin
			@name   = name
			@number = number
		end

		def to_s
			"#{self.class::TYPE}#{@name}(#{@number})"
		end
	end

	# QQ好友类
	class QQFriend < QQEntity
		TYPE = 'QQ好友'

		# attr_reader :info

		# @param [WebQQClient] client
		def initialize(client, uin, markname)
			num = client.fetch_qq_number(uin)
			# @info = client.fetch_friend_info(uin)
			super(uin, markname, num)
		end
	end

	class QQGroupMember < QQEntity
		TYPE = 'QQ群成员'

		# @param [WebQQClient] client
		def initialize(client, uin, card = nil)
			super(uin, card, client.fetch_qq_number(uin))
		end
	end

	# QQ群类
	class QQGroup < QQEntity
		TYPE = 'QQ群'

		attr_reader :code, :info, :members

		# @param [WebQQClient] client
		def initialize(client, uin, code, name)
			@client = client
			@code = code
			super(uin, name, @client.fetch_group_number(@code))
			@info = client.fetch_group_info(code)
			@members = {}
			@member_names = {}
			@info[JSON_KEY_MINFO].each do |member|
				@member_names[member[JSON_KEY_UIN]] = member[JSON_KEY_NICK]
			end
			@info[JSON_KEY_CARDS].each do |card|
				@member_names[card[JSON_KEY_MUIN]] = card[JSON_KEY_CARD]
			end
		end

		def member(uin)
			return @members[uin] if @members[uin]
			@members[uin] = QQGroupMember.new(@client, uin, @member_names[uin])
		end
	end

	attr_reader :qq, :nickname

	# 初始化客户端
	def initialize(qq, password, logger, on_captcha_need = self.method(:default_on_captcha_need))
		@qq, @password = qq, password
		@logger, @on_captcha_need = logger, on_captcha_need

		@net_helper = Util::NetHelper.new(@logger)
		@net_helper.add_header(HEADER_KEY_USER_AGENT, HEADER_USER_AGENT)

		@logined = false
	end

	# 登录
	def login
		return if @logined
		log('开始登陆……')

		@random_key = Random.rand
		@client_id  = Random.rand(10000000...100000000) # 客户端id

		begin
			# 第一次握手
			log('拉取验证信息……')
			uri = URI::HTTPS.build(
				host: HOST_SSL_PTLOGIN2_QQ,
				path: '/check',
				query: URI.encode_www_form(
					uin: @qq,
					appid: APPID,
					js_ver: JS_VER,
					js_type: JS_TYPE,
					login_sig: LOGIN_SIG,
					u1: 'http://web2.qq.com/loginproxy.html',
					r: @random_key
				)
			)
			need_verify, verify_code, key = @net_helper.get(uri).scan(/'.*?'/).map{|str| str[1..-2]}
			log("是否需要验证码： #{need_verify}", Logger::DEBUG) if $-d
			log("密钥： #{key}", Logger::DEBUG) if $-d

			if need_verify != '0'
				# 需要验证码
				log('获取验证码……')
				uri = URI::HTTPS.build(
					host: 'ssl.captcha.qq.com',
					path: '/getimage',
					query: URI.encode_www_form(
						uin: @qq,
						aid: APPID,
						r: @random_key
					)
				)
				verify_code = @on_captcha_need.call(@net_helper.get(uri))
				log("验证码： #{verify_code}")
			end

			#加密密码
			log('加密密码……')
			password_encrypted = PasswordEncrypt.encrypt(@password, verify_code, key)
			log("密码加密为：#{password_encrypted}", Logger::DEBUG) if $-d

			# 验证账号
			log('验证账号……')
			uri = URI::HTTPS.build(
				host: HOST_SSL_PTLOGIN2_QQ,
				path: '/login',
				query: URI.encode_www_form(
					u: qq,
					p: password_encrypted,
					verifycode: verify_code.downcase,
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
			state, _, address, info, _, nickname = @net_helper.get(uri).scan(/'.*?'/).map{|str| str[1..-2]}
			state = state.to_i
			@nickname = nickname.force_encoding('utf-8')
			raise LoginFailed.new(state, info) unless state.zero?
			log("账号验证成功，昵称：#{@nickname}")

			# 连接给定地址获得cookie
			log('获取cookie……')
			@net_helper.get(URI(address))
			@ptwebqq = @net_helper.cookies[COOKIE_KEY_PTWEBQQ]

			@net_helper.add_header(HEADER_KEY_REFERER, HEADER_REFERER)

			# 获取会话数据
			log('正在登陆……')
			json_data = JSON.parse(
				@net_helper.post(
					URI('https://d.web2.qq.com/channel/login2'),
					URI.encode_www_form(
						r: JSON.fast_generate(
							status: 'online',
							ptwebqq: @ptwebqq,
							passwd_sig: '',
							clientid: @client_id,
							psessionid: nil
						),
						clientid: @client_id
					)
				)
			)
			raise ErrorCode.new(json_data[JSON_KEY_RETCODE], json_data) unless json_data[JSON_KEY_RETCODE] == 0
			session_data  = json_data[JSON_KEY_RESULT]
			@p_session_id = session_data[JSON_KEY_PSESSIONID]
			@uin          = session_data[JSON_KEY_UIN]
			@verify_webqq = session_data[JSON_KEY_VFWEBQQ]
			log('登陆成功')
		rescue LoginFailed => ex
			case ex.state
			when 3
				log("账号验证失败，账号密码不正确。(#{ex.info})")
				return
			when 4
				log("账号验证失败，验证码不正确。(#{ex.info})")
				retry
			when 7
				log("账号验证失败，参数不正确。(#{ex.info})")
				return
			else
				log("账号验证失败，未知错误。(#{ex.info})")
				return
			end
		end

		@logined = true
		self
	end

	# 登出
	PATH_LOGOUT = '/channel/logout2'
	def logout
		return unless @logined
		log('开始登出……')
		uri = URI::HTTPS.build(
			host: HOST_D_WEB2_QQ,
			path: PATH_LOGOUT,
			query: URI.encode_www_form(
				ids: nil,
				clientid: @client_id,
				psessionid: @p_session_id,
				t: Time.now.to_i
			)
		)
		ret = 0
		begin
			util_get_json_data_result(uri)
			log('登出成功！')
		rescue ErrorCode => ex
			log("登出失败！(返回码=#{ex.error_code},返回信息=#{ex.raw_data['result']})")
			ret = ex.error_code
		end

		@logined = false

		ret
	end

	def log(message, level = Logger::INFO)
		@logger.log(level, message, self.class.name)
	end

	def debug(message)
		log(message, Logger::DEBUG) if $DEBUG
	end

	# HTTP POST 请求
	def util_post_request(raw_data, uri)
		data = URI.encode_www_form(
			r: raw_data,
			clientid: @client_id,
			psessionid: @p_session_id
		)
		json_data = JSON.parse(@net_helper.post(uri, data))
		log("response data: #{json_data}", Logger::DEBUG) if $-d
		raise ErrorCode.new(json_data[JSON_KEY_RETCODE], json_data) unless json_data[JSON_KEY_RETCODE] == 0
		json_data[JSON_KEY_RESULT]
	end

	# HTTP GET 请求，返回解析后的 json 数据
	def util_get_json_data_result(uri)
		json_data = JSON.parse(@net_helper.get(uri))
		log("response data: #{json_data}", Logger::DEBUG) if $-d
		raise ErrorCode.new(json_data[JSON_KEY_RETCODE], json_data) unless json_data[JSON_KEY_RETCODE] == 0
		json_data[JSON_KEY_RESULT]
	end

	# 获取群信息
=begin
{
	"gmarklist":[],
	"gmasklist":[],
    "gnamelist":[
		{
			"flag":0,
			"name":"",
			"gid":0,
			"code":0
		},
		......
	]
}
=end
	# @return [Array[QQGroup]]

	URI_GET_GROUP_NAME_LIST = URI::HTTP.build(
		host: HOST_S_WEB2_QQ,
		path: '/api/get_group_name_list_mask2'
	)
	def groups
		raw_data = JSON.fast_generate(vfwebqq: @verify_webqq)
		json_data = util_post_request(raw_data, URI_GET_GROUP_NAME_LIST)
		groups = []
		json_data[JSON_KEY_GNAMELIST].each do |group|
			groups << QQGroup.new(self, group[JSON_KEY_GID], group[JSON_KEY_CODE], group[JSON_KEY_NAME])
		end
		groups
	end

	def friends_hash(b, i)
		a = [0, 0, 0, 0]
		i.bytes.each_with_index { |c, s| a[s % 4] ^= c.ord }
		j = %w(EC OK)
		d = [
			b >> 24 & 255 ^ j[0][0].ord,
			b >> 16 & 255 ^ j[0][1].ord,
			b >>  8 & 255 ^ j[1][0].ord,
			b >>  0 & 255 ^ j[1][1].ord
		]
		j = Array.new(8) {|s| s % 2 == 0 ? a[s >> 1] : d[s >> 1]}
		a = '0123456789ABCDEF'
		d = ''
		j.each do |c|
			d += a[c >> 4 & 15] + a[c & 15]
		end
		d
	end

	# 获取好友信息
=begin
{
	# 分组信息
	"categories":[{index:0, sort:0, name:""}, ...... ]
	"friends":[{"flag":0,"uin":0,"categories":0}, ...... ],
	# 备注
	"marknames":[{"uin":0,"markname":"","type":0}, ...... ],
	# VIP信息
	"vipinfo":[{"vip_level":0,"u":0,"is_vip":0}, ...... ],
	"info":[{"face":0,"flag":0,"nick":"","uin":0}, ...... ]
}
=end
	# @return [Array[QQFriend]]
	GET_FRIENDS_HELLO_MESSAGE = 'hello'
	URI_GET_USER_FRIENDS = URI::HTTP.build(
		host: HOST_S_WEB2_QQ,
		path: '/api/get_user_friends2'
	)
	def friends
		raw_data = JSON.generate(
			h: GET_FRIENDS_HELLO_MESSAGE,
			hash: friends_hash(@uin, @ptwebqq),
			vfwebqq: @verify_webqq
		)
		json_data = util_post_request(raw_data, URI_GET_USER_FRIENDS)
		marknames = json_data[JSON_KEY_MARKNAMES]
		info = json_data[JSON_KEY_INFO]
		friends = []
		json_data[JSON_KEY_FRIENDS].each do |friend|
			uin = friend[JSON_KEY_UIN]
			markname = marknames.find{|t| t[JSON_KEY_UIN] == uin }
			name = nil
			if markname
				name = markname[JSON_KEY_MARKNAME]
			else
				nickname = info.find{|t| t[JSON_KEY_UIN] == uin }
				name = nickname[JSON_KEY_NICK]
			end
			friends << QQFriend.new(self, uin, name)
		end
		friends
	end

	# 通过 uin 获取 QQ 号
=begin
{
	"uiuin":"",
	"account":0,
	"uin":0
}
=end
	PATH_GET_QQ_NUMBER = '/api/get_friend_uin2'
	def fetch_qq_number(uin)
		uri = URI::HTTP.build(
			host: HOST_S_WEB2_QQ,
			path: PATH_GET_QQ_NUMBER,
			query: URI.encode_www_form(
				tuin: uin,
				verifysession: nil,
				type: 1,
				code: nil,
				vfwebqq: @verify_webqq,
				t: Time.now.to_i
			)
		)
		self.util_get_json_data_result(uri)[JSON_KEY_ACCOUNT]
	end

	# 通过 uin 获取群号
=begin
{
	"uiuin":"",
	"account":0,
	"uin":0
}
=end
	PATH_GET_GROUP_NUMBER = '/api/get_friend_uin2'
	def fetch_group_number(uin)
		uri = URI::HTTP.build(
			host: HOST_S_WEB2_QQ,
			path: PATH_GET_GROUP_NUMBER,
			query: URI.encode_www_form(
				tuin: uin,
				verifysession: nil,
				type: 4,
				code: nil,
				vfwebqq: @verify_webqq,
				t: Time.now.to_i)
		)
		self.util_get_json_data_result(uri)[JSON_KEY_ACCOUNT]
	end

	# 通过 uin 获取好友信息
=begin
{
"face":0,
"birthday":{"month":0,"year":0,"day":0},
"occupation":"",
"phone":"",
"allow":0,
"college":"",
"uin":0,
"constel":0,
"blood":0,
"homepage":"",
"stat":0,
"vip_info":0,
"country":"",
"city":"",
"personal":"",
"nick":"残月",
"shengxiao":0,
"email":"",
"client_type":0,
"province":"",
"gender":"male",
"mobile":""
}
=end
	PATH_GET_FRIEND_INFO = '/api/get_friend_info2'
	def fetch_friend_info(uin)
		uri = URI::HTTP.build(
			host: HOST_S_WEB2_QQ,
			path: PATH_GET_FRIEND_INFO,
			query: URI.encode_www_form(
				tuin: uin,
				verifysession: nil,
				code: nil,
				vfwebqq: @verify_webqq,
				t: Time.now.to_i
			)
		)
		self.util_get_json_data_result(uri)
	end

	# 通过 uin 获取群信息
=begin
{
	# 在线成员列表
	"stats":[{"client_type":, "uin":, "stat":}, ...... ]
	# 成员信息
	"minfo":[{"nick":, "province":, "gender": "male", "uin":, "country":, "city":}, ...... ],
	# 群信息
"	ginfo":{
		"face":,
		"memo":,
		"class":,
		"fingermemo":,
		"code":,
		"createtime":,
		"flag":,
		"level":,
		"name":,
		"gid":,
		"owner":,
		"members":[{"muin":, "mflag": }, ...... ],
		"option":
	},
	# 群名片
	"cards":[{"muin":, "card":"安安子"}, ...... ]
}
=end
	PATH_GET_GROUP_INFO = '/api/get_group_info_ext2'
	def fetch_group_info(group_code)
		uri = URI::HTTP.build(
			host: HOST_S_WEB2_QQ,
			path: PATH_GET_GROUP_INFO,
			query: URI.encode_www_form(
				gcode: group_code,
				vfwebqq: @verify_webqq,
				t: Time.now.to_i
			)
		)
		self.util_get_json_data_result(uri)
	end

	URI_ADD_FRIEND = URI::HTTP.build(
		host: HOST_S_WEB2_QQ,
		path: '/api/allow_and_add2'
	)
	def add_friend(account, mname = '')
		raw_data = JSON.generate(
			account: account,
			gid: 0,
			mname: mname,
			vfwebqq: @verify_webqq
		)
		QQFriend.new(self, util_post_request(raw_data, URI_ADD_FRIEND)[JSON_KEY_TUIN])
	end

	# 获取消息接收者
	def receiver
		MessageReceiver.new(@client_id, @p_session_id, @net_helper.cookies.to_s, @logger)
	end

	# 获取消息发送者
	def sender
		MessageSender.new(@net_helper.cookies.to_s, @logger, @client_id, @p_session_id)
	end
end