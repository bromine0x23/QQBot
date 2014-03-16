#!/usr/bin/ruby
# -*- coding: utf-8 -*-

# 插件源文件名应匹配 /plugin*.rb/
# 类名匹配 /Plugin.*Base/ 的类不会生成实例（载入）

# 

# 最基础的插件类
class PluginTemplate < PluginBase
	# 实例变量
	# [QQBot]  @qqbot  => QQ机器人实例
	# [Logger] @logger => Logger实例
	# [Method] @send_message       => 好友消息发送方法，参数为([Integer] uin, [String] 消息, [Hash] 字体设置)
	# [Method] @send_group_message => 群消息发送方法，参数同上
	
	# protected方法
	# log(message, level = Logger::INFO) # 记录日志
	# debug(message)                     # 仅在debug模式下记录日志
	

	NAME = '插件名'
	AUTHOR = '作者'
	VERSION = '版本'
	DESCRIPTION = '描述'
	MANUAL = <<MANUAL
手册
MANUAL
	PRIORITY = 0 # 优先级

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
end

# 回应群或好友消息的插件
class PluginResponserTemplate < PluginResponserBase

	# uin             => 群或好友的uin
	# sender_qq       => 消息发送者的Q号
	# sender_nickname => 消息发送者的群名片（如果有）或昵称
	# content         => 消息内容
	# time            => 时间（以秒数）

	def deal_message(uin, sender_qq, sender_nickname, content, time)
		super
		# 处理好友消息响应
	end

	def deal_group_message(guin, sender_qq, sender_nickname, content, time)
		super
		# 处理群消息响应
	end
end

# 在群中需要用昵称用呼叫的插件
class PluginNicknameResponserTemplate < PluginNicknameResponserBase
	# @nickname => 机器人昵称

	# uin             => 群或好友的uin
	# sender_qq       => 消息发送者的Q号
	# sender_nickname => 消息发送者的群名片（如果有）或昵称
	# message         => 消息文本
	# time            => 时间（以秒数）
	# 返回值在不为false或nil时会作为回应消息发送
	def get_response(uin, sender_qq, sender_nickname, message, time)
		nil or false or '回应消息'
	end
end