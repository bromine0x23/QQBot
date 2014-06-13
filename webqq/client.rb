# -*- coding: utf-8 -*-

require 'logger'
require 'json'

require_relative 'config'
require_relative 'net_client'
require_relative 'entity'
require_relative 'receiver'
require_relative 'sender'

module WebQQProtocol

	#noinspection RubyTooManyInstanceVariablesInspection,RubyTooManyMethodsInspection
	class Client
		attr_reader :qq, :nick
		attr_reader :receiver, :sender
		attr_reader :friends, :groups, :discusses

		DEFAULT_ON_CAPTCHA_NEED = proc do |image_data|
			File.open('captcha.jpg', 'wb') do |file|
				file << image_data
			end
			puts '验证码已保存到 captcha.jpg, 请输入验证码：'
			gets.strip.upcase
		end

		def initialize(qq, password, logger, on_captcha_need = DEFAULT_ON_CAPTCHA_NEED)
			@qq = qq
			@logger = logger
			@on_captcha_need = on_captcha_need

			start(password)
		end

		def start(password)
			init_client

			init_login(password)

			init_session

			log('登录成功')

			init_entities

			init_thread

			log('客户端建立成功')
		end

		def stop
			@receiver.thread.kill
			@sender.thread.kill
			@net, @sender, @receiver = nil, nil, nil
		end

		# @return [WebQQProtocol::Friend]
		def friend_by_uin(uin)
			@friends[uin]
		end

		# @return [WebQQProtocol::Friend]
		def friend_by_number(number)
			@friends.values.find { |friend| friend.number == number }
		end

		# @return [WebQQProtocol::Friend]
		def friend_by_name(name)
			@friends.values.find { |friend| friend.name == name }
		end

		# @return [WebQQProtocol::Group]
		def group_by_uin(uin)
			@groups[uin]
		end

		# @return [WebQQProtocol::Group]
		def group_by_number(number)
			@groups.values.find { |group| group.number == number }
		end

		# @return [WebQQProtocol::Group]
		def group_by_name(name)
			@groups.values.find { |group| group.name == name }
		end

		# @return [WebQQProtocol::Group]
		def discuss_by_uin(uin)
			@discusses[uin]
		end

		# @return [WebQQProtocol::Group]
		def discuss_by_name(name)
			@discusses.values.find { |discuss| discuss.name == name }
		end

		# @return [WebQQProtocol::QQEntity]
		def entity_by_uin(uin)
			friend_by_uin(uin) || group_by_uin(uin)
		end

		def referer_header(host)
			{
				'origin' => host,
				'referer' => "http://#{host}/proxy.html?v=20130916001&callback=1&id=2"
			}
		end

		# HTTP GET 请求，返回解析后的 json 数据的 result 键对应的值
		def http_get(host, path, query)
			NetClient.json_result(
				@net.http_get(
					host,
					path,
					query,
					referer_header(host)
				)
			)
		end

		# HTTP GET 请求，返回解析后的 json 数据的 result 键对应的值
		def https_get(host, path, query)
			NetClient.json_result(
				@net.https_get(
					host,
					path,
					query,
					referer_header(host)
				)
			)
		end

		# HTTP POST 请求，返回解析后的 json 数据的 result 键对应的值
		def http_post(host, path, data)
			NetClient.json_result(
				@net.http_post(
					host,
					path,
					{
						r: JSON.fast_generate(data)
					},
					referer_header(host)
				)
			)
		end

		# HTTP POST 请求，返回解析后的 json 数据的 result 键对应的值
		def https_post(host, path, data)
			NetClient.json_result(
				@net.https_post(
					host,
					path,
					{
						r: JSON.fast_generate(data)
					},
					referer_header(host)
				)
			)
		end

		def init_client
			@net = NetClient.new

			@net.header['User-Agent'] = Config::USER_AGENT

			@clientid = Random.rand(10000000...100000000) # 客户端id
		end

		def init_login(password)
			loop do
				cookie = WEBrick::Cookie.new('chkuin', @qq)
				cookie.domain = 'ptlogin2.qq.com'
				cookie.path = '/'

				@net.cookies.add!(cookie)

				/ptui_checkVC\('(?<need_verify>.*)','(?<verify_code>.*)','(?<encrypt_key>.*)', '.*'\);/ =~ load_check

				need_verify, verify_code, encrypt_key = $~[:need_verify], $~[:verify_code], $~[:encrypt_key]

				verify_code = get_verify_code if need_verify != '0'

				/ptuiCB\('(?<state>.*)','.*','(?<address>.*)','.*','(?<info>.*)', '(?<nick>.*)'\);/ =~ load_login(verify_code, Utility.hash_password(password, verify_code, encrypt_key))

				state, address, info, @nick = $~[:state], $~[:address], $~[:info].force_encoding('utf-8'), $~[:nick].force_encoding('utf-8')

				case state
				when '0'
					@net.uri_get(URI(address))
					break
				when '3'
					log("密码错误(#{info})", Logger::ERROR)
					raise PasswordWrong.new
				when '4'
					log("验证码错误(#{info})", Logger::ERROR)
					next
				when 7
					log("账号验证失败(#{info})", Logger::ERROR)
					raise
				else
					raise LoginFailed.new(state, info.force_encoding('utf-8'))
				end
			end
		end

		def ptwebqq
			@net.cookies['ptwebqq']
		end

		def init_session
			@psessionid = ''

			result = require_login

			@psessionid, @uin, @vfwebqq = result['psessionid'], result['uin'], result['vfwebqq']
		end

		def init_entities
			friends_data = require_friends

			friends_list = Hash[
				friends_data['marknames'].map! { |markname|
					[markname['uin'], markname['markname']]
				}
			].merge!(
				Hash[
					friends_data['info'].map! { |info|
						[info['uin'], info['nick']]
					}
				]
			)

			@friends = Hash.new do |friends, uin|
				friends[uin] = Friend.new(
					uin,
					friends_list[uin],
					require_number(uin, 1)['account'],
				)
			end

			on_number_require = proc do |uin|
				require_number(uin, 1)['account']
			end

			groups_data = require_groups

			groups_list = Hash[
				groups_data['gnamelist'].map! { |gname|
					[gname['gid'], gname]
				}
			]

			@groups = Hash.new do |groups, gid|
				group = groups_list[gid]
				groups[gid] = Group.new(
					group['gid'],
					group['name'],
					require_number(group['code'], 4)['account'],
					require_group_info(group['code']),
					&on_number_require
				)
			end

			discusses_data = require_discusses

			discusses_list = Hash[
				discusses_data['dnamelist'].map! { |dname|
					[dname['did'], dname]
				}
			]

			@discusses = Hash.new do |discusses, did|
				discuss = discusses_list[did]
				discusses[did] = Discuss.new(
					discuss['din'],
					discuss['nick'],
					&on_number_require
				)
			end
		end

		def init_thread
			@receiver = Receiver.new(@clientid, @psessionid, @net, @logger)
			@sender = Sender.new(@clientid, @psessionid, @net, @logger)
		end

		# 校验账号
		def load_check
