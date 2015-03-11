# -*- coding: utf-8 -*-

require 'digest'
require 'logger'
require 'yaml'
require 'singleton'

require_relative 'webqq_client'
require_relative 'plugin'

class QQBot
	include Singleton

	module Status
		NOT_INIT = 0
		DONE_INIT = 1
		ONLINE = 2
		OFFLINE = 3
		BUSY = 4
	end

	include Status

	attr_reader :status, :plugins, :logger

	def initialize
		@status = :not_init
		init
	end

	def init
		logout if @status == :online
		@logger = Logger.new("#{File.dirname(__FILE__)}/qqbot.log", 1)
		@logger.formatter = proc { |severity, datetime, prog_name, msg| "[#{datetime}][#{severity}][#{prog_name}] #{msg}\n" }
		@config = YAML.load_file("#{File.dirname(__FILE__)}/qqbot.yaml")
		@handler = nil
		@status = :done_init

		init_plugins
	end

	def login
		init if @status == :not_init
		@status = :do_login
		@client = WebQQClient.new(@config[:account], @config[:password], @config[:is_md5])
		@client.start
		@status = :online
		self
	rescue Exception
		@status = :offline
		log(ERROR, 'QQBot', '登陆失败', true)
		raise
	else
		log(INFO, 'QQBot', '登陆成功', true)
	end

	def logout
		return if @status == :offline
		@status = :do_logout
		@client.stop
		self
	ensure
		@status = :offline
		log(INFO, 'QQBot', '已登出', true)
	end

	def relink
		return unless @status == :online
		@status = :do_relink
		@client.relink
		@status = :online
		self
	rescue Exception
		@status = :offline
		log(ERROR, 'QQBot', '重连失败', true)
		raise
	else
		log(INFO, 'QQBot', '重连成功', true)
	end

	def start_handle
		@handler = Handler.new(self, method(:log)) unless @handler
		@client.set_handler(@handler)
	rescue
		log(ERROR, 'QQBot', 'Handler启动失败', true)
		raise
	else
		log(INFO, 'QQBot', 'Handler启动成功', true)
	end

	def stop_handle
		@client.unset_handler
		@handler = nil
	ensure
		log(INFO, 'QQBot', 'Handler已停止', true)
	end

	def log(severity, progname, message, echo = false)
		warn "[#{Time.now}][#{progname}] #{message}" if echo
		@logger.log(severity, message, progname)
	end

	def receive_message
		@client.receive_message
	end

	# 发送消息
	def send_message(to, message, font = {})
		@client.send_message(to, message, font.merge(@config[:font]))
	end

	def name
		@name ||= @client.user.name
	end

	def friends
		@client.friends
	end

	def groups
		@client.groups
	end

	def discusses
		@client.discusses
	end

	def administrator?(friend)
		@config[:administrators].include?(friend.number)
	end

	def manager?(group, friend)
		((@config[:manager] || {})[group.number] || {}).include?(friend.number)
	end

	# @param [Exception] exception
	def format_exception(exception)
		<<-EXCEPTION
