# -*- coding: utf-8 -*-

require 'logger'
require 'net/http'

require_relative 'config'
require_relative 'net_client'

module WebQQProtocol

	class Client

		# 消息发送线程
		class Sender
			REDO_LIMIT = 10

			attr_reader :thread

			# 创建发送线程
			#noinspection RubyScope
			# @param [WebQQProtocol::Net] net
			# @param [Logger] logger
			def initialize(clientid, psessionid, net, logger)
				@logger = logger
				@messages= Queue.new
				@thread = Thread.new(clientid, psessionid, net) do |clientid, psessionid, net|
					log('线程启动……', Logger::INFO)

					redo_count = 0

					message_counter = Random.rand(1000...10000) * 10000

					begin
						uri_buddy_message = URI('http://d.web2.qq.com/channel/send_buddy_msg2')
						uri_group_message = URI('http://d.web2.qq.com/channel/send_qun_msg2')
						uri_discuss_message = URI('http://d.web2.qq.com/channel/send_discu_msg2')
					
						loop do
							message = @messages.pop
							message_counter += 1

							header = net.header
							header['origin'] = 'd.web2.qq.com'
							header['referer'] = 'http://d.web2.qq.com/proxy.html?v=20130916001&callback=1&id=2'
							
							data = {
								content: message[:content],
								msg_id: message_counter,
								face: 555,
								clientid: clientid,
								psessionid: psessionid,
							}

							case message[:type]
							when :buddy_message
								data[:to] = message[:uin]
								request = Net::HTTP::Post.new(uri_buddy_message, header)
							when :group_message
								data[:group_uin] = message[:uin]
								request = Net::HTTP::Post.new(uri_group_message, header)
							when :discuss_message
								data[:did] = message[:uin]
								request = Net::HTTP::Post.new(uri_discuss_message, header)
							else
								next
							end

							request.set_form_data(r: JSON.fast_generate(data))
							
							retried = false
							begin
								NetClient.json_result(net.send(request).body)
							rescue EOFError
								log('网络异常，无法发送消息，重试……', Logger::ERROR)
								unless retried
									retried = true
									retry
								end
							end
							
							
						end
					rescue Exception => ex
						log(<<LOG.strip, Logger::ERROR)
发生异常：[#{ex.class}] #{ex.message}，于
#{ex.backtrace.join("\n")}
LOG
						redo_count += 1
						if redo_count > REDO_LIMIT
							log("重试超过#{REDO_LIMIT}次，退出", Logger::FATAL)
							raise
						end
						log('重试', Logger::ERROR)
						retry
					end
				end
			end

			# 发送好友消息
			def send_buddy_message(uin, message, font)
				@messages.push(
					type: :buddy_message,
					uin: uin,
					content: encode_content(message, font)
				)
			end

			# 发送群消息
			def send_group_message(uin, message, font)
				@messages.push(
					type: :group_message,
					uin: uin,
					content: encode_content(message, font)
				)
			end

			# 发送消息
			def send_discuss_message(uin, message, font)
				@messages.push(
					type: :discuss_message,
					uin: uin,
					content: encode_content(message, font)
				)
			end

			# 编码内容数据
			def encode_content(message, font)
				JSON.fast_generate(
					[
						message,
						[
							'font',
							{
								name: font[:name] || '宋体',
								size: font[:size] || 10,
								style: [
									font[:bold] ? 1 : 0,
									font[:italic] ? 1 : 0,
									font[:underline] ? 1 : 0
								],
								color: font[:color] || '000000'
							}
						]
					]
				)
			end

			def alive?
				@thread.alive?
			end

			def log(message, level = Logger::INFO)
				@logger.log(level, message, self.class.name)
			end
		end
	end
end