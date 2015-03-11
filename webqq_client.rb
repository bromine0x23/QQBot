# -*- coding: utf-8 -*-

require 'base64'
require 'concurrent'
require 'digest'
require 'logger'
require 'thread'
require 'uri'
require 'time'
require 'yajl'

require_relative 'http_client'

# noinspection RubyResolve
class WebQQClient < HttpClient
	# 加密算法
	module Encrypt
		def self.random(min = 0, max = 0x100)
			$-d ? (min + max) / 2 : rand(min...max)
		end

		module RSA
			KEY = 0xF20CE00BAE5361F8FA3AE9CEFA495362FF7DA1BA628F64A347F0A8C012BF0B254A30CD92ABFFE7A6EE0DC424CB6166F8819EFA5BCCB20EDFB4AD02E412CCF579B1CA711D55B8B0B3AEB60153D5E0693A2A86F3167D7847A0CB8B00004716A9095D9BADC977CBB804DBDCBA6029A9710869A453F27DFDDF83C016D928B3CBF4C7
			POW = 3
			UINT8_PER_KEY = 128

			# @param [String] data BIN-format
			# @return [String] HEX-format
			def self.rsa(data, key, pow)
				data = data.unpack('H*')[0].to_i(16)
				result = (data ** pow % key).to_s(16)
				result.length.odd? ? "0#{result}" : result
			end

			# @param [String] source BIN-format
			# @return [String] HEX-format
			def self.encrypt(source)
				data = source.rjust(UINT8_PER_KEY, "\x00")
				index = UINT8_PER_KEY - source.bytesize - 1
				data[index -= 1] = Encrypt.random(1, 0x100).chr while index > 2
				data[1] = "\x02"
				rsa(data, KEY, POW)
			end
		end

		module MD5
			# @param [String] source BIN-format
			# @return [String] BIN-format
			def self.md5(source)
				Digest::MD5.digest(source)
			end
		end

		module TEA
			# @param [Integer] data 64-bit
			# @param [Array] key 4x32bit
			# @return [Integer] 64-bit
			def self.tea_encrypt(data, key)
				data0, data1, = data >> 32, data & 0xFFFFFFFF
				key0, key1, key2, key3, = key
				sum = 0
				16.times do
					sum = (sum + 0x9E3779B9) & 0xFFFFFFFF
					data0 = (data0 + (((data1 << 4) + key0) ^ (data1 + sum) ^ ((data1 >> 5) + key1))) & 0xFFFFFFFF
					data1 = (data1 + (((data0 << 4) + key2) ^ (data0 + sum) ^ ((data0 >> 5) + key3))) & 0xFFFFFFFF
				end
				(data0 << 32) | data1
			end

			# @param [String] data BIN-format
			# @param [Array] key 4x32bit
			# @return [String] BIN-format
			def self.core_encrypt(data, key)
				a, b = 0, 0
				data.unpack('Q>*').map{|d|
					a = a ^ d
					c = tea_encrypt(a, key) ^ b
					b = a
					a = c
				}.pack('Q>*')
			end

			# @param [String] source BIN-format
			# @param [Array] key 4x32bit
			# @return [String] BIN-format
			def self.encrypt(source, key)
				length = (source.bytesize + 10 + 7) & 0xFFFFFFF8
				data = []
				data << ((Encrypt.random & 0xF8) | (length - source.bytesize - 10))
				(length - source.bytesize - 8).times{ data << (Encrypt.random & 0xFF) }
				source.bytesize.times{|i| data << source[i].ord }
				7.times{ data << 0 }
				core_encrypt(data.pack('C*'), key)
			end
		end

		# 加密密码
		def self.password(password, salt, vcode, is_md5)
			password = password || ''
			salt = eval(%["#{salt}"]).force_encoding('BINARY').upcase
			vcode = vcode || ''

			b = is_md5 ? [password].pack('H*') : MD5.md5(password)
			r = RSA.encrypt(b)
			k = MD5.md5(b + salt.upcase).unpack('L>*')
			s = ['%04x%s%s%04x%s' % [r.length / 2, r, salt.unpack('H*')[0], vcode.length, vcode.unpack('H*')[0]]].pack('H*')
			d = TEA.encrypt(s, k)

			Base64.strict_encode64(d).gsub!(/[\/+=]/, '/' => :-, '+' => :*, '=' => :_)
		end

		# 腾讯迷の哈希，用于获取好友和群的uid等
		def self.fetch(uin, ptwebqq)
			r = ''
			u = uin.to_s.bytes
			ul, ui = u.size, 0
			ptwebqq.each_byte do |p|
				r += '%02X' % (u[ui] ^ p)
				ui = (ui + 1) % ul
			end
			'password error'.each_byte do |p|
				r += '%02X' % (u[ui] ^ p)
				ui = (ui + 1) % ul
			end
			r
		end
	end

	class Entity
		def friend?
			false
		end

		def group?
			false
		end

		def discuss?
			false
		end
	end

	module CompositeEntity
		def members
			@members ||= {}
		end

		def by_uin(uin)
			@members[uin]
		end

		def by_name(name)
			@members.find{|_, member| member.name == name}
		end

		def by_number(number)
			@members.find{|_, member| member.number == number}
		end
	end

	class Friend < Entity
		BLOOD = %w(无 A型 B型 O型 AB型 其他)
		CONSTELLATION = %w(无 水瓶座 双鱼座 白羊座 金牛座 双子座 巨蟹座 狮子座 处女座 天秤座 天蝎座 射手座 摩羯座)
		SHENGXIAO = %w(鼠 牛 虎 兔 龙 蛇 马 羊 猴 鸡 狗 猪)

		attr_reader :number
		attr_reader :id, :name
		attr_reader :country, :province, :city
		attr_reader :birthday
		attr_reader :gender, :face
		attr_reader :blood, :constellation, :shengxiao

		def initialize(number, info)
			@number = number
			@id, @name = info['uin'], info['nick']
			@country, @province, @city = info['country'], info['province'], info['city']
			@birthday = Time.local(info['birthday']['year'], info['birthday']['month'], info['birthday']['day']) if info['birthday']
			@gender, @face = info['gender'], info['face']
			@blood, @constellation, @shengxiao = BLOOD[info['blood'] || 0], CONSTELLATION[info['constel'] || 0], SHENGXIAO[info['shengxiao'] || 0]
		end

		def friend?
			true
		end
	end

	class Group < Entity
		include CompositeEntity
		attr_reader :number
		attr_reader :id, :name
		attr_reader :owner, :description, :create_time

		def initialize(number, info, &on_number_require)
			@number = number
			@id, @name = info['ginfo']['gid'], info['ginfo']['name']
			@owner, @description, @create_time = info['ginfo']['owner'], info['ginfo']['memo'], Time.at(info['ginfo']['createtime'] || 0)

			members_info = {}
			(info['minfo'] || []).each do |member_info|
				members_info[member_info['uin']] = member_info
			end
			(info['cards'] || []).each do |card|
				members_info[card['muin']]['nick'] = card['card']
			end

			@members = Hash.new do |members, uin|
				members[uin] = Friend.new(on_number_require[uin], members_info[uin] || {})
			end
		end

		def group?
			true
		end
	end

	class Discuss < Entity
		include CompositeEntity
		attr_reader :id, :name
		attr_reader :owner

		def initialize(info, &on_number_require)
			@id, @name = info['info']['did'], info['info']['discu_name']
			@owner = info['info']['owner']

			members_info = {}
			(info['mem_info'] || []).each do |member_info|
				members_info[member_info['uin']] = member_info
			end

			@members = Hash.new do |members, uin|
				members[uin] = Friend.new(on_number_require[uin], members_info[uin])
			end
		end

		def discuss?
			true
		end
	end

	class ErrorCode < ArgumentError
		attr_reader :retcode, :data

		def initialize(retcode, data)
			super()
			@retcode, @data = retcode, data
		end

		def message
			"[ErrorCode] retcode: #{@retcode}, raw_data: #{@data}"
		end
	end

	class Receiver < Concurrent::SingleThreadExecutor
		include Logger::Severity

		DEFAULT_HANDLER = proc{}

		def initialize(receiver, logger)
			super()
			@handler = DEFAULT_HANDLER
			@logger = logger
			@receiver = receiver
			post do
				loop do
					begin
						data = @receiver.call
						handler.call(data) if data
					rescue Errno::ECONNRESET, Net::ReadTimeout => ex
						log(INFO, self.class, "#{ex.class}")
						retry
					rescue => exception
						log(ERROR, self.class, <<-LOG)
