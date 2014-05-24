# -*- coding: utf-8 -*-

require_relative 'webqq/webqq'
require_relative 'plugin_manager'

require 'yaml'

#noinspection RubyTooManyMethodsInspection
class QQBot
	FILE_CONFIG = 'config.yaml'

	attr_reader :nick
	attr_reader :masters
	attr_reader :plugin_manager

	def initialize
		load_config

		init_logger
	end

	def load_config
		@config = YAML.load_file(FILE_CONFIG)
		@nick = @config[:common][:name]
		@masters = @config[:common][:masters]
		@font_config = @config[:font]
	end

	def init_logger
		@logger = Logger.new(@config[:common][:log_file] || 'qqbot.log', File::WRONLY | File::APPEND | File::CREAT)
		@logger.formatter = proc do |severity, datetime, prog_name, msg|
			prog_name ? "[#{datetime}][#{severity}][#{prog_name}] #{msg}\n" : "[#{datetime}][#{severity}] #{msg}\n"
		end
	end

	def init_client
		begin
			raise Exception.new('未设置QQ号或密码') unless @config[:common][:qq] and @config[:common][:password]
			@client = WebQQProtocol::Client.new(@config[:common][:qq], @config[:common][:password], @logger, self.method(:on_captcha_need))
		rescue WebQQProtocol::LoginFailed
			puts '登录失败'
			raise
		end
		puts '登录成功！'

		@plugin_manager = PluginManager.new(self, @client, @logger)
	end

	def run
		init_client

		load_plugins
	
		log('开始运行……')

		begin
			loop do
				raise 'offline' unless @client.online?
				datas = @client.poll_data
				log("data => #{datas}") if $-d
				datas.each do |data|
					@plugin_manager.on_event(data)
				end
			end
		rescue Exception => ex
			log(<<LOG.strip, Logger::ERROR)
发生异常：[#{ex.class}] #{ex.message}，于
#{ex.backtrace.join("\n")}
LOG
			raise
		ensure
			stop
		end
	end

	def stop
		@client.stop
		unload_plugins
	end

	def send_message(from, message, font = {})
		@client.send_message(from.uin, message.strip, @font_config.merge(font))
	end

	def send_group_message(from, message, font = {})
		@client.send_group_message(from.uin, message.strip, @font_config.merge(font))
	end

	def send_discuss_message(from, message, font = {})
		@client.send_discuss_message(from.uin, message.strip, @font_config.merge(font))
	end

	# @return [String]
	def self.message(content)
		content.select { |item| item.is_a? String }.join.force_encoding('utf-8').strip
	end

	# @return [PluginBase]
	def plugin(plugin_name)
		@plugin_manager.plugin(plugin_name)
	end

	# @param [WebQQProtocol::Entity] from
	def plugins(from)
		from.is_a?(WebQQProtocol::Group) ? @plugin_manager.filtered_plugins(from) : @plugin_manager.plugins
	end

	def load_plugins
		@plugin_manager.load_plugins
	end

	def unload_plugins
		@plugin_manager.unload_plugins
	end

	def reload_plugins
		@plugin_manager.reload_plugins
	end

	# @param [WebQQProtocol::Entity] from
	# @param [WebQQProtocol::Entity] sender
	# @param [PluginBase] plugin
	def enable_plugin(from, sender, plugin)
		@plugin_manager.enable_plugin(from, sender, plugin) if from.is_a? WebQQProtocol::Group
	end

	# @param [WebQQProtocol::Entity] from
	# @param [WebQQProtocol::Entity] sender
	# @param [PluginBase] plugin
	def disable_plugin(from, sender, plugin)
		@plugin_manager.disable_plugin(from, sender, plugin) if from.is_a? WebQQProtocol::Group
	end

	# @param [WebQQProtocol::Group] group
	# @param [WebQQProtocol::GroupMember] member
	def group_manager?(group, member)
		@masters.group_manager?(group, member) if group.is_a? WebQQProtocol::Group
	end

	# @param [WebQQProtocol::QQEntity] sender
	def master?(sender)
		@masters.include? sender.number
	end

	private

	def log(message, level = Logger::INFO)
		@logger.log(level, message, self.class.name)
	end

	def on_captcha_need(image_data)
		captcha_file = @config[:common][:captcha_file] || 'captcha.jpg'
		File.open(captcha_file, 'wb') do |file|
			file << image_data
		end
		puts "验证码已保存到 #{captcha_file}, 请输入验证码："
		gets.strip.upcase
	end
end