# -*- coding: utf-8 -*-

require 'logger'
require 'net/http'

require_relative 'config'
require_relative 'net_client'

module WebQQProtocol

	class Client

		# 消息发送线程
		class Sender
			REDO_LIMIT = 5

			attr_reader :thread

			# 创建发送线程
			#noinspection RubyScope
			# @param [WebQQProtocol::Net] net
			# @param [Logger] logger
			def initialize(clientid, psessionid, net, logger)
				@logger = logger
				@messages= Queue.new
				@thread = Thread.new(
					clientid,
					psessionid,
					net
				) do |clientid, psessionid, net|
					log('线程启动……', Logger::INFO)

					redo_count = 0

					request_buddy = Net::HTTP::Post.new(URI('http://d.web2.qq.com/channel/send_qun_msg2'), net.header)
					request_qun = Net::HTTP::Post.new(URI('http://d.web2.qq.com/channel/send_qun_msg2'), net.header)
					request_discuss = Net::HTTP::Post.new(URI('http://d.web2.qq.com/channel/send_discu_msg2'), net.header)

					message_counter = Random.rand(1000...10000) * 10000

					data = {
						to: nil,
						group_uin: nil,
						did: nil,
						content: nil,
						face: 555,
						msg_id: nil,
						clientid: clientid,
						psessionid: psessionid
					}
					begin
						loop do
							message = @messages.pop
							begin
								case message[:type]
								when :buddy_message
									data[:to] = message[:uin]
									request = request_buddy
								when :group_message
									data[:group_uin] = message[:uin]
									request = request_qun
								when :discuss_message
									data[:did] = message[:uin]
									request = request_discuss
								else
									next
								end

								message_counter += 1

								data[:content] = encode_content(message[:message], message[:font])
								data[:msg_id] = message_counter

								request.set_form_data(r: JSON.fast_generate(data))

								NetClient.json_result(net.send(request).body)
							rescue EOFError
								log('网络异常，无法发送消息，重试……', Logger::ERROR)
								retry
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
					message: message,
					font: font
				)
				self
			end

			# 发送群消息
			def send_group_message(uin, message, font)
				@messages.push(
					type: :group_message,
					uin: uin,
					message: message,
					font: font
				)
				self
			end

			# 发送消息
			def send_discuss_message(uin, message, font)
				@messages.push(
					type: :discuss_message,
					uin: uin,
					message: message,
					font: font
				)
				self
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