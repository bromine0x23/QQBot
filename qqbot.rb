#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require 'yaml'
require_relative 'webqq'
# require_relative 'plugins/plugin'

# $DEBUG = true

class QQBot
	CONFIG_FILE = 'config.yaml'
	KEY_POLL_TYPE = 'poll_type'
	KEY_VALUE = 'value'
	KEY_FROM_UIN = 'from_uin'

	attr_reader :bot_name
	attr_reader :plugins
	attr_reader :groups
	attr_reader :friends
	attr_reader :masters
	attr_reader :uin_map

	def initialize
		load_config
		init_logger
		load_plugins

		@client = WebQQClient.new(@qq, @password, @logger, self.method(:on_captcha_need))
	end

	def run
		begin
			log('开始运行……')
			@client.login
			@groups = @client.groups
			@friends = @client.friends
			@uin_map = {}
			@groups.each { |group| @uin_map[group.uin] = group }
			@friends.each { |friend| @uin_map[friend.uin] = friend }
			save_uins

			@message_receiver =@client.receiver
			@message_sender = @client.sender
			begin
				loop do
					datas = @message_receiver.data
					datas.each do |data|
						log("data: #{data}", Logger::DEBUG) if $-d
						poll_type, value = data[KEY_POLL_TYPE], data[KEY_VALUE]
						from_uin = value[KEY_FROM_UIN]
						event = :"on_#{poll_type}"
						@plugins.each do |plugin|
							next if plugin_forbidden?(from_uin, plugin)
							begin
								break if plugin.send(event, value)
							rescue Exception => ex
								log("执行插件 #{plugin.name} 时发生异常：#{ex}", Logger::ERROR)
								log("调用栈：\n#{ex.backtrace.join("\n")}", Logger::ERROR)
							end
						end
					end
				end
			rescue Exception => ex
				retry
			end
		ensure
			stop
		end
	end

	def test
		log('开始测试……')
		begin
			log('测试登录……')
			@client.login

			log('测试用户及群信息请求……')
			File.open('test_data.txt', 'w') do |file|
				file.puts @client.friends
				file.puts @client.groups
			end
		rescue Exception => ex
			log(ex)
			log("调用栈：\n#{ex.backtrace.join("\n")}")
		ensure
			log('测试登出……')
			@client.logout
		end
	end

	def stop
		@client.logout
		@groups, @friends, @uin_map = nil, nil, nil
		@message_receiver, @message_sender = nil, nil
		Thread.list.each do |thread|
			thread.terminate if thread != Thread.main
		end
	end

	def send_message(uin, message, font = {})
		@message_sender.send_message(uin, message.strip, @font_config.merge(font))
	end

	def send_group_message(uin, message, font = {})
		@message_sender.send_group_message(uin, message.strip, @font_config.merge(font))
	end

	def self.message(content)
		content.select{ |item| item.is_a? String }.join.strip
	end

	def enable_plugin(uin, plugin)
		if @forbidden.has_key? uin
			@forbidden[uin].delete(plugin.class.name)
		end
	end

	def disable_plugin(uin, plugin)
		if @forbidden.has_key? uin
			@forbidden[uin] << plugin.class.name unless @forbidden[uin].include? plugin.class.name
		else
			@forbidden[uin] = [plugin.class.name]
		end
	end

	def plugin_forbidden?(uin, plugin)
		@forbidden.has_key? uin and @forbidden[uin].include? plugin.class.name
	end

	def master?(qq)
		@masters.include? qq
	end

	def group_master?(group_number, qq_number)
	end


	def friend_nickname(uin)
		@uin_map[uin].name
	end

	def group_nickname(guin, uin)
		@uin_map[guin].group_nickname(uin)
	end

	def qq_number(uin)
		return @uin_map[uin].qq_number if @uin_map.has_key? uin
		@client.fetch_qq_number(uin)
	end

	private

	def log(message, level = Logger::INFO)
		@logger.log(level, message, self.class.name)
	end

	def debug(message)
		log(message, Logger::DEBUG) if $DEBUG
	end

	def load_config
		config = YAML.load_file(CONFIG_FILE)
		common_config = config['common']
		@log_file = common_config['log_file'] || 'qqbot.log'
		@captcha_file = common_config['captcha_file'] || 'captcha.jpg'
		@qq, @password = common_config['qq'], common_config['password']
		raise Exception.new('未设置QQ号或密码') if not @qq or not @password
		@bot_name = common_config['bot_name']
		@masters = common_config['masters']
		@font_config = config['font']
	end

	LOAD_PLUGINS_PATH = './plugins/plugin*.rb'

	def load_plugins
		log('载入插件……')
		Dir.glob(LOAD_PLUGINS_PATH) { |file_name| load file_name }
		@plugins = PluginBase.plugins
		.map { |plugin_class|
			begin
				plugin_class.new(self, @logger)
			rescue Exception => ex
				log("载入插件 #{plugin_class::NAME} 时发生异常：#{ex}", Logger::ERROR)
				log("调用栈：\n#{ex.backtrace.join("\n")}", Logger::ERROR)
			end
		}.sort! { |plugin1, plugin2| plugin2.priority <=> plugin1.priority }
		load_plugin_config
		log('插件载入完毕')
	end

	def reload_plugins
		log('重载插件')
		@plugins.each do |plugin| plugin.on_unload end
		Module.constants.select { |symbol| Object.send :remove_const, symbol if /^Plugin*/ =~ symbol }
		load_plugins
		log('插件重载完毕……')
	end

	def load_plugin_config
		# TODO this is 坑
		@forbidden = {}
	end

	def init_logger
		@logger = Logger.new(@log_file, File::WRONLY | File::APPEND | File::CREAT)
		@logger.formatter = proc do |severity, datetime, prog_name, msg|
			prog_name ? "[#{datetime}][#{severity}][#{prog_name}] #{msg}\n" : "[#{datetime}][#{severity}] #{msg}\n"
		end
		@logger
	end

	def save_uins
		File.open('uin_map.txt', 'w') do |file|
			@uin_map.each do |key, value|
				if value.is_a? WebQQClient::QQGroup
					file << <<LINE
#{key} : QQ群 #{value.group_name}(#{value.group_code})
LINE
				elsif value.is_a? WebQQClient::QQFriend
					file << <<LINE
#{key} : QQ用户 #{value.name}(#{value.qq_number})
LINE
				end
			end
		end
	end

	def on_captcha_need(image_data)
		File.open(@captcha_file, 'wb') do |file|
			file << image_data
		end
		puts "验证码已保存到 #{@captcha_file}, 请输入验证码："
		`start #{@captcha_file}`
		gets.strip.upcase
	end
end

# qqbot.test
qqbot = QQBot.new
#=begin
loop do
	restart = 0
	begin
		qqbot.run
	rescue Exception => ex
		puts ex
		puts ex.backtrace
		puts 'WebQQ已掉线，将在10秒后重启……'

		sleep(10)

		restart += 1
		if restart > 10
			puts '重启超过10次，退出'
			break
		end

		retry
	ensure
		qqbot.stop
	end
end
#=end
# qqbot.logout_clean