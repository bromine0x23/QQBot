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
			@message_receiver = @client.receiver
			@message_sender = @client.sender
			refresh_entities
			save_entities
			begin
				puts 'QQBot已成功登录！'
				loop do
					datas = @message_receiver.data
					datas.each do |data|
						log("data: #{data}", Logger::DEBUG) if $-d
						poll_type = data[KEY_POLL_TYPE]
						value     = data[KEY_VALUE]
						event     = :"on_#{poll_type}"
						from_uin  = value[KEY_FROM_UIN]

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

	def enable_plugin(uin, qq_number, plugin)
		if @forbidden.has_key? uin
			@forbidden[uin].delete(plugin.class.name)
		end
	end

	def disable_plugin(uin, qq_number, plugin)
		if @forbidden.has_key? uin
			@forbidden[uin] << plugin.class.name unless @forbidden[uin].include? plugin.class.name
		else
			@forbidden[uin] = [plugin.class.name]
		end
	end

	def plugin_forbidden?(uin, plugin)
		@forbidden.has_key? uin and @forbidden[uin].include? plugin.class.name
	end

	def master?(qq_number)
		@masters.include? qq_number
	end

	def friend(uin)
		@friends[uin]
	end

	def group(guin)
		@groups[guin]
	end

	def group_member(guin, uin)
		@groups[guin].member(uin)
	end

	def refresh_entities
		friends, groups = @client.friends, @client.groups
		@friends, @groups = {}, {}
		friends.each do |friend|
			@friends[friend.uin] = friend unless @friends[friend.uin]
		end
		groups.each do |group|
			@groups[group.uin] = group unless @groups[group.uin]
		end

		@entities = @friends.merge @groups

		true
	end

	# @return [WebQQClient::QQFriend]
	def add_friend(uin)
		new_friend = @client.add_friend(uin)
		@friends[new_friend.uin] = new_friend
	end


	# @return [WebQQClient::QQFriend]
	def delete_friend(uin)
		@friends.delete(uin)
	end

	private

	def log(message, level = Logger::INFO)
		@logger.log(level, message, self.class.name)
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
		@plugins = []
		PluginBase.plugins.each { |plugin_class|
			begin
				@plugins << plugin_class.new(self, @logger)
			rescue Exception => ex
				log("载入插件 #{plugin_class::NAME} 时发生异常：#{ex}", Logger::ERROR)
				log("调用栈：\n#{ex.backtrace.join("\n")}", Logger::ERROR)
			end
		}
		@plugins.sort_by { |plugin| -plugin.priority }
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

	def save_entities
		File.open('entities.txt', 'w') do |file|
			@entities.each do |uid, entity|
				if entity.is_a? WebQQClient::QQGroup
					file << <<ENTITY << <<MEMBERS
QQ群：#{entity.group_name}(#{entity.group_number}) => #{uid}
ENTITY
#{entity.members.map{|member| "#{member.nickname}(#{member.qq_number}) => #{member.uid}"}.join('\n') }
MEMBERS
				elsif entity.is_a? WebQQClient::QQFriend
					file << <<ENTITY
QQ用户：#{entity.nickname}(#{entity.qq_number}) => #{uid}
ENTITY
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