Exception<#{exception.class}>: #{exception.message}
#{exception.backtrace.first(4).join("\n")}
		EXCEPTION
	end

	module PluginManager
		include Logger::Severity

		attr_reader :plugins

		def init_plugins
			@plugins = []
		end

		def load_plugins
			return unless @plugins.empty?
			read_plugins
			install_plugins
			sort_plugins
		rescue
			@plugins.clear
			log(ERROR, 'QQBot', '插件载入失败', true)
			raise
		else
			log(INFO, 'QQBot', "插件载入成功，共 #{@plugins.length} 个插件", true)
			@plugins.length
		end

		def unload_plugins
			uninstall_plugins
		rescue
			log(ERROR, 'QQBot', '插件卸载失败', true)
			raise
		else
			log(INFO, 'QQBot', '插件卸载成功', true)
		end

		def reload_plugins
			uninstall_plugins
			read_plugins
			install_plugins
			sort_plugins
		rescue
			@plugins.clear
			log(ERROR, 'QQBot', '插件重载失败', true)
			raise
		else
			log(INFO, 'QQBot', "插件重载成功，共 #{@plugins.length} 个插件", true)
			@plugins.length
		end

		# noinspection RubyUnusedLocalVariable
		def filtered_plugins(from)
			@plugins.select { |plugin| plugin.enable?(from) }
		end

		def find_plugin(from, key, filter = true)
			(filter ? filtered_plugins(from) : plugins).find{ |plugin| plugin.name == key }
		end

		private

		def read_plugins
			Dir.glob('plugin/*') { |file| read_plugin(file) if File.directory?(file) }
		end

		def read_plugin(directory)
			filename = "#{directory}/plugin.rb"
			@plugins << Plugin.new(filename).tap { |plugin| plugin.instance_eval(File.read(filename), filename) } if File.exist? filename
		rescue => exception
			log(ERROR, 'QQBot', "读入 #{file} 时发生异常：#{format_exception(exception)}")
		end

		def install_plugins
			@plugins.each { |plugin| install_plugin(plugin) }
		end

		def install_plugin(plugin)
			plugin.install(self)
			log(INFO, plugin.name, '载入成功')
		rescue => exception
			log(ERROR, plugin.name, "载入异常：#{format_exception(exception)}")
		end

		def uninstall_plugins
			@plugins.reverse_each { |plugin| uninstall_plugin(plugin) }.clear
		rescue
			install_plugins
		end

		def uninstall_plugin(plugin)
			plugin.uninstall
			log(INFO, plugin.name, '卸载成功')
		rescue => exception
			log(ERROR, plugin.name, "卸载异常：#{format_exception(exception)}")
			raise
		end

		def sort_plugins
			@plugins.sort_by! { |plugin| -plugin.priority }
		end
	end

	include PluginManager

	class Handler < Concurrent::ThreadPoolExecutor
		include Logger::Severity

		def initialize(qqbot, logger)
			super(max_threads: 2)
			@qqbot = qqbot
			@logger = logger
		end

		def call(*args)
			post(*args) do |data|
				data.each { |datum| dispatch(datum) }
			end
		rescue => exception
			@qqbot.log(INFO, self.class, "发生异常：#{@qqbot.format_exception(exception)}", true)
			raise
		end

		private

		# 提取消息中的文本
		# @return [String]
		def get_text(content)
			content.select{ |item| item.is_a? String }.join.strip
		end

		def dispatch(data)
			send(data['poll_type'], data['value'])
		rescue NoMethodError => ex
			log(UNKNOWN, self.class, <<-UNKNOWN)
Unknown Message Type： #{data}
#{@qqbot.format_exception(ex)}
			UNKNOWN
		end

		# noinspection RubyUnusedLocalVariable

		def message(value)
			sender  = @qqbot.friends[value['from_uin']]
			message = get_text(value['content'])
			time    = Time.at(value['time'])
			@qqbot.filtered_plugins(sender).each do |plugin|
				return if on_message(plugin, sender, message, time)
			end
		end

		def on_message(plugin, sender, message, time)
			plugin.on_message(sender, message, time)
		rescue => exception
			@qqbot.log(ERROR, plugin.name, "消息处理异常：#{@qqbot.format_exception(exception)}", true)
		end

		def group_message(value)
			from    = @qqbot.groups[value['from_uin']]
			sender  = from.by_uin(value['send_uin'])
			message = get_text(value['content'])
			time    = Time.at(value['time'])
			@qqbot.filtered_plugins(from).each do |plugin|
				break if on_group_message(plugin, from, sender, message, time)
			end
		end

		def on_group_message(plugin, from, sender, message, time)
			plugin.on_group_message(from, sender, message, time)
		rescue => exception
			@qqbot.log(ERROR, plugin.name, "消息处理异常：#{@qqbot.format_exception(exception)}", true)
		end

		def discu_message(value)
			from    = @qqbot.discusses[value['from_uin']]
			sender  = from.by_uin(value['send_uin'])
			message = get_text(value['content'])
			time    = Time.at(value['time'])
			@qqbot.filtered_plugins(from).each do |plugin|
				break if on_discuss_message(plugin, from, sender, message, time)
			end
		end

		def on_discuss_message(plugin, from, sender, message, time)
			plugin.on_discuss_message(from, sender, message, time)
		rescue => exception
			@qqbot.log(ERROR, plugin.name, "消息处理异常：#{@qqbot.format_exception(exception)}", true)
		end

		def group_web_message(_)
			# ignore
		end

		def buddies_status_change(_)
			# ignore
		end

		def input_notify(_)
			# ignore
		end
	end

end