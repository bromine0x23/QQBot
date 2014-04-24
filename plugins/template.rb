# -*- coding: utf-8 -*-

# 插件源文件名应匹配 /plugin*.rb/
# 类名匹配 /Plugin.*Base/ 的类不会生成实例（载入）

# 最基础的插件类
class PluginTemplate < PluginBase
	# 类变量
	# @@plugins # => 用作生成实例的Plugin类，在有类继承自 PluginBase 时自动更新

	# 实例变量
	# [QQBot]  @qqbot  # => QQ机器人实例
	# [Logger] @logger # => Logger实例
	# [Method] @send_message       # => 好友消息发送方法，参数为([Integer] uin, [String] 消息, [Hash] 字体设置)
	# [Method] @send_group_message # => 群消息发送方法，参数同上
	
	# protected 实例方法
	# log(message, level = Logger::INFO) # 记录日志
	
	# 常量
	NAME = '插件名'
	AUTHOR = '作者'
	VERSION = '版本'
	DESCRIPTION = '描述'
	MANUAL = <<MANUAL
手册
MANUAL
	PRIORITY = 0 # 优先级，用以确定处理的顺序，优先级高的先执行，默认为 0

	def on_load
		super
		# 插件载入时被调用
	end

	def on_unload
		super
		# 插件卸载时被调用
	end

	def on_enter_loop
		super
		# 呃……还没被调用
	end

	def on_exit_loop
		super
		# 同上
	end

	def on_message(value)
		super
		# 处理 message 消息
	end

	def on_group_message(value)
		super
		# 处理 group_message 消息
	end

	def on_input_notify(value)
		super
		# 处理 input_notify 消息
	end

	def on_buddies_status_change(value)
		super
		# 处理 buddies_status_change 消息
	end

	def on_sess_message(value)
		super
		# 处理 sess_message 消息
	end

	def on_kick_message(value)
		super
		# 处理 on_kick_message 消息
	end
	
	def on_group_web_message(value)
		super
		# 处理 group_web_message 消息
		nil
	end

	def on_system_message(value)
		super
		# 处理 system_message 消息
		nil
	end

	def on_sys_g_msg(value)
		super
		# 处理 sys_g_msg 消息
		nil
	end

	def on_buddylist_change(value)
		super
		# 处理 buddylist_change 消息
		nil
	end
end

# 回应群或好友消息的插件
class PluginResponderTemplate < PluginResponderBase

	# 实例方法
	# bot_name -> String # 获得QQBot名字

	# [WebQQProtocol::QQFriend] sender  => 消息发送者
	# [String]                  command => 命令
	# [Time]                    time    => 时间
	def deal_message(sender, content, time)
		super
		# 处理好友消息响应
	end

	# [WebQQProtocol::QQGroup]       from    => 消息来自的群
	# [WebQQProtocol::QQGroupMember] sender  => 消息发送者
	# [String]                       command => 命令
	# [Time]                         time    => 时间
	def deal_group_message(from, sender, content, time)
		super
		# 处理群消息响应
	end
end

# 在群中需要用昵称用呼叫的插件
#noinspection RubyClassModuleNamingConvention
class PluginNicknameResponderTemplate < PluginNicknameResponderBase

	# [WebQQProtocol::QQEntity] from    => 消息来自何处，好友[WebQQProtocol::QQFriend]或群[WebQQProtocol::QQGroup]
	# [WebQQProtocol::QQEntity] sender  => 消息发送者，好友[WebQQProtocol::QQFriend]或群成员[WebQQProtocol::QQGroupMember]
	# [String]                  command => 命令
	# [Time]                    time    => 时间
	# 返回值在不为false或nil时会作为回应消息发送
	def get_response(from, sender, command, time)
		nil or false or '回应消息'
	end
end

#noinspection RubyClassModuleNamingConvention
class PluginNicknameResponderCombineFunctionTemplate < PluginNicknameResponderCombineFunctionBase

	# [WebQQProtocol::QQEntity] from    => 消息来自何处，好友[WebQQProtocol::QQFriend]或群[WebQQProtocol::QQGroup]
	# [WebQQProtocol::QQEntity] sender  => 消息发送者，好友[WebQQProtocol::QQFriend]或群成员[WebQQProtocol::QQGroupMember]
	# [String]                  command => 命令
	# [Time]                    time    => 时间
	def function_template1(from, sender, command, time)
		nil or false or '回应消息'
	end

	def function_template2(from, sender, command, time)
		nil or false or '回应消息'
	end

	# 在接收到消息时自动依声明顺序调用各 function_XXX 方法，直到获得回应消息
end