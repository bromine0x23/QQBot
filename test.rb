#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require_relative 'qqbot'

$-d = true

class QQBot::PluginAdministrator

	alias on_event_qqbot on_event

	def on_event(data)
		puts data
		on_event_qqbot(data)
	end

end

class Tester < QQBot

	SELF_UIN = 31415926
	SELF_NUMBER = 57668573

	BUDDY_UIN = 12345678
	BUDDY_NUMBER = 12345678
	BUDDY_NAME = '测试者'

	GROUP_UIN = 122333
	GROUP_NUMBER = 1223334444
	GROUP_NAME = '测试群'

	def initialize
		load_config
		init_logger
		@plugin_adminsrator = PluginAdministrator.new(self, @logger)
	end

	def run
		load_plugins

		@message_count = 0

		friend = WebQQProtocol::QQEntity.new(BUDDY_UIN, BUDDY_NUMBER, BUDDY_NAME)
		group = WebQQProtocol::QQEntity.new(GROUP_UIN, GROUP_NUMBER, GROUP_NAME)

		group.instance_variable_set(:@members, friend)

		def group.member(uin)
			@members[uin]
		end

		@friends = {BUDDY_UIN => friend}
		@groups = {GROUP_UIN => group}

		@entities = @friends.merge @groups

		begin
			loop do
				datas = read_test_datas
				datas.each do |data|
					@plugin_adminsrator.on_event(data)
				end
			end
		rescue Exception => ex
			puts ex
			puts ex.backtrace
		ensure
			unload_plugins
		end
	end

	def send_message(uin, message, font = {})
		puts <<MEESAGE
to user：
#{message}
MEESAGE
	end

	def send_group_message(uin, message, font = {})
		puts <<MEESAGE
to group：
#{message}
MEESAGE
	end

	def read_test_datas
		print '>'
		message = gets.force_encoding('utf-8')

		@message_count += 1

		[
			{
				'poll_type' => 'message',
				'value' => {
					'msg_id' => @message_count,
					'from_uin' => BUDDY_UIN,
					'to_uin' => SELF_NUMBER,
					'send_uin' => BUDDY_UIN,
					'time' => Time.now.to_i,
					'content' => [
						[
							'font',
							{'size'=>10, 'color'=>'000000', 'style'=>[0, 0, 0], 'name'=>'微软雅黑'}
						],
						message
					]
				}
			}
		]
	end

	def plugins(_)
		@plugin_adminsrator.plugins
	end

	def forbidden?(plugin_name, uin)
		@plugin_adminsrator.forbidden?(plugin_name, entity.number)
	end

	def administrator?(uin, qq_number)
		@plugin_adminsrator.administrator?(entity.number, qq_number) or master?(qq_number)
	end

	def refresh_entities
		friends, groups = @client.friends, @client.groups
		@friends, @groups = {}, {}
		friends.each do |friend|
			@friends[friend.uin] = friend
		end
		groups.each do |group|
			@groups[group.uin] = group
		end

		@entities = @friends.merge @groups

		true
	end
end

qqbot = Tester.new

loop do
	restart = 0
	begin
		qqbot.run
	rescue Exception => ex
		puts ex
		puts ex.message
		puts ex.backtrace
	end
end