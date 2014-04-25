# -*- coding: utf-8 -*-

# 插件源文件名应匹配 /plugin*.rb/
# 类名匹配 /Plugin.*Base/ 的类不会生成实例（载入）
# 插件类与插件源文件名应保持一致，插件类用大驼峰式命名法(UpperCamelCase)，源文件用小驼峰式命名法(lowerCamelCase)

# 最基础的插件类
class PluginTemplate < PluginBase
	# 类变量
	# @@plugins # => 用作生成实例的Plugin类，在有类继承自 PluginBase 时自动更新

	# public 实例方法
	# name        -> String  # 返回插件名字
	# author      -> String  # 返回插件作者
	# version     -> String  # 返回插件版本
	# description -> String  # 返回插件描述
	# manual      -> String  # 返回插件帮助
	# priority    -> Integer # 返回插件优先级
	# info        -> Hash    # 返回所有插件信息

	# protected 实例方法
	# qqbot -> QQBot # QQ机器人实例
	# log(message, level = Logger::INFO) # 记录日志

	# protected 类方法
	# file_path([String] file_name) # 扩展文件名至相对插件文件夹
	
	# 常量
	NAME = '插件名'
	AUTHOR = '作者'
	VERSION = '版本'
	DESCRIPTION = '描述'
	MANUAL = <<MANUAL
手册
MANUAL
	PRIORITY = 0 # 优先级，用以确定处理的顺序，优先级高的先执行，默认为 0

	# 可扩展的实例方法
	# on_load   # 插件载入时被调用
	# on_unload #插件卸载时被调用

	# 可定义的实例方法
	# on_message([WebQQProtocol::QQFriend] sender, [String] message, [Time] time) # 处理 message 消息
	# on_group_message([WebQQProtocol::QQGroup] from, [WebQQProtocol::QQGroupMember] sender, [String] message, [Time] time)
	#     # 处理 group_message 消息
	# on_input_notify([Hash] value)          # 处理 input_notify          消息
	# on_buddies_status_change([Hash] value) # 处理 buddies_status_change 消息
	# on_sess_message([Hash] value)          # 处理 sess_message          消息
	# on_kick_message([Hash] value)          # 处理 kick_message          消息
	# on_group_web_message([Hash] value)     # 处理 group_web_message     消息
	# on_system_message([Hash] value)        # 处理 system_message        消息
	# on_sys_g_msg([Hash] value)             # 处理 sys_g_msg             消息
	# on_buddylist_change([Hash] value)      # 处理 buddylist_change      消息
end

# 回应群或好友消息的插件
#noinspection RubyUnusedLocalVariable
class PluginResponderTemplate < PluginResponderBase
	# 该插件调用方法为：
	#     我叫你一声你敢答应吗
	# 对好友消息返回：
	#     好友消息
	# 对群消息返回：
	#     群消息

	# 需要覆写的实例方法

	# 处理好友消息
	# [WebQQProtocol::QQFriend] sender  => 消息发送者
	# [String]                  message => 消息
	# [Time]                    time    => 时间
	def deal_message(sender, message, time)
		if command == '我叫你一声你敢答应吗'
			'好友消息'
		end
	end

	# 处理群消息
	# [WebQQProtocol::QQGroup]       from    => 消息来自的群
	# [WebQQProtocol::QQGroupMember] sender  => 消息发送者
	# [String]                       message => 消息
	# [Time]                         time    => 时间
	def deal_group_message(from, sender, message, time)
		if command == '我叫你一声你敢答应吗'
			'群消息'
		end
	end
end

# 在群中需要用昵称用呼叫的插件
#noinspection RubyClassModuleNamingConvention,RubyUnusedLocalVariable
class PluginNicknameResponderTemplate < PluginNicknameResponderBase
	# 该插件调用格式为：
	#     <昵称> 测试
	# 返回：
	#     测试

	# 可用接口
	# protected 实例方法
	# bot_name -> String # 返回呼叫QQBot使用的昵称

	# 需要覆写的实例方法

	# 回应消息，返回值在不为false或nil时会发送到 from
	# [WebQQProtocol::QQEntity] from    => 消息来自何处，好友[WebQQProtocol::QQFriend]或群[WebQQProtocol::QQGroup]
	# [WebQQProtocol::QQEntity] sender  => 消息发送者，好友[WebQQProtocol::QQFriend]或群成员[WebQQProtocol::QQGroupMember]
	# [String]                  command => 命令
	# [Time]                    time    => 时间
	def get_response(from, sender, command, time)
		if command == '测试'
			'测试'
		end
	end
end

#noinspection RubyClassModuleNamingConvention,RubyUnusedLocalVariable
class PluginNicknameResponderCombineFunctionTemplate < PluginNicknameResponderCombineFunctionBase
	# 该插件调用格式为：
	#     <昵称> 模版 测试 <任意文本>
	# 返回格式为：
	#     [<时间>] <任意文本>

	COMMAND_HEADER = '模版' # 用于定义呼叫插件的字符串

	# [WebQQProtocol::QQEntity] from    => 消息来自何处，好友[WebQQProtocol::QQFriend]或群[WebQQProtocol::QQGroup]
	# [WebQQProtocol::QQEntity] sender  => 消息发送者，好友[WebQQProtocol::QQFriend]或群成员[WebQQProtocol::QQGroupMember]
	# [String]                  command => 命令
	# [Time]                    time    => 时间
	# 在接收到消息时自动依声明顺序调用各 function_XXX 方法，直到获得回应消息
	def function_template(from, sender, command, time)
		if /^测试\s*(?<string>.*)/ =~ command
			"[#{time.to_s}] #{$~[:string]}"
		end
	end

	# 其他可覆写的方法
	# command_header -> String   # 默认为 self.class::COMMAND_HEADER
	# command_pattern -> Regexp  # 默认为 /^#{command_header}\s*(?<command>.+)/i
	# functions -> Array[Symbol] # 默认返回所有匹配 /^function_/ 的方法名
end