#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require_relative 'plugin'

class PluginCore < PluginNicknameResponserBase
	NAME = '核心插件'
	AUTHOR = 'BR'
	VERSION = '1.12'
	DESCRIPTION = 'QQBot核心'
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
	PRIORITY = 8

	DB_FILE = File.expand_path(File.dirname(__FILE__) + '/pluginCore.db')

	TABLE_MESSAGES = 'messages'

	TYPEID_MESSAGE       = 0
	TYPEID_GROUP_MESSAGE = 1

	SQL_CREATE_TABLE_MESSAGES = <<SQL
CREATE TABLE messages (
	id           INTEGER PRIMARY KEY AUTOINCREMENT,
	message_type INTEGER,
	from_number  INTEGER,
	from_name    TEXT,
	send_number  INTEGER,
	send_name    TEXT,
	message      TEXT,
	created_at   TIMESTAMP
)
SQL

	SQL_CHECK_TABLE = <<SQL
SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name = ?
SQL

	SQL_INSERT_MESSAGE = <<SQL
INSERT INTO messages (
	message_type,
	from_number,
	from_name,
	send_number,
	send_name,
	message,
	created_at
) VALUES (?, ?, ?, ?, ?, ?, ?)
SQL

	def on_load
		# super # FOR DEBUG
		log('连接数据库……')
		@db = SQLite3::Database.open DB_FILE
		@db.execute SQL_CREATE_TABLE_MESSAGES if @db.get_first_value(SQL_CHECK_TABLE, TABLE_MESSAGES).zero?
		log('数据库连接完毕')
	end

	def on_unload
		# super # FOR DEBUG
		log('断开数据库连接')
		@db.close
	end

	def deal_message(uin, sender_qq, sender_nickname, content, time)
		@db.transaction do |db|
			db.execute SQL_INSERT_MESSAGE, TYPEID_MESSAGE, sender_qq, sender_nickname, sender_qq, sender_nickname, QQBot.message(content), time
		end
		super
	end

	def deal_group_message(guin, sender_qq, sender_nickname, content, time)
		group = @qqbot.group guin
		@db.transaction do |db|
			db.execute SQL_INSERT_MESSAGE, TYPEID_GROUP_MESSAGE, group.group_number, group.group_name, sender_qq, sender_nickname, QQBot.message(content), time
		end
		super
	end

	JSON_KEY_TYPE    = 'type'
	JSON_KEY_ACCOUNT = 'account'
	STRING_VERIFY_REQUIRED = 'verify_required'

	def on_system_message(value)
		# super # FOR DEBUG
		if value[JSON_KEY_TYPE] == STRING_VERIFY_REQUIRED
			new_friend = @qqbot.add_friend value[JSON_KEY_ACCOUNT]
			log("和#{new_friend.nickname}（#{new_friend.qq_number}）成为了好友")
			true
		end
	end

	STATUS_ONLINE  = 'online'
	STATUS_OFFLINE = 'offline'
	STATUS_AWAY    = 'away'
	STATUS_SILENT  = 'silent'

	JSON_KEY_UIN    = 'uin'
	JSON_KEY_STATUS = 'status'

	def on_buddies_status_change(value)
		super # FOR DEBUG
		uin = value[JSON_KEY_UIN]
		status = value[JSON_KEY_STATUS]
		friend = @qqbot.friend(uin)
		case status
		when STATUS_ONLINE
			log("#{friend.nickname}(#{friend.qq_number}) 上线了")
			# @send_message.call(uin, '正面上我！')
		when STATUS_OFFLINE
			log("#{friend.nickname}(#{friend.qq_number}) 下线了")
			# @send_message.call(uin, '正面上我！')
		when STATUS_AWAY
			log("#{friend.nickname}(#{friend.qq_number}) 暂时离开")
		when STATUS_SILENT
			log("#{friend.nickname}(#{friend.qq_number}) 开始工作")
		else
			log("未处理的状态 #{status}")
		end
		true
	end

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
			header = "已启用插件：\n"
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