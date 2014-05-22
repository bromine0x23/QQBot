# -*- coding: utf-8 -*-

require 'logger'
require 'json'

require_relative 'config'
require_relative 'net'
require_relative 'hash'

module WebQQProtocol
	class Login

		LOG_FILE = 'login.log'

		def self.logger
			@logger ||= Logger.new(LOG_FILE, File::WRONLY | File::APPEND | File::CREAT)
		end

		def self.logger=(logger)
			@logger = logger
		end

		def self.on_captcha_need
			@on_captcha_need ||= proc do |image_data|
				File.open('captcha.jpg', 'wb') do |file|
					file << image_data
				end
				puts '验证码已保存到 captcha.jpg, 请输入验证码：'
				gets.strip.upcase
			end
		end

		def self.on_captcha_need=(on_captcha_need)
			@on_captcha_need = on_captcha_need
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
				"WebQQ login failed: {state: #{@state}, info: #{@info}}"
			end
		end

		#noinspection SpellCheckingInspection
		# 登录主过程
		def self.run(qq, password)
			client_id  = Random.rand(10000000...100000000) # 客户端id

			net = Net.new

			net.header['User-Agent'] = Config::USER_AGENT

			need_verify, verify_code, key = check_account(net, qq)

			verify_code = get_verify_code(net, qq) if need_verify != '0'

			password_encrypted = Hash.hash_password(password, verify_code, key)

			state, _, address, _, info, nickname = login1(net, qq, verify_code, password_encrypted)

			raise LoginFailed.new(state, info.force_encoding('utf-8')) unless state != '0'

			callback(net, address)

			ptwebqq = net.cookies['ptwebqq']

			data = login2(net, client_id, ptwebqq)

			raise ErrorCode.new(data['retcode'], data) unless data['retcode'] == 0

			result  = data['result']

			{
				client_id: client_id,
				net: net,
				qq: qq,
				nickname: nickname.force_encoding('utf-8'),
				ptwebqq: ptwebqq,
				psessionid: result['psessionid'],
				uin: result['uin'],
				vfwebqq: result['vfwebqq'],
			}
		end

		# 校验账号
		def self.check_account(net, qq)
			data = net.get(
				'ssl.ptlogin2.qq.com',
				'/check',
				URI.encode_www_form(
					uin: qq,
					appid: Config::APPID,
					js_ver: Config::JS_VER,
					js_type: Config::JS_TYPE,
					login_sig: Config::LOGIN_SIG,
					u1: 'http://web2.qq.com/loginproxy.html',
					r: Random.rand
				)
			)
			data.scan(/'.*?'/).map{|str| str[1..-2]}
		end

		# 获取验证码
		def self.get_verify_code(net, qq)
			data = net.get(
				'ssl.captcha.qq.com',
				'/getimage',
				URI.encode_www_form(
					aid: APPID,
					uin: qq,
					r: random_key
				)
			)
			on_captcha_need.call(data)
		end

		# 登录第一步
		def login1(net, qq, verify_code, password_encrypted)
			data = net.get(
				'ssl.ptlogin2.qq.com',
				'/login',
				URI.encode_www_form(
					u: qq,
					p: password_encrypted,
					verifycode: verify_code,
					webqq_type: 10,
					remember_uin: 1,
					login2qq: 1,
					aid: Config::APPID,
					u1:  'http://web2.qq.com/loginproxy.html?login2qq=1&webqq_type=10',
					h: 1,
					ptredirect: 0,
					ptlang: 2052,
					daid: Config::DAID,
					from_ui: 1,
					pttype: 1,
					dumy: nil,
					fp: 'loginerroralert',
					action: '0-20-24025',
					mibao_css: 'm_webqq',
					t: 1,
					g: 1,
					js_ver: Config::JS_VER,
					js_type: Config::JS_TYPE,
					login_sig: Config::LOGIN_SIG
				)
			)
			data.scan(/'.*?'/).map{|str| str[1..-2]}
		end

		# 访问给定地址，获取cookie
		def callback(net, address)
			net.get2(URI(address))
		end

		# 获取会话数据
		def login2(net, client_id, ptwebqq)
			data = net.post(
				'd.web2.qq.com',
				'login2',
				URI.encode_www_form(
					r: JSON.generate(
						status: 'online',
						ptwebqq: ptwebqq,
						clientid: client_id,
						psessionid: nil
					),
					clientid: client_id
				)
			)
			JSON.parse(data)
		end
	end
end