Exception<#{exception.class}>: #{exception.message}
#{exception.backtrace.first(4).join("\n")}
						LOG
						raise
					end
				end
			end
		end

		def handler
			mutex.synchronize do
				@handler
			end
		end

		def handler=(handler)
			mutex.synchronize do
				@handler = handler
			end
		end
	end

	class Sender < Concurrent::SingleThreadExecutor
		include Logger::Severity

		def initialize(on_message, on_session_message, on_group_message, on_discuss_message, logger)
			super()
			@on_message, @on_session_message, @on_group_message, @on_discuss_message = on_message, on_session_message, on_group_message, on_discuss_message
			@logger = logger
			@message_id = (Time.now.to_i / 1000).round(-5)
		end

		# @return [Boolean]
		def push(*args)
			post(*args) do |message|
				transmit(message)
			end
		end

		private

		# @return [Integer]
		def message_id
			@message_id += 1
		end

		# @return [Boolean]
		def transmit(message)
			case message[:type]
			when :message
				@on_message.call(message[:to], message[:content], message_id)
			when :session_message
				@on_session_message.call(message[:to], message[:content], message_id, message[:group_sig], message[:service_type])
			when :group_message
				@on_group_message.call(message[:to], message[:content], message_id)
			when :discuss_message
				@on_discuss_message.call(message[:to], message[:content], message_id)
			else
				fail 'Invalid type'
			end
		rescue EOFError
			retry
		rescue => exception
			log(ERROR, self.class, <<-LOG)
