# -*- coding: utf-8 -*-

require 'English'
require 'yajl'

class Plugin
	attr_reader :directory

	def initialize(path)
		@directory = File.dirname(path)
	end

	def file_path(file_name)
		File.join(directory, file_name)
	end

	# @param [QQBot] qqbot
	def install(qqbot)
		on_install(qqbot)
		self
	end

	def uninstall
		on_uninstall
		self
	end

	protected

	attr_reader :qqbot

	private

	module Config
		def name
			config[:name] || '无名插件'
		end

		def description
			config[:description] || 'QQBot插件'
		end

		def manual
			config[:manual] || ''
		end

		def priority
			config[:priority] || 0
		end

		def to_s
			'%<name>s：%<description>s' % {name: name, description: description}
		end

		def inspect
			"Plugin<#{name}>"
		end

		private

		def config
			@config ||= File.exist?(file_path('plugin.yaml')) ? YAML.load_file(file_path('plugin.yaml')) : {}
		end
	end

	module Filter
		def enable(group)
			filter[group.number] = true
			save_filter
		end

		def disable(group)
			filter[group.number] = false
			save_filter
		end

		def enable?(from)
			if from.group?
				filter.fetch(from.number){config[:enable]}
			else
				config[:enable]
			end
		end

		private

		def filter
			@filter ||= File.exist?(file_path('plugin.filter')) ? YAML.load_file(file_path('plugin.filter')) : {}
		end

		def save_filter
			File.write(file_path('plugin.filter'), YAML.dump(filter))
		end
	end

	module EventHandle
		def on_install(qqbot)
			@qqbot = qqbot
			install_hooks.each(&:call)
		end

		def on_uninstall
			uninstall_hooks.each(&:call)
		end

		# @param [WebQQClient::Friend] sender
		# @param [String] message
		# @param [Time] time
		def on_message(sender, message, time)
			response = deal_message(sender, message, time)
			send_message(sender, response) if response
		end

		# @param [WebQQClient::Group] from
		# @param [WebQQClient::Friend] sender
		# @param [String] message
		# @param [Time] time
		def on_group_message(from, sender, message, time)
			response = deal_group_message(from, sender, message, time)
			send_message(from, response) if response
		end

		# @param [WebQQClient::Discuss] from
		# @param [WebQQClient::Friend] sender
		# @param [String] message
		# @param [Time] time
		def on_discuss_message(from, sender, message, time)
			response = deal_discuss_message(from, sender, message, time)
			send_message(from, response) if response
		end

		private

		def send_message(to, message)
			qqbot.send_message(to, message)
		end

		def install_hooks
			@install_hooks ||= []
		end

		def uninstall_hooks
			@uninstall_hooks ||= []
		end

		def functions
			@functions ||= []
		end

		def pattern_without_name
			@pattern_without_name ||= /\A#{config[:prefix]}\s*(?<command>.*)\Z/mi
		end

		def pattern_with_name
			@pattern_with_name ||= /\A@?#{qqbot.name}\s*#{config[:prefix]}\s*(?<command>.*)\Z/mi
		end

		def deal_message(sender, message, time)
			get_response(sender, sender, $LAST_MATCH_INFO[:command].strip, time) if pattern_without_name =~ message
		end

		def deal_group_message(from, sender, message, time)
			get_response(from, sender, $LAST_MATCH_INFO[:command].strip, time) if pattern_with_name =~ message
		end

		def deal_discuss_message(from, sender, message, time)
			get_response(from, sender, $LAST_MATCH_INFO[:command].strip, time) if pattern_with_name =~ message
		end

		def get_response(from, sender, command, time)
			functions.each do |function|
				response = function.call(from, sender, command, time)
				return response if response
			end
			nil
		end
	end

	module Utility
		def pseudo_random(seed, index = 11, mod = 11117)
			index.times.reduce(seed) { |x, _i| x * x % mod }
		end

		def date_seed(date, year_rank = 10000, month_rank = 100, day_rank = 1)
			date.year * year_rank + date.month * month_rank + date.day * day_rank
		end

		private

		def local
			@local ||= {}
		end
	end

	include Config, Filter, EventHandle, Utility
end