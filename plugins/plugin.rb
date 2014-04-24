# -*- coding: utf-8 -*-

require 'yaml'

#noinspection RubyClassVariableUsageInspection,RubyTooManyMethodsInspection
class PluginBase
	NAME = '插件基类'
	AUTHOR = 'BR'
	VERSION = '0.0'
	DESCRIPTION = '用于派生其他插件'
	MANUAL = <<MANUAL
MANUAL
	PRIORITY = 0

	PLUGIN_DIRECTORY = File.expand_path(File.dirname(__FILE__))

	@@plugins = []
	@@instance_plugins = []

	def self.instance_plugins
		@@instance_plugins
	end

	def self.plugins
		@@plugins
	end

	# @param [QQBot] qqbot
	# @param [Logger] logger
	def initialize(qqbot, logger)
		@qqbot = qqbot
		@logger = logger
		@send_message = @qqbot.method(:send_message)
		@send_group_message = @qqbot.method(:send_group_message)
		on_load
		log('初始化完毕', Logger::DEBUG) if $-d
	end

	# @return [String]
	def name
		self.class::NAME
	end

	# @return [String]
	def author
		self.class::AUTHOR
	end

	# @return [String]
	def version
		self.class::VERSION
	end

	# @return [String]
	def description
		self.class::DESCRIPTION
	end

	# @return [String]
	def manual
		self.class::MANUAL
	end

	# @return [Integer]
	def priority
		self.class::PRIORITY
	end

	# @return [Hash]
	def info
		{
			name: name,
			author: author,
			version: version,
			description: description,
			manual: manual,
			priority: priority
		}
	end

	def on_load
		file_name = self.class.name
		file_name[0] = file_name[0].downcase

		config_file = "#{PLUGIN_DIRECTORY}/#{file_name}.config"

		if File.exist? config_file
			YAML.load_file(config_file).each_pair { |key, value| instance_variable_set(:"@#{key}", value) }
		end

		data_file = "#{PLUGIN_DIRECTORY}/#{file_name}.data"
		@data = YAML.load_file(data_file) if File.exist? data_file
	end

	def on_unload
		# 桩方法
	end

	def on_enter_loop
		# 桩方法
	end

	def on_exit_loop
		# 桩方法
	end

	# @param [Hash] value
	def on_message(value)
		log("message #{value}", Logger::DEBUG) if $-d
		# 桩方法，处理 message 消息
		nil
	end

	# @param [Hash] value
	def on_group_message(value)
		log("group_message #{value}", Logger::DEBUG) if $-d
		# 桩方法，处理 group_message 事件
		nil
	end

	# @param [Hash] value
	def on_input_notify(value)
		log("input_notify #{value}", Logger::DEBUG) if $-d
		# 桩方法，处理 input_notify 消息
		true # 暂时忽略
	end

	# @param [Hash] value
	def on_buddies_status_change(value)
		log("buddies_status_change #{value}", Logger::DEBUG) if $-d
		# 桩方法，处理 buddies_status_change 消息
		nil
	end

	# @param [Hash] value
	def on_sess_message(value)
		log("sess_message #{value}")
		# 桩方法，处理 sess_message 消息
		nil
	end

	# @param [Hash] value
	def on_kick_message(value)
		log("kick_message #{value}")
		# 桩方法，处理 kick_message 消息
		true
	end

	# @param [Hash] value
	def on_group_web_message(value)
		log("group_web_message #{value}")
		# 桩方法，处理 group_web_message 消息
		true
	end

	# @param [Hash] value
	def on_system_message(value)
		log("system_message #{value}")
		# 桩方法，处理 system_message 消息
		true
	end

	# @param [Hash] value
	def on_sys_g_msg(value)
		log("sys_g_msg #{value}")
		# 桩方法，处理 sys_g_msg 消息
		true
	end

	# @param [Hash] value
	def on_buddylist_change(value)
		log("buddylist_change #{value}")
		# 桩方法，处理 buddylist_change 消息
		true
	end

	protected

	def qqbot
		@qqbot
	end

	def log(message, level = Logger::INFO)
		@logger.log(level, message, self.class.name)
	end

	def self.file_path(source_path, file_name)
		File.expand_path "#{File.dirname(source_path)}/#{file_name}"
	end

	private

	STR_BASE = 'Base'

	# @param [Class] subclass
	def self.inherited(subclass)
		@@plugins.unshift subclass
		@@instance_plugins << subclass unless subclass.name.end_with? STR_BASE
	end
end

class PluginResponderBase < PluginBase
	NAME = '消息回应插件基类'

	KEY_FROM_UIN = 'from_uin'
	KEY_SEND_UIN = 'send_uin'
	KEY_CONTENT  = 'content'
	KEY_TIME     = 'time'

	# @param [Hash] value
	def on_message(value)
		super
		sender = qqbot.friend(value[KEY_FROM_UIN])
		time = Time.at(value[KEY_TIME])
		deal_message(sender, value[KEY_CONTENT], time)
	end

	# @param [Hash] value
	def on_group_message(value)
		super
		from = qqbot.group(value[KEY_FROM_UIN])
		sender = from.member(value[KEY_SEND_UIN])
		time = Time.at(value[KEY_TIME])
		deal_group_message(from, sender, value[KEY_CONTENT], time)
	end

	# @param [WebQQProtocol::QQFriend] sender
	# @param [content] content
	# @param [Time] time
	def deal_message(sender, content, time)
		# 桩方法，处理事件响应
	end

	# @param [WebQQProtocol::QQGroup] from
	# @param [WebQQProtocol::QQGroupMember] sender
	# @param [content] content
	# @param [Time] time
	def deal_group_message(from, sender, content, time)
		# 桩方法，处理群事件响应
	end
end

class PluginNicknameResponderBase < PluginResponderBase
	NAME = '昵称呼叫型消息回应插件基类'

	def deal_message(sender, content, time)
		response_or_ignore(sender, sender, QQBot.message(content), time, @send_message)
	end

	def deal_group_message(from, sender, content, time)
		if /^\s*@?#{bot_name}(?<message>.*)/ =~ QQBot.message(content)
			response_or_ignore(from, sender, $~[:message].strip, time, @send_group_message)
		end
	end

	# @param [WebQQProtocol::QQEntity] from
	# @param [WebQQProtocol::QQEntity] sender
	# @param [String] command
	# @param [Time] time
	# @param [Method] call_back
	def response_or_ignore(from, sender, command, time, call_back)
		response = get_response(from, sender, command, time)
		call_back.call(from.uin, response) if response
	end

	# @param [WebQQProtocol::QQEntity] from
	# @param [WebQQProtocol::QQEntity] sender
	# @param [String] command
	# @param [Time] time
	def get_response(from, sender, command, time)
		# 桩方法，处理消息响应
	end

	protected

	def bot_name
		@qqbot.bot_name
	end
end

#noinspection ALL
class PluginNicknameResponderCombineFunctionBase < PluginNicknameResponderBase

	COMMAND_HEADER = ''

	# @return [String]
	def command_header
		self.class::COMMAND_HEADER
	end

	# @return [Regexp]
	def command_pattern
		@command_pattern ||= /^#{command_header}\s*(?<command>.+)/i
	end

	# @return [Array[Symbol]]
	def fuctions
		@fuctions ||= methods.select! {|method_name| /^function_/ =~ method_name}
	end

	def get_response(from, sender, command, time)
		if command_pattern =~ command
			command = $~[:command]
			response = nil
			fuctions.each do |function|
				response = send(function, from, sender, command, time)
				break if response
			end
			response
		end
	end
end