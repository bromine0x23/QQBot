#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require_relative 'qqbot'

# $-d = true

qqbot = QQBot.new

loop do
	restart = 0
	begin
		qqbot.run
	rescue Exception => ex
		puts ex
		puts ex.message
		puts ex.backtrace
		puts 'WebQQ已掉线，将在10秒后重启……'

		sleep(10)

		restart += 1
		if restart > 10
			puts '重启超过10次，退出'
			break
		end

		retry
	end
end