=begin
ptui_checkVC(need_verify, verify_code, encrypt_key);
=end
			@net.https_get(
				'ssl.ptlogin2.qq.com',
				'/check',
				uin: @qq,
				appid: Config::APPID,
				js_ver: Config::JS_VER,
				js_type: Config::JS_TYPE,
				login_sig: Config::LOGIN_SIG,
				u1: 'http://w.qq.com/proxy.html',
				r: Random.rand
			)
		end

		# 获取验证码
		def get_verify_code
			@on_captcha_need.call(
				@net.https_get(
					'ssl.captcha.qq.com',
					'/getimage',
					aid: Config::APPID,
					r: Random.rand,
					uin: @qq,
				)
			)
		end

		# 登录第一步，获取登录回调代码
=begin
ptuiCB(state, _, address, _, info, nick);
=end
		def load_login(verify_code, password)
			@net.https_get(
				'ssl.ptlogin2.qq.com',
				'/login',
				u: @qq,
				p: password,
				verifycode: verify_code,
				webqq_type: 10,
				remember_uin: 1,
				login2qq: 1,
				aid: Config::APPID,
				u1: 'http://w.qq.com/proxy.html?login2qq=1&webqq_type=10',
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
		end

		# 登录第二步，获取会话数据
		def require_login
			https_post(
				'd.web2.qq.com',
				'/channel/login2',
				ptwebqq: ptwebqq,
				clientid: @clientid,
				psessionid: @psessionid,
				status: 'online',
			)
		end

		# 获取好友信息
		def require_friends
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
			http_post(
				's.web2.qq.com',
				'/api/get_user_friends2',
				vfwebqq: @vfwebqq,
				hash: Utility.hash_get(@uin, ptwebqq),
			)
		end

		# 获取群信息
		def require_groups
=begin
{
	"gmarklist": [],
	"gmasklist": [],
    "gnamelist": [ { "flag": 0, "name": "", "gid": 0, "code": 0 }, ...... ]
}
=end
			http_post(
				's.web2.qq.com',
				'/api/get_group_name_list_mask2',
				vfwebqq: @vfwebqq,
				hash: Utility.hash_get(@uin, ptwebqq),
			)
		end

		# 获取讨论组信息
		def require_discusses
=begin
{
	"dnamelist":[
		{"name":"","did":0}
	]
}
=end
			http_get(
				's.web2.qq.com',
				'/api/get_discus_list',
				clientid: @clientid,
				psessionid: @psessionid,
				vfwebqq: @vfwebqq,
				t: Time.now.to_i,
			)
		end

		# 通过 uin 获取 Q号 或 群号
		def require_number(uin, type)
=begin
{ "uiuin": "", "account": 0, "uin": 0 }
=end
			http_get(
				's.web2.qq.com',
				'/api/get_friend_uin2',
				tuin: uin,
				verifysession: nil,
				type: type,
				code: nil,
				vfwebqq: @vfwebqq,
				t: Time.now.to_i,
			)
		end

		def require_self_info
=begin
{
	"birthday":{"month":0,"year":0,"day":0}, #生日
	"face":555,
	"phone":"",
	"occupation":"",
	"allow":1,
	"college":"",
	"uin":0,
	"blood":2, # 血型
	"constel":, # 星座
	"lnick":"签名",
	"vfwebqq":"",
	"homepage":"主页",
	"vip_info":0,
	"city":"城市",
	"country":"国家",
	"personal":"",
	"shengxiao":, # 生肖
	"nick":"昵称",
	"email":"",
	"province":"省份",
	"account":0,
	"gender":"性别",
	"mobile":""
}
=end
			http_get(
				's.web2.qq.com',
				'/api/get_self_info2',
				t: Time.now.to_i,
			)
		end

		# 获取好友状态
		def require_online_buddies
=begin
[
	{
		"uin":0,
		"status":"busy", # "online", "callme", "away", "busy", "silent", "hidden", "offline"
		"client_type":1 # 1 或21
	},
	......
]
=end
			http_get(
				'd.web2.qq.com',
				'/channel/get_online_buddies2',
				clientid: @clientid,
				psessionid: @psessionid,
				vfwebqq: @vfwebqq,
				t: Time.now.to_i,
			)
		end

		# 获取近期会话列表
=begin
[
	{
		"uin":0,
		"type":1 # 0 或 1
	},
	......
]
=end
		def require_recent_list
			http_post(
				'd.web2.qq.com',
				'/channel/get_recent_list2',
				clientid: @clientid,
				psessionid: @psessionid,
				vfwebqq: @vfwebqq,
			)
		end

		# 获取好友信息
		def require_friend_info(uin)
=begin
{
	"face":177, # 头像
	"birthday":{ # 生日
		"month":9,
		"year":1993,
		"day":16
	},
	"occupation":"",
	"phone":"电话",
	"allow":1,
	"college":"学校",
	"uin":0,
	"constel":0, # 星座
	"blood":0, # 血型
	"homepage":"",
	"stat":10,
	"vip_info":0,
	"country":"国家",
	"city":"城市",
	"personal":"",
	"nick":"昵称",
	"shengxiao":10, # 生肖
	"email":"邮箱",
	"client_type":1,
	"province":"省份",
	"gender":"性别",
	"mobile":"移动电话" #
}
=end
			http_get(
				's.web2.qq.com',
				'/api/get_friend_info2',
				tuin: uin,
				vfwebqq: @vfwebqq,
				clientod: @clientid,
				psessionid: @psessionid,
				t: Time.now.to_i,
			)
		end

		def require_group_info(gcode)
=begin
｛
	# 在线成员
	"stats":[
		{
			"client_type":1,
			"uin":549264057,
			"stat":10
		},
		......
	],
	# 成员信息
	"minfo":[
		{
			"nick":"",
			"province":"",
			"gender":"male",
			"uin":0,
			"country":"",
			"city":""
		},
		......
	],
	# 群信息
	"ginfo":{
		"face":0,
		"memo":"群简介",
		"class":25,
		"fingermemo":"",
		"code":,
		"createtime":,
		"flag":,
		"level":0,
		"name":"群名称",
		"gid":,
		"owner":, # 群主uin
		"members":[
			{
				"muin":0,
				"mflag":0
			},
		],
		"option":2
	},
	# 群名片
	"cards":[
		{
			"muin":0,
			"card":"群名片"
		},
		......
	],
	"vipinfo":[
		{
			"vip_level":,
			"u":,
			"is_vip":
		},
		.......
	]
}
=end
			http_get(
				's.web2.qq.com',
				'/api/get_group_info_ext2',
				gcode: gcode,
				vfwebqq: @vfwebqq,
				t: Time.now.to_i
			)
		end

		def allow_add_add(account)
			# 同意添加好友
=begin
{ "result1": 0, "account": "10000" ,  "tuin": "uin", "stat": 10 }
=end
			http_post(
				's.web2.qq.com',
				'/api/allow_and_add2',
				account: account,
				gid: 0,
				mname: '',
				vfwebqq: @vfwebqq
			)
		end

		def send_buddy_message(from, message, font = {})
			@sender.send_buddy_message(from.uin, message.strip, font)
		end

		def send_group_message(from, message, font = {})
			@sender.send_group_message(from.uin, message.strip, font)
		end

		def send_discuss_message(from, message, font = {})
			@sender.send_discuss_message(from.uin, message.strip, font)
		end

		# 添加好友
		# @return [WebQQProtocol::Friend]
		def add_friend(account)
			json_data = allow_add_add(account)
			uin = json_data['tuin']
			@friends[uin] = Friend.new(uin, json_data['account'], require_friend_info(uin)['nick'])
		end

		def poll_data
			@receiver.data
		end

		def online?
			@sender.alive? and @receiver.alive?
		end

		def log(message, level = Logger::INFO)
			@logger.log(level, message, self.class.name)
		end
	end
end