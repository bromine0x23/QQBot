#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require 'thread'
require 'json'
require 'logger'
require 'uri'
require 'net/https'
require_relative 'util'

# WebQQ客户端
class WebQQClient
	USER_AGENT = 'Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/33.0.1750.146 Safari/537.36'
	APPID = 1003903
	JS_VER = 10071
	JS_TYPE = 0

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

	# 封装登录步骤
	module Loginer
		# @param [Util::NetHelper] net_helper
		# @param [Logger] logger
		def self.login(qq, password, net_helper, logger, on_captcha_need)
			client_id  = Random.rand(10000000...100000000) # 客户端id
			random_key = Random.rand
			uri = nil
			begin
				# 第一次握手
				log(logger, '拉取验证信息……')
				uri = Util::NetHelper.uri_https(
					'ssl.ptlogin2.qq.com',
					'/check',
					uin: qq,
					appid: APPID,
					js_ver: JS_VER,
					js_type: JS_TYPE,
					login_sig: 'EDCv9dZdzXo5FchLpEEgEk-coa77jI5yM8L7rEhPWJCYGQlEMBdf5fRmccPqtHKt',
					u1: 'http://web2.qq.com/loginproxy.html',
					r: random_key
				)
				need_verify, verify_code, key =net_helper.get(uri).scan(/'.*?'/).map{|str| str[1..-2]}
				log(logger, "是否需要验证码： #{need_verify}", Logger::DEBUG) if $-d
				log(logger, "密钥： #{key}", Logger::DEBUG) if $-d

				if need_verify != '0'
					# 需要验证码
					log(logger, '获取验证码……')
					uri = Util::NetHelper.uri_https(
						'ssl.captcha.qq.com',
						'/getimage',
						uin: qq,
						aid: APPID,
						r: random_key
					)
					verify_code = on_captcha_need.call(net_helper.get(uri))
					log(logger, "验证码： #{verify_code}")
				end

				#加密密码
				log(logger, '加密密码……')
				password_encrypted = PasswordEncrypt.encrypt(password, verify_code, key)
				log(logger, "密码加密为：#{password_encrypted}", Logger::DEBUG) if $-d

				# 验证账号
				log(logger, '验证账号……')
				uri = Util::NetHelper.uri_https(
					'ssl.ptlogin2.qq.com',
					'/login',
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
					login_sig: 'EDCv9dZdzXo5FchLpEEgEk-coa77jI5yM8L7rEhPWJCYGQlEMBdf5fRmccPqtHKt'
				)
				state, _, address, info, _, nickname = net_helper.get(uri).scan(/'.*?'/).map{|str| str[1..-2]}
				state = state.to_i
				raise LoginFailed.new(state, info.force_encoding('utf-8')) unless state.zero?
				@nickname = nickname.force_encoding('utf-8')
				log(logger, "账号验证成功，昵称：#{@nickname}")
			rescue LoginFailed => ex
				case ex.state
				when 3
					log(logger, "账号验证失败，账号密码不正确。(#{ex.info})")
					return
				when 4
					log(logger, "账号验证失败，验证码不正确。(#{ex.info})")
					retry
				when 7
					log(logger, "账号验证失败，参数不正确。(#{ex.info})")
					return
				else
					log(logger, "账号验证失败，未知错误。(#{ex.info})")
					return
				end
			end

			# 连接给定地址获得cookie
			log(logger, '获取cookie……')
			net_helper.get(URI(address))
			ptwebqq = net_helper.cookies['ptwebqq']


			net_helper.add_header('Content-Type', 'application/x-www-form-urlencoded')
			net_helper.add_header('Referer', 'http://d.web2.qq.com/proxy.html?v=20110331002&callback=1&id=2')

			# 正式登录
			log(logger, '正在登陆...')
			session_data = get_session_data(net_helper, client_id, ptwebqq)
			p_session_id, uin, verify_webqq = session_data['psessionid'], session_data['uin'], session_data['vfwebqq']
			log(logger, '登陆成功')

			{
				client_id: client_id,
				random_key: random_key,
				nickname: nickname,
				uin: uin,
				ptwebqq: ptwebqq,
				p_session_id: p_session_id,
				verify_webqq: verify_webqq
			}
		end

		private

		def self.log(logger, message, level = Logger::INFO)
			logger.log(level, message, self.name)
		end

		def self.get_session_data(net_helper, client_id, ptwebqq)
			json_data = JSON.parse(
				net_helper.post(
					Util::NetHelper.uri_https('d.web2.qq.com', '/channel/login2'),
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
			raise ErrorCode.new(json_data['retcode'], json_data) unless json_data['retcode'] == 0
			json_data['result']
		end
	end

	# 封装消息接收线程
	class MessageReceiver
		TIMEOUT = 120
		KEY_RETCODE = 'retcode'
		KEY_RESULT = 'result'

		# 创建接收线程
		def initialize(cookies, logger, client_id, p_session_id)
			@logger = logger
			@messages= Queue.new
			@thread = Thread.new do
				begin
					log('线程启动……')
					http = Net::HTTP.start('d.web2.qq.com', read_timeout: TIMEOUT)
					request = Net::HTTP::Post.new(
						'/channel/poll2',
						'User-Agent' => USER_AGENT,
						'Referer' => 'http://d.web2.qq.com/proxy.html?v=20110331002&callback=1&id=2',
						'Cookie' => cookies
					)
					request.set_form_data(
						r: JSON.generate(clientid: client_id, psessionid: p_session_id, key: 0, ids: []),
						clientid: client_id,
						psessionid: p_session_id
					)
					loop do
						begin
							json_data = JSON.parse(http.request(request).body)
							raise ErrorCode.new(json_data[KEY_RETCODE], json_data) unless json_data[KEY_RETCODE] == 0
							@messages.push json_data[KEY_RESULT]
						rescue WebQQClient::ErrorCode => ex
							case ex.error_code
							when 102, 116
								next
							when 103, 108, 114, 120, 121
								log("poll时遭遇错误代码：#{ex.error_code}", Logger::ERROR)
								raise
							else
								log("poll时遭遇未知代码：#{ex.error_code}", Logger::FATAL)
							end
						end
					end
				rescue Exception => ex
					log("捕获到异常：#{ex.message}", Logger::ERROR)
					log("调用栈：\n#{ex.backtrace.join("\n")}", Logger::ERROR)
					log('线程重启……')
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
		KEY_RETCODE = 'retcode'
		STRING_FONT = 'font'
		DEFAULT_FONT_FACE = '宋体'
		DEFAULT_COLOR = '000000'

		# 创建发送线程
		def initialize(cookies, logger, client_id1, p_session_id1)
			@logger = logger
			@messages= Queue.new
			@thread = Thread.new(client_id1, p_session_id1) do |client_id, p_session_id|
				begin
					log('线程启动……')
					https = Net::HTTP.start('d.web2.qq.com', 443, use_ssl: true, verify_mode: OpenSSL::SSL::VERIFY_NONE)
					buddy_request = Net::HTTP::Post.new(
						'/channel/send_buddy_msg2',
						'User-Agent' => USER_AGENT,
						'Referer' => 'https://d.web2.qq.com/cfproxy.html?v=20110331002&callback=1',
						'Cookie' => cookies
					)
					qun_request = Net::HTTP::Post.new(
						'/channel/send_qun_msg2',
						'User-Agent' => USER_AGENT,
						'Referer' => 'https://d.web2.qq.com/cfproxy.html?v=20110331002&callback=1',
						'Cookie' => cookies
					)
					message_counter = Random.rand(1000...10000) * 10000
					loop do
						data = @messages.pop
						begin
							case data[:type]
							when :group_message
								message_counter += 1
								qun_request.set_form_data(
									r: JSON.generate(
										group_uin: data[:uin],
										content: encode_content(data[:message], data[:font]),
										msg_id: message_counter,
										clientid: client_id,
										psessionid: p_session_id
									),
									clientid: client_id,
									psessionid: p_session_id
								)
								log("HTTP POST #{qun_request.path}", Logger::DEBUG) if $-d
								log("BODY：#{qun_request.body}", Logger::DEBUG) if $-d
								json_data = JSON.parse(https.request(qun_request).body)
								log("RESPONSE：#{json_data}", Logger::DEBUG) if $-d
								raise ErrorCode.new(json_data[KEY_RETCODE], json_data) unless json_data[KEY_RETCODE] == 0
							when :message
								message_counter += 1
								buddy_request.set_form_data(
									r: JSON.generate(
										to: data[:uin],
										face: 0,
										content: encode_content(data[:message], data[:font]),
										msg_id: message_counter,
										clientid: client_id,
										psessionid: p_session_id
									),
									clientid: client_id,
									psessionid: p_session_id
								)
								log("HTTP POST：#{buddy_request.path}", Logger::DEBUG) if $-d
								log("BODY：#{buddy_request.body}", Logger::DEBUG) if $-d
								json_data = JSON.parse(https.request(buddy_request).body)
								log("RESPONSE：#{json_data}", Logger::DEBUG) if $-d
								raise ErrorCode.new(json_data[KEY_RETCODE], json_data) unless json_data[KEY_RETCODE] == 0
							else
								next
							end
						rescue EOFError
							log('网络异常，无法发送消息，重试……')
							retry
						end
					end
				rescue Exception => ex
					log("捕获到异常：#{ex.message}", Logger::ERROR)
					log("调用栈：\n#{ex.backtrace.join("\n")}", Logger::ERROR)
					log('线程重启……')
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
			JSON.generate(
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

	# QQ好友类
	class QQFriend
		attr_reader :uin, :nickname, :markname, :qq_number, :info

		# @param [WebQQClient] client
		def initialize(client, uin, nickname, markname = nil)
			@uin = uin
			@nickname, @markname = nickname, markname
			@qq_number = client.fetch_qq_number(uin)
			@info = client.fetch_friend_info(uin)
		end

		# 返回名片或昵称
		def name
			@markname ? @markname : @nickname
		end

		# 使用幽灵方法访问各属性
		# Example: birthday_month ==> @info['birthday']['month']
		def method_missing(symbol)
			res = @info
			symbol.to_s.split('_').each do |key|
				res = res[key]
				break unless res
			end
			res
		end
	end

	# QQ群类
	class QQGroup
		attr_reader :uin, :group_code, :group_name, :group_number, :group_info

		KEY_MINFO = 'minfo'
		KEY_MUIN  = 'muin'
		KEY_UIN   = 'uin'
		KEY_NICK  = 'nick'
		KEY_CARDS = 'cards'
		KEY_CARD  = 'card'

		# @param [WebQQClient] client
		def initialize(client, uin, group_code, group_name)
			@uin = uin
			@group_code, @group_name = group_code, group_name
			@group_number = client.fetch_group_number(group_code)
			@group_info = client.fetch_group_info(group_code)
			@group_nicknames = {}
			@group_info[KEY_MINFO].each do |member|
				@group_nicknames[member[KEY_UIN]] = member[KEY_NICK]
			end
			@group_info[KEY_CARDS].each do |card|
				@group_nicknames[card[KEY_MUIN]] = card[KEY_CARD]
			end
		end

		alias name group_name

		# 返回群名片
		def group_nickname(uin)
			@group_nicknames[uin]
		end
	end

	attr_reader :qq, :nickname

	# 初始化客户端
	def initialize(qq, password, logger, on_captcha_need = self.method(:default_on_captcha_need))
		@qq, @password = qq, password
		@logger, @on_captcha_need = logger, on_captcha_need

		@net_helper = Util::NetHelper.new(@logger)
		@net_helper.add_header('User-Agent', USER_AGENT)

		@logined = false
	end

	# 登录
	def login
		return if @logined
		log('开始登陆……')
		info = Loginer.login(@qq, @password, @net_helper, @logger, @on_captcha_need)
		@client_id = info[:client_id]
		@random_key = info[:random_key]
		@nickname = info[:nickname]
		@uin = info[:uin]
		@ptwebqq = info[:ptwebqq]
		@p_session_id = info[:p_session_id]
		@verify_webqq = info[:verify_webqq]
		@logined = true
		self
	end

	# 登出
	def logout
		return unless @logined
		log('开始登出……')
		uri = @net_helper.uri_https(
			'd.web2.qq.com',
			'/channel/logout2',
			ids: nil,
			clientid: @client_id,
			psessionid: @p_session_id,
			t: Time.now.to_i
		)
		ret = 0
		begin
			util_get_json_data(uri)
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

	KEY_RETCODE = 'retcode'
	KEY_RESULT = 'result'

	# HTTP POST 请求
	def util_post_request(raw_data, uri)
		data = URI.encode_www_form(
			r: raw_data,
			clientid: @client_id,
			psessionid: @p_session_id
		)
		# @net_helper.add_header('Content-Type', 'application/x-www-form-urlencoded')
		json_data = JSON.parse(@net_helper.post(uri, data))
		# @net_helper.delete_header('Content-Type')
		raise ErrorCode.new(json_data[KEY_RETCODE], json_data) unless json_data[KEY_RETCODE] == 0
		log("response data: #{json_data[KEY_RESULT]}", Logger::DEBUG) if $-d
		json_data[KEY_RESULT]
	end

	# HTTP GET 请求，返回解析后的 json 数据
	def util_get_json_data(uri)
		json_data = JSON.parse(@net_helper.get(uri))
		raise ErrorCode.new(json_data[KEY_RETCODE], json_data) unless json_data[KEY_RETCODE] == 0
		json_data
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
	def groups
		raw_data = JSON.generate(vfwebqq: @verify_webqq)
		uri = @net_helper.uri_http(
			's.web2.qq.com',
			'/api/get_group_name_list_mask2'
		)
		json_data = self.util_post_request(raw_data, uri)
		log("json_data = #{json_data}", Logger::DEBUG) if $-d
		json_data['gnamelist'].map do |group|
			QQGroup.new(self, group['gid'], group['code'], group['name'])
		end
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
	def friends
		raw_data = JSON.generate(
			h: 'hello',
			hash: friends_hash(@uin, @ptwebqq),
			vfwebqq: @verify_webqq
		)
		uri = @net_helper.uri_http(
			's.web2.qq.com',
			'/api/get_user_friends2'
		)
		json_data = self.util_post_request(raw_data, uri)

		json_data['friends'].map do |friend|
			uin = friend['uin']
			nickname = json_data['info'].find{|t| t['uin'] == uin }['nick']
			markname = json_data['marknames'].find{|t| t['uin'] == uin }
			markname = markname['markname'] if markname
			QQFriend.new(self, uin, nickname, markname)
		end
	end

	# 通过 uin 获取 QQ 号
=begin
{
	"uiuin":"",
	"account":0,
	"uin":0
}
=end
	def fetch_qq_number(uin)
		uri = @net_helper.uri_http(
			's.web2.qq.com',
			'/api/get_friend_uin2',
			tuin: uin,
			verifysession: nil,
			type: 1,
			code: nil,
			vfwebqq: @verify_webqq,
			t: Time.now.to_i
		)
		self.util_get_json_data(uri)['result']['account']
	end

	# 通过 uin 获取群号
=begin
{
	"uiuin":"",
	"account":0,
	"uin":0
}
=end
	def fetch_group_number(uin)
		uri = @net_helper.uri_http(
			's.web2.qq.com',
			'/api/get_friend_uin2',
			tuin: uin,
			verifysession: nil,
			type: 4,
			code: nil,
			vfwebqq: @verify_webqq,
			t: Time.now.to_i
		)
		self.util_get_json_data(uri)['result']['account']
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
	def fetch_friend_info(uin)
		uri = @net_helper.uri_http(
			's.web2.qq.com',
			'/api/get_friend_info2',
			tuin: uin,
			verifysession: nil,
			code: nil,
			vfwebqq: @verify_webqq,
			t: Time.now.to_i
		)
		self.util_get_json_data(uri)['result']
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
	def fetch_group_info(group_code)
		uri = @net_helper.uri_http(
			's.web2.qq.com',
			'/api/get_group_info_ext2',
			gcode: group_code,
			vfwebqq: @verify_webqq,
			t: Time.now.to_i
		)
		self.util_get_json_data(uri)['result']
	end

	# 获取消息接收者
	def receiver
		MessageReceiver.new(@net_helper.cookies.to_s, @logger, @client_id, @p_session_id)
	end

	# 获取消息发送者
	def sender
		MessageSender.new(@net_helper.cookies.to_s, @logger, @client_id, @p_session_id)
	end
end