Exception<#{exception.class}>: #{exception.message}
#{exception.backtrace.first(4).join("\n")}
			LOG
		end
	end

	module APIProxy
		include Logger::Severity

		# main_domain = 'http://w.qq.com/'
		# main_url = "http://#{main_domain}/"
		# webqq_main_url = 'http://web2.qq.com/'
		static_cgi_url = 'http://s.web2.qq.com/'
		dynamic_cgi_url = 'http://d.web2.qq.com/'
		# file_server = 'http://file1.web.qq.com/'

		urls = {
			login2: "#{dynamic_cgi_url}channel/login2",
			poll2: "#{dynamic_cgi_url}channel/poll2",
			get_vfwebqq: "#{static_cgi_url}api/getvfwebqq",
			refuse_file: "#{dynamic_cgi_url}channel/refuse_file2",
			notify_offfile: "#{dynamic_cgi_url}channel/notify_offfile2",
			get_user_friends2: "#{static_cgi_url}api/get_user_friends2",
			get_group_name_list_mask2: "#{static_cgi_url}api/get_group_name_list_mask2",
			get_discus_list: "#{static_cgi_url}api/get_discus_list",
			get_recent_list2: "#{dynamic_cgi_url}channel/get_recent_list2",
			get_single_long_nick2: "#{static_cgi_url}api/get_single_long_nick2",
			get_self_info2: "#{static_cgi_url}api/get_self_info2",
			get_group_info_ext2: "#{static_cgi_url}api/get_group_info_ext2",
			get_discu_info: "#{dynamic_cgi_url}channel/get_discu_info",
			get_friend_info2: "#{static_cgi_url}api/get_friend_info2",
			get_friend_uin2: "#{static_cgi_url}api/get_friend_uin2",
			get_online_buddies2: "#{dynamic_cgi_url}channel/get_online_buddies2",
			change_status2: "#{dynamic_cgi_url}channel/change_status2",
			send_buddy_msg2: "#{dynamic_cgi_url}channel/send_buddy_msg2",
			send_sess_msg2: "#{dynamic_cgi_url}channel/send_sess_msg2",
			send_qun_msg2: "#{dynamic_cgi_url}channel/send_qun_msg2",
			send_discu_msg2: "#{dynamic_cgi_url}channel/send_discu_msg2",
			get_c2cmsg_sig2: "#{dynamic_cgi_url}channel/get_c2cmsg_sig2",
		}

		string_origin = 'origin'
		string_referer = 'referer'

		# noinspection RubyStringKeysInHashInspection
		header = {
			's.web2.qq.com' => {
				string_origin => static_cgi_url,
				string_referer => 'http://s.web2.qq.com/proxy.html?v=20130916001&callback=1&id=2'
			},
			'd.web2.qq.com' => {
				string_origin => dynamic_cgi_url,
				string_referer => 'http://d.web2.qq.com/proxy.html?v=20130916001&callback=1&id=2'
			}
		}

		# noinspection RubyStringKeysInHashInspection
		get_header = lambda do |uri|
			header[uri.host]
		end

		define_method :parse_response do |uri, response|
			begin
				data = Yajl.load(response)
				case data['retcode']
				when 0
					data['result']
				else
					fail ErrorCode.new(data['retcode'], data)
				end
			rescue Yajl::ParseError
				log(ERROR, 'WebQQ', <<-ERROR)
