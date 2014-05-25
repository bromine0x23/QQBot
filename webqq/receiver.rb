# -*- coding: utf-8 -*-

require 'logger'
require 'net/http'

require_relative 'config'
require_relative 'net_client'
require_relative 'exception'

module WebQQProtocol

	class Client

		# 消息接收线程
		class Receiver
			REDO_LIMIT = 10

			attr_reader :thread

			# 创建接收线程
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

					begin
						loop do
							begin
								request = Net::HTTP::Post.new(
									URI('http://d.web2.qq.com/channel/poll2'),
									net.header
								)
								request.set_form_data(
									r: JSON.fast_generate(
										ptwebqq: net.cookies['ptwebqq'],
										clientid: clientid,
										psessionid: psessionid,
										key: ''
									)
								)

								response = net.send(request, 120)

								begin
									@messages.push(NetClient.json_result(response.body))
								rescue JSON::ParserError => ex
									next
								end
							rescue ErrorCode => ex
								case ex.retcode
								when 102
									next
								when 116
									# 重设 ptwebqq
									net.cookies['ptwebqq'] = ex.data['p']
									next
								when 100
									# NotReLogin
									raise 'NotLogin'
								when 120, 121
									log('ReLinkFailure', Logger::ERROR)
									raise
								when 109, 110
									next
								else
									log("poll时遭遇未知代码：#{ex.retcode}", Logger::FATAL)
									raise
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
						log("第 #{redo_count} 次重试", Logger::ERROR)
						retry
					end
				end
			end

			# 读取数据
=begin
可能的消息类型
sess_message
message
group_message
discu_message
kick_message
filesrv_transfer
file_message
push_offfile
notify_offfile
=end
			def data
				@messages.pop
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