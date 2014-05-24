# -*- coding: utf-8 -*-

require 'yaml'

require_relative 'webqq/webqq'

#noinspection RubyClassVariableUsageInspection,RubyTooManyMethodsInspection
class PluginBase
	NAME = '插件基类'
	AUTHOR = 'BR'
	VERSION = '0.0'
	DESCRIPTION = '用于派生其他插件'
	MANUAL = <<MANUAL
MANUAL
	PRIORITY = 0

	PLUGIN_DIRECTORY = 'plugins'

	@@plugins = []
	@@instance_plugins = []

	def self.instance_plugins
		@@instance_plugins
	end

	def self.plugins
		@@plugins
	end

	# @param [WebQQProtocol::Client] client
	# @param [Logger] logger
	def initialize(qqbot, client, logger)
		@qqbot = qqbot
		@client = client
		@logger = logger
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
		YAML.load_file(config_file).each_pair { |key, value| instance_variable_set(:"@#{key}", value) } if File.exist? config_file

		data_file = "#{PLUGIN_DIRECTORY}/#{file_name}.data"
		@data = YAML.load_file(data_file) if File.exist? data_file

		log('载入完毕')
	end

	def on_unload
		log('卸载完毕')
		# 桩方法
	end

	def to_s
		"#{name}[#{author}<#{version}>]：#{description}"
	end

	protected

	attr_reader :qqbot, :client

	def log(message, level = Logger::INFO)
		@logger.log(level, message, self.class.name)
	end

	def self.file_path(file_name)
		File.expand_path "#{PLUGIN_DIRECTORY}/#{file_name}"
	end

	private

	STR_BASE = 'Base'

	# @param [Class] subclass
	def self.inherited(subclass)
		@@plugins.unshift subclass
		@@instance_plugins << subclass unless subclass.name.end_with? STR_BASE
	end
end

#noinspection RubyUnusedLocalVariable
class PluginResponderBase < PluginBase
	NAME = '消息回应插件基类'

	# @param [WebQQProtocol::QQFriend] sender
	# @param [String] message
	# @param [Time] time
	def on_message(sender, message, time)
		response = deal_message(sender, message, time)
		@client.send_buddy_message(sender, response) if response
	end

	# @param [WebQQProtocol::QQGroup] from
	# @param [WebQQProtocol::QQGroupMember] sender
	# @param [String] message
	# @param [Time] time
	def on_group_message(from, sender, message, time)
		response = deal_group_message(from, sender, message, time)
		@client.send_group_message(from, response) if response
	end

	# @param [WebQQProtocol::QQFriend] sender
	# @param [String] message
	# @param [Time] time
	def deal_message(sender, message, time)
		# 桩方法，好友消息响应
	end

	# @param [WebQQProtocol::QQGroup] from
	# @param [WebQQProtocol::QQGroupMember] sender
	# @param [String] message
	# @param [Time] time
	def deal_group_message(from, sender, message, time)
		# 桩方法，处理群消息响应
	end
end

class PluginNicknameResponderBase < PluginResponderBase
	NAME = '昵称呼叫型消息回应插件基类'

	def initialize(qqbot, client, logger)
		super
		@nick = @qqbot.nick
	end

	# @param [WebQQProtocol::QQFriend] sender
	# @param [String] message
	# @param [Time] time
	def deal_message(sender, message, time)
		get_response(sender, sender, message, time)
	end

	# @param [WebQQProtocol::QQGroup] from
	# @param [WebQQProtocol::QQGroupMember] sender
	# @param [String] message
	# @param [Time] time
	def deal_group_message(from, sender, message, time)
		if /^@?#{nick}\s*(?<message>.*)/ =~ message
			get_response(from, sender, $~[:message], time)
		end
	end

	# @param [WebQQProtocol::QQEntity] from
	# @param [WebQQProtocol::QQEntity] sender
	# @param [String] command
	# @param [Time] time
	def get_response(from, sender, command, time)
		# 桩方法，处理消息响应
	end

	protected
	attr_reader :nick
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
	def functions
		@fuctions ||= methods.select! { |method_name| /^function_/ =~ method_name }
	end

	def get_response(from, sender, command, time)
		if command_pattern =~ command
			command = $~[:command]
			response = nil
			functions.each do |function|
				response = send(function, from, sender, command, time)
				break if response
			end
			response
		end
	end
end