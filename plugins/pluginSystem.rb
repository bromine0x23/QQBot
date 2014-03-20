#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require_relative 'plugin'

class PluginSystem < PluginNicknameResponserBase
	NAME = '系统插件'
	AUTHOR = 'BR'
	VERSION = '1.11'
	DESCRIPTION = '管理QQBot'
	MANUAL = <<MANUAL.strip
==> 系统插件 <==
== 列出管理员 ==
权限狗列表
== 列出已启用插件 ==
插件列表
== 列出插件优先级 ==
插件优先级
== 显示插件帮助 ==
插件帮助 <插件>
MANUAL
=begin
== [插件管理员]启用插件 ==
开启插件 <插件>
== [插件管理员]关闭插件 ==
关闭插件 <插件>
== [系统管理员]启动垃圾回收 ==
垃圾回收
== [系统管理员]重载插件 ==
重载插件
== [系统管理员]重载配置 ==
重载配置
== [系统管理员]重载插件规则 ==
重载插件规则
MANUAL
=end
	PRIORITY = 8

	COMMAND_LIST_MASTERS         = '权限狗列表'
	COMMAND_LIST_PLUGINS         = '插件列表'
	COMMAND_LIST_PLUGIN_PRIORITY = '插件优先级'
	COMMAND_ENABLE_PLUGIN        = '启用插件'
	COMMAND_DISABLE_PLUGIN       = '停用插件'
	COMMAND_RELOAD_CONFIG        = '重载配置'
	COMMAND_RELOAD_PLUGINS       = '重载插件'
	COMMAND_START_GC             = '垃圾回收'
	COMMAND_START_DEBUG          = '开始调试'
	COMMAND_END_DEBUG            = '结束调试'
	COMMAND_HELP                 = '插件帮助'

	COMMAND_PATTERN = /(?<command>#{COMMAND_HELP}|#{COMMAND_ENABLE_PLUGIN}|#{COMMAND_DISABLE_PLUGIN})\s*(?<plugin_name>.+)/

	NO_PERMISSION_RELOAD_CONFIG  = '重载配置：权限不足'
	NO_PERMISSION_RELOAD_PLUGINS = '重载插件：权限不足'
	NO_PERMISSION_START_GC       = '垃圾回收：权限不足'
	NO_PERMISSION_START_DEBUG    = '开始调试：权限不足'
	NO_PERMISSION_END_DEBUG      = '结束调试：权限不足'
	NO_PERMISSION_ENABLE_PLUGIN  = '启用插件：权限不足'
	NO_PERMISSION_DISABLE_PLUGIN = '停用插件：权限不足'

	RESPONSE_CONFIG_RELOADED  = '配置已重载'
	RESPONSE_PLUGINS_RELOADED = '插件已重载，共 %d 个插件'
	RESPONSE_GC_FINISHED      = '垃圾回收运行完毕，已执行 %d 次'
	RESPONSE_DEBUG_STARTED    = '调试开始'
	RESPONSE_DEBUG_ENDED      = '调试结束'
	RESPONSE_PLUGIN_ENABLED   = '%s 已启用'
	RESPONSE_PLUGIN_DISABLED  = '%s 已停用'
	RESPONSE_UNKNOWN_PLUGIN   = '未知插件 %s'
	RESPONSE_PLUGIN_HELP      = <<RESPONSE
==> %s 帮助 <==
%s
RESPONSE

	STRING_EMPTY = '空'

	MASTERS = 'BR'

	def get_response(uin, sender_qq, sender_nickname, message, time)
		# super # FOR DEBUG

		case message
		when COMMAND_LIST_MASTERS
			MASTERS
		when COMMAND_LIST_PLUGINS
			header = '已启用插件：'
			body = ''
			@qqbot.plugins.each do |plugin|
				unless @qqbot.plugin_forbidden? uin, plugin
					body  << <<RESPONSE
#{plugin.name}[#{plugin.author}<#{plugin.version}>]：#{plugin.description}
RESPONSE
				end
			end
			header << (body.empty? ? STRING_EMPTY : body)
		when COMMAND_LIST_PLUGIN_PRIORITY
			response = ''
			@qqbot.plugins.each do |plugin|
				unless @qqbot.plugin_forbidden? uin, plugin
					response << "#{plugin.name} => #{plugin.priority}\n"
				end
			end
			response
		when COMMAND_RELOAD_CONFIG
			if @qqbot.master? sender_qq
				@qqbot.send :load_config
				RESPONSE_CONFIG_RELOADED
			else
				NO_PERMISSION_RELOAD_CONFIG
			end
		when COMMAND_RELOAD_PLUGINS
			if @qqbot.master? sender_qq
				@qqbot.send :reload_plugins
				# RESPONSE_GC_FINISHED % @qqbot.plugins.size
				"插件已重载，共 #{@qqbot.plugins.size} 个插件"
			else
				NO_PERMISSION_RELOAD_PLUGINS
			end
		when COMMAND_START_GC
			if @qqbot.master? sender_qq
				GC.start
				# RESPONSE_GC_FINISHED % GC.count
				"垃圾回收运行完毕，已执行 #{GC.count} 次"
			else
				NO_PERMISSION_START_GC
			end
		when COMMAND_START_DEBUG
			if @qqbot.master? sender_qq
				$-d = true
				RESPONSE_DEBUG_STARTED
			else
				NO_PERMISSION_START_DEBUG
			end
		when COMMAND_END_DEBUG
			if @qqbot.master? sender_qq
				$-d = false
				RESPONSE_DEBUG_ENDED
			else
				NO_PERMISSION_END_DEBUG
			end
		else
			if COMMAND_PATTERN =~ message
				plugin_name = $~[:plugin_name]
				plugin = @qqbot.plugins.find{ |plugin| plugin.name == plugin_name }
				if plugin
					case $~[:command]
					when COMMAND_HELP
						# RESPONSE_PLUGIN_HELP % [plugin_name, plugin.manual]
						<<RESPONSE
==> #{plugin_name} 帮助 <==
#{plugin.manual}
RESPONSE
					when COMMAND_ENABLE_PLUGIN
						if @qqbot.master? sender_qq
							@qqbot.enable_plugin uin, sender_qq, plugin
							# RESPONSE_PLUGIN_ENABLED % plugin_name
							"#{plugin_name} 已启用"
						else
							NO_PERMISSION_ENABLE_PLUGIN
						end
					when COMMAND_DISABLE_PLUGIN
						if @qqbot.master? sender_qq
							@qqbot.disable_plugin uin, sender_qq, plugin
							# RESPONSE_PLUGIN_DISABLED % plugin_name
							"#{plugin_name} 已停用"
						else
							NO_PERMISSION_DISABLE_PLUGIN
						end
					else
					end
				else
					# RESPONSE_UNKNOWN_PLUGIN % plugin_name
					"未知插件 #{plugin_name}"
				end
			end
		end
	end
end