Response From #{uri}
JSON Parser Error: #{response}
				ERROR
			end
		end

		define_method :request do |method, uri, args, timeout = nil|
			uri = URI(uri)
			case method
			when :get
				uri.query = URI.encode_www_form(args)
				parse_response(uri, get(uri, get_header.call(uri), timeout))
			when :post
				parse_response(uri, post(uri, { r: Yajl.dump(args) }, get_header.call(uri), timeout))
			else
				log(ERROR, self.class, "Unknown http method: #{method}.")
				fail ArgumentError.new('unknown http method')
			end
		end

		define_method :login do |status = :online|
			request(
				:post, urls[:login2],
				{
					ptwebqq: validate[:ptwebqq],
					clientid: validate[:clientid],
					psessionid: validate[:psessionid],
					status: status
				}
			)
		end

		define_method :relink do |status = :online|
			request(
				:post, urls[:login2], {
					ptwebqq: validate[:ptwebqq],
					clientid: validate[:clientid],
					psessionid: validate[:psessionid],
					key: '',
					status: status
				}
			)
		end

		define_method :poll do
			begin
				request(
					:post, urls[:poll2], {
						ptwebqq: validate[:ptwebqq],
						clientid: validate[:clientid],
						psessionid: validate[:psessionid],
						key: ''
					},
					120
				)
			rescue ErrorCode => ex
				case ex.retcode
				when 102, 109, 110
					# do nothing
				when 116
					validate[:ptwebqq] = cookies['qq.com', '/', 'ptwebqq'].value = ex.data['p']['ptwebqq']
				else
					log(ERROR, self.class, "遭遇错误代码：#{ex.retcode}")
					raise
				end
			end
		end

		define_method :get_vfwebqq do
			request(
				:get, urls[:get_vfwebqq], {
					ptwebqq: validate[:ptwebqq],
					clientid: validate[:clientid],
					psessionid: validate[:psessionid],
					t: Time.now.to_i,
				},
			)
		end

		define_method :get_user_friends do
			request(
				:post, urls[:get_user_friends2], {
					vfwebqq: validate[:vfwebqq],
					hash: Encrypt.fetch(user.id, validate[:ptwebqq])
				},
			)
		end

		define_method :get_group_list do
			request(
				:post, urls[:get_group_name_list_mask2], {
					vfwebqq: validate[:vfwebqq],
					hash: Encrypt.fetch(user.id, validate[:ptwebqq])
				},
			)
		end

		define_method :get_discus_list do
			request(
				:get, urls[:get_discus_list], {
					clientid: validate[:clientid],
					psessionid: validate[:psessionid],
					vfwebqq: validate[:vfwebqq],
					t: Time.now.to_i,
				},
			)
		end

		define_method :get_recent_list do
			request(
				:get, urls[:get_recent_list2], {
					clientid: validate[:clientid],
					psessionid: validate[:psessionid],
					vfwebqq: validate[:vfwebqq],
					t: Time.now.to_i,
				}
			)
		end

		define_method :get_signature do |tuin|
			request(
				:get, urls[:get_single_long_nick2], {
					tuin: tuin,
					vfwebqq: validate[:vfwebqq],
					t: Time.now.to_i,
				}
			)
		end

		define_method :get_group_info_list do |gcode|
			request(
				:get, urls[:get_group_info_ext2], {
					gcode: gcode,
					vfwebqq: validate[:vfwebqq],
					t: Time.now.to_i,
				}
			)
		end

		define_method :get_discu_info_list do |did|
			request(
				:get, urls[:get_discu_info], {
					did: did,
					clientod: validate[:clientid],
					psessionid: validate[:psessionid],
					vfwebqq: validate[:vfwebqq],
					t: Time.now.to_i,
				}
			)
		end

		define_method :get_friend_uin do |uin, type|
			request(
				:get, urls[:get_friend_uin2], {
					tuin: uin,
					type: type,
					vfwebqq: validate[:vfwebqq],
					t: Time.now.to_i,
				}
			)
		end

		define_method :get_friend_info do |uin|
			request(
				:get, urls[:get_friend_info2], {
					tuin: uin,
					clientod: validate[:clientid],
					psessionid: validate[:psessionid],
					vfwebqq: validate[:vfwebqq],
					t: Time.now.to_i,
				}
			)
		end

		define_method :get_buddy_online_state do
			request(
				:get, urls[:get_online_buddies2], {
					clientod: validate[:clientid],
					psessionid: validate[:psessionid],
					vfwebqq: validate[:vfwebqq],
					t: Time.now.to_i,
				}
			)
		end

		define_method :get_self_info do
			request(
				:get, urls[:get_self_info2], {
					t: Time.now.to_i,
				}
			)
		end

		define_method :change_status do |status = :hidden|
			request(
				:get, urls[:get_self_info2], {
					clientod: validate[:clientid],
					psessionid: validate[:psessionid],
					newstatus: status,
					t: Time.now.to_i,
				}
			)
		end

		define_method :send_msg do |to, content, message_id|
			request(
				:post, urls[:send_buddy_msg2], {
					to: to,
					content: content,
					face: user.face,
					clientid: validate[:clientid],
					msg_id: message_id,
					psessionid: validate[:psessionid],
				}
			)
		end

		define_method :send_session_msg do |to, content, message_id, group_sig, service_type|
			request(
				:post, urls[:send_qun_msg2], {
					to: to,
					content: content,
					face: user.face,
					clientid: validate[:clientid],
					msg_id: message_id,
					psessionid: validate[:psessionid],
					group_sig: group_sig,
					service_type: service_type,
				}
			)
		end

		define_method :send_group_msg do |group_uin, content, message_id|
			request(
				:post, urls[:send_qun_msg2], {
					group_uin: group_uin,
					content: content,
					face: user.face,
					clientid: validate[:clientid],
					msg_id: message_id,
					psessionid: validate[:psessionid],
				}
			)
		end

		define_method :send_discuss_msg  do |did, content, message_id|
			request(
				:post, urls[:send_discu_msg2], {
					did: did,
					content: content,
					face: user.face,
					clientid: validate[:clientid],
					msg_id: message_id,
					psessionid: validate[:psessionid],
				}
			)
		end
	end

	Validate = Struct.new(:clientid, :skey, :psessionid, :ptwebqq, :vfwebqq)

	ON_CAPTCHA_REQUIRE = lambda do |image_data|
		File.open("#{File.dirname(__FILE__)}/captcha.jpg", 'wb'){ |file| file << image_data }
		puts '验证码已保存到 captcha.jpg, 请输入验证码：'
		gets.strip.upcase
	end

	include Logger::Severity

	attr_reader :user, :friends, :groups, :discusses

	def initialize(account, password, is_md5, on_captcha_require = ON_CAPTCHA_REQUIRE)
		super()
		@logger = Logger.new("#{File.dirname(__FILE__)}/webqq_client.log", 1)
		@logger.formatter = proc do |severity, datetime, prog_name, msg|
			"[#{datetime}][#{severity}][#{prog_name}] #{msg}\n"
		end

		@validate = Validate.new

		@friends, @groups, @discusses = {}, {}, {}

		header['User-Agent'] = 'Mozilla/5.0 (Windows NT 6.3; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/40.0.2214.93 Safari/537.36'
		cookies << Cookie.new('pgv_info', "ssid=s#{(rand * 1E10).round}", 'qq.com', '/')
		cookies << Cookie.new('pgv_pvid', "#{(rand * 1E10).round}", 'qq.com', '/')

		pre_login(account, password, is_md5, on_captcha_require)
	end

	def start
		@validate[:clientid], @validate[:ptwebqq] = 53999199, cookies['qq.com', '/', 'ptwebqq'].value

		data = login

		@validate[:psessionid], @validate[:vfwebqq] = data['psessionid'], data['vfwebqq']

		@user = Friend.new(get_friend_uin(data['uin'], 1)['account'], get_self_info)

		set_entries

		@receiver = Receiver.new(
			method(:poll),
			method(:log)
		)

		@sender = Sender.new(
			method(:send_msg),
			method(:send_session_msg),
			method(:send_group_msg),
			method(:send_discuss_msg),
			method(:log)
		)
	end

	def stop
		@receiver.shutdown
		@sender.shutdown
		@entries_update.shutdown
	end

	def set_handler(handler)
		@receiver.handler = handler
	end

	def unset_handler
		@receiver.handler = Receiver::DEFAULT_HANDLER
	end

	self.class_eval do
		encode_message = lambda do |message, font|
			Yajl.dump(
				[
					message, [
						'font', {
							name: font[:name] || '宋体',
							size: font[:size] || 10,
							style: font[:style] || [0, 0, 0],
							color: font[:color] || '000000'
						}
					]
				]
			)
		end

		define_method :send_message do |to, message, font|
			case to
			when WebQQClient::Friend
				@sender.push(type: :message, to: to.id, content: encode_message.call(message.strip, font))
			when WebQQClient::Group
				@sender.push(type: :group_message, to: to.id, content: encode_message.call(message.strip, font))
			when WebQQClient::Discuss
				@sender.push(type: :discuss_message, to: to.id, content: encode_message.call(message.strip, font))
			else
				log(ERROR, self.class, "发送类型未知 #{to.class}", true)
			end
		end
	end

	def log(severity, progname, message, echo = false)
		warn "[#{Time.now}][#{progname}] #{message}" if echo
		@logger.log(severity, message, progname)
	end

	protected

	attr_reader :validate

	private

	include APIProxy

	def set_entries
		@friends = Hash.new do |friends, uin|
			friends[uin] = Friend.new(get_friend_uin(uin, 1)['account'], get_friend_info(uin))
		end

		groups_list = {}
		@groups = Hash.new do |groups, gid|
			group = groups_list[gid]
			groups[gid] = Group.new(get_friend_uin(group['code'], 4)['account'], get_group_info_list(group['code'])) do |uin|
				get_friend_uin(uin, 1)['account']
			end
		end

		@discusses = Hash.new do |discusses, did|
			discusses[did] = Discuss.new(get_discu_info_list(did)) do |uin|
				get_friend_uin(uin, 1)['account']
			end
		end

		@entries_update = Concurrent::TimerTask.execute(execution: 7200, timeout: 60, now: true) do
			groups_list.clear
			get_group_list['gnamelist'].each{ |gname| groups_list[gname['gid']] = gname }

			@friends.clear
			@groups.clear
			@discusses.clear

			log(INFO, self.class, '实体更新完毕', true)
		end
	end

	class_eval do
		emulator = Object.new

		emulator.instance_eval do
			define_singleton_method :ptui_checkVC do |state, verify_code, salt, pt_verify_session, pt_is_rand_salt|
				[state == '0', verify_code, salt, pt_verify_session, pt_is_rand_salt.to_i]
			end

			define_singleton_method :ptuiCB do |state, _, callback, _, info, _|
				[state.to_i, callback, info]
			end
		end

		appid = 501004106
		js_ver = 10113
		js_type = 0
		login_sig = 'bjW2f0yRgQsfmYZHLbboRdq908JAR2O7Y7ea8JqZ5pDdnnyl1rHmsSVP3A74piPs'
		daid = 164

		define_method :pre_login do |account, password, is_md5, on_captcha_require|
			cookies << Cookie.new('chkuin', account, 'ptlogin2.qq.com', '/')
			loop do
				uri = URI('https://ssl.ptlogin2.qq.com/check')
				uri.query = URI.encode_www_form(
					pt_tea: 1,
					uin: account,
					appid: appid,
					js_ver: js_ver,
					js_type: js_type,
					login_sig: login_sig,
					u1: 'http://w.qq.com/proxy.html',
					r: Random.rand
				)
				need_vc, verify_code, salt, pt_verify_session, pt_is_rand_salt = emulator.instance_eval(get(uri))

				unless need_vc
					uri = URI('https://ssl.captcha.qq.com/getimage')
					uri.query = URI.encode_www_form(
						aid: appid,
						r: Random.rand,
						uin: account,
					)
					verify_code = on_captcha_require[get(uri)]
					pt_verify_session = cookies['qq.com', '/', 'verifysession'].value
				end

				uri = URI('https://ssl.ptlogin2.qq.com/login')
				uri.query = URI.encode_www_form(
					u: account,
					p: Encrypt.password(password, salt, verify_code, is_md5),
					verifycode: verify_code,
					webqq_type: 10,
					remember_uin: 1,
					login2qq: 1,
					aid: appid,
					u1: 'http://w.qq.com/proxy.html?login2qq=1&webqq_type=10',
					h: 1,
					ptredirect: 0,
					ptlang: 2052,
					daid: daid,
					from_ui: 1,
					pttype: 1,
					dumy: nil,
					fp: 'loginerroralert',
					action: "0-#{Random.rand(10..30)}-#{Random.rand(10000..20000)}",
					mibao_css: 'm_webqq',
					t: 1,
					g: 1,
					js_type: js_type,
					js_ver: js_ver,
					login_sig: login_sig,
					pt_randsalt: (pt_is_rand_salt || 0),
					pt_vcode_v1: 0,
					pt_verifysession_v1: pt_verify_session,
				)
				state, callback_address, info = emulator.instance_eval(get(uri))

				succeed = false

				case state
				when 0
					get(URI(callback_address))
					succeed = true
				when 4
					puts '验证码错误'
				else
					fail "登录失败：#{info.force_encoding('utf-8')}"
				end

				break if succeed
			end
		end
	end
end