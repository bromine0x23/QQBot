# -*- coding: utf-8 -*-

require 'sqlite3'

class PluginCore < PluginNicknameResponderCombineFunctionBase
	NAME = '核心插件'
	AUTHOR = 'BR'
	VERSION = '1.15'
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

	def on_load
		super
		load_filter_list
		prepare_db
	end

	def on_unload
		super
		save_filter_list
		close_db
	end

	FILTER_FILE = "#{PLUGIN_DIRECTORY}/pluginCore.filter"

	def load_filter_list
		@filter = YAML.load_file(FILTER_FILE)
	end

	def save_filter_list
		File.open(FILTER_FILE, 'w') do |file|
			file << YAML.dump(@filter)
		end
	end

	DB_FILE = "#{PLUGIN_DIRECTORY}/pluginCore.db"

	SQL_CREATE_TABLE_MESSAGES = <<SQL
CREATE TABLE IF NOT EXISTS messages (
	id            INTEGER PRIMARY KEY AUTOINCREMENT,
	sender_number INTEGER,
	sender_name   TEXT,
	message       TEXT,
	created_at    TIMESTAMP
)
SQL

	#noinspection RubyConstantNamingConvention
	SQL_CREATE_TABLE_GROUP_MESSAGES = <<SQL
CREATE TABLE IF NOT EXISTS group_messages (
	id            INTEGER PRIMARY KEY AUTOINCREMENT,
	from_number   INTEGER,
	from_name     TEXT,
	sender_number INTEGER,
	sender_name   TEXT,
	message       TEXT,
	created_at    TIMESTAMP
)
SQL

	SQL_INSERT_MESSAGE = <<SQL
INSERT
INTO messages (sender_number, sender_name, message, created_at)
VALUES (?, ?, ?, ?)
SQL

	SQL_INSERT_GROUP_MESSAGE = <<SQL
INSERT
INTO group_messages (from_number, from_name, sender_number, sender_name, message, created_at)
VALUES (?, ?, ?, ?, ?, ?)
SQL

	def prepare_db
		@db = SQLite3::Database.open DB_FILE
		@db.execute SQL_CREATE_TABLE_MESSAGES
		@db.execute SQL_CREATE_TABLE_GROUP_MESSAGES
	end

	def close_db
		@db.close
	end

	def on_message(sender, content, time)
		@db.transaction do |db|
			db.execute(SQL_INSERT_MESSAGE, sender.number, sender.name, QQBot.message(content), time.to_i)
		end
		return true if @filter.include? sender.number
		super
	end

	def on_group_message(from, sender, content, time)
		@db.transaction do |db|
			db.execute(SQL_INSERT_GROUP_MESSAGE, from.number, from.name, sender.number, sender.name, QQBot.message(content), time.to_i)
		end
		return true if @filter.include? sender.number
		super
	end

	JSON_KEY_TYPE    = 'type'
	JSON_KEY_ACCOUNT = 'account'
	STRING_VERIFY_REQUIRED = 'verify_required'

	def on_system_message(value)
		super
		if value[JSON_KEY_TYPE] == STRING_VERIFY_REQUIRED
			friend = qqbot.add_friend(value[JSON_KEY_ACCOUNT])
			log("和#{friend.name}（#{friend.number}）成为了好友")
			true
		end
	end

	COMMAND_LIST_PLUGINS    = '插件列表'
	COMMAND_LIST_PRIORITIES = '插件优先级'
	COMMAND_RELOAD_CONFIG   = '重载配置'
	COMMAND_RELOAD_PLUGINS  = '重载插件'
	COMMAND_START_GC        = '垃圾回收'
	COMMAND_OBJECT_CHECK    = '检视对象'
	COMMAND_START_DEBUG     = '开始调试'
	COMMAND_STOP_DEBUG      = '结束调试'
	COMMAND_END_DEBUG       = '结束调试'
	COMMAND_FILTER_LIST     = '屏蔽列表'
	COMMAND_FILTER_ADD      = /^屏蔽\s*(?<number>\d+)/
	COMMAND_FILTER_REMOVE   = /^(停止|取消)屏蔽\s*(?<number>\d+)/
	COMMAND_PLUGIN_MANUAL   = /^插件帮助\s*(?<plugin_name>.+)/
	COMMAND_PLUGIN_ENABLE   = /^启用插件\s*(?<plugin_name>.+)/
	COMMAND_PLUGIN_DISABLE  = /^停用插件\s*(?<plugin_name>.+)/

	def function_list_plugins(from, _, command, _)
		if COMMAND_LIST_PLUGINS == command
			header = "已启用插件：\n"
			body = qqbot.plugins(from).map { |plugin| "#{plugin.name}[#{plugin.author}<#{plugin.version}>]：#{plugin.description}" }.join("\n")
			#noinspection RubyResolve
			header << (body.empty? ? @responses[:plugin_list_empty] : body)
		end
	end

	def function_list_priorities(from, _, command, _)
		if COMMAND_LIST_PRIORITIES == command
			qqbot.plugins(from).map { |plugin| "#{plugin.name} => #{plugin.priority}" }.join("\n")
		end
	end

	def function_reload_config(_, sender, command, _)
		if COMMAND_RELOAD_CONFIG == command
			if qqbot.master?(sender)
				qqbot.load_config
				#noinspection RubyResolve
				@responses[:config_reloaded]
			else
				#noinspection RubyResolve
				@responses[:no_permission] % {command: command}
			end
		end
	end

	def function_reload_plugins(_, sender, command, _)
		if COMMAND_RELOAD_PLUGINS == command
			if qqbot.master?(sender)
				plugin_count = qqbot.reload_plugins
				#noinspection RubyResolve
				if plugin_count > 0
					@responses[:plugins_reloaded] % {plugin_count: plugin_count}
				else
					@responses[:plugins_reloaded_failed]
				end
			else
				#noinspection RubyResolve
				@responses[:no_permission] % {command: command}
			end
		end
	end

	def function_start_gc(_, sender, command, _)
		if COMMAND_START_GC == command
			if qqbot.master?(sender)
				GC.start
				#noinspection RubyResolve
				@responses[:gc_finished] % {gc_count: GC.count}
			else
				#noinspection RubyResolve
				@responses[:no_permission] % {command: command}
			end
		end
	end

	def function_object_check(_, sender, command, _)
		if COMMAND_OBJECT_CHECK == command
			if qqbot.master?(sender)
				result = ObjectSpace.count_objects
				<<RESPONSE
Ｔｏｔａｌ：　　#{result[:TOTAL]}
Ｆｒｅｅ：　　　#{result[:FREE]}
Ｏｂｊｅｃｔ：　#{result[:T_OBJECT]}
Ｃｌａｓｓ：　　#{result[:T_CLASS]}
Ｍｏｄｕｌｅ：　#{result[:T_MODULE]}
Ｓｔｒｉｎｇ：　#{result[:T_STRING]}
Ｒｅｘｅｘｐ：　#{result[:T_REGEXP]}
Ａｒｒａｙ：　　#{result[:T_ARRAY]}
Ｈａｓｈ：　　　#{result[:T_HASH]}
Ｂｉｇｎｕｍ：　#{result[:T_BIGNUM]}
Ｆｉｌｅ：　　　#{result[:T_FILE]}
Ｍａｔｃｈ：　　#{result[:T_MATCH]}
RESPONSE
			else
				#noinspection RubyResolve
				@responses[:no_permission] % {command: command}
			end
		end
	end

	def function_start_debug(_, sender, command, _)
		if COMMAND_START_DEBUG == command
			if qqbot.master?(sender)
				$-d = true
				#noinspection RubyResolve
				@responses[:debug_started]
			else
				#noinspection RubyResolve
				@responses[:no_permission] % {command: command}
			end
		end
	end

	def function_stop_debug(_, sender, command, _)
		if COMMAND_STOP_DEBUG == command
			if qqbot.master?(sender)
				$-d = false
				#noinspection RubyResolve
				@responses[:debug_stopped]
			else
				#noinspection RubyResolve
				@responses[:no_permission] % {command: command}
			end
		end
	end

	def function_display_filter_list(from, sender, command, _)
		if COMMAND_FILTER_LIST == command
			if qqbot.master?(sender) or qqbot.group_manager?(from, sender)
				#noinspection RubyResolve
				@filter.empty? ? @responses[:filter_list_empty] : @filter.join("\n")
			else
				#noinspection RubyResolve
				@responses[:no_permission] % {command: command}
			end
		end
	end

	def function_filter_add(from, sender, command, _)
		if COMMAND_FILTER_ADD =~ command
			if qqbot.master?(sender) or qqbot.group_manager?(from, sender)
				number = $~[:number].to_i
				@filter << number unless @filter.include? number
				save_filter_list
				#noinspection RubyResolve
				@responses[:filter_add] % {number: number}
			else
				#noinspection RubyResolve
				@responses[:no_permission] % {command: command}
			end
		end
	end

	def function_filter_remove(from, sender, command, _)
		if COMMAND_FILTER_REMOVE =~ command
			if qqbot.master?(sender) or qqbot.group_manager?(from, sender)
				number = $~[:number].to_i
				@filter.delete number
				save_filter_list
				#noinspection RubyResolve
				@responses[:filter_remove] % {number: number}
			else
				#noinspection RubyResolve
				@responses[:no_permission] % {command: command}
			end
		end
	end

	def function_plugin_manual(_, _, command, _)
		if COMMAND_PLUGIN_MANUAL =~ command
			plugin = qqbot.plugin($~[:plugin_name])
			if plugin
				#noinspection RubyResolve
				@responses[:plugin_help] % {plugin_name: plugin.name, plugin_manual: plugin.manual}
			else
				#noinspection RubyResolve
				@responses[:unknown_plugin] % {plugin_name: plugin.name}
			end
		end
	end

	def function_plugin_enable(_, _, command, _)
		if COMMAND_PLUGIN_ENABLE =~ command
			if qqbot.master?(sender) or qqbot.group_manager?(from, sender)
				plugin = qqbot.plugin($~[:plugin_name])
				if plugin
					qqbot.enable_plugin(from, sender, plugin)
					#noinspection RubyResolve
					@responses[:plugin_enabled] % {plugin_name: plugin.name}
				else
					#noinspection RubyResolve
					@responses[:unknown_plugin] % {plugin_name: plugin.name}
				end
			else
				#noinspection RubyResolve
				@responses[:no_permission] % {command: command}
			end
		end
	end

	def function_plugin_disable(_, _, command, _)
		if COMMAND_PLUGIN_DISABLE =~ command
			if qqbot.master?(sender) or qqbot.group_manager?(from, sender)
				plugin = qqbot.plugin($~[:plugin_name])
				if plugin
					qqbot.disable_plugin(from, sender, plugin)
					#noinspection RubyResolve
					@responses[:plugin_disabled] % {plugin_name: plugin.name}
				else
					#noinspection RubyResolve
					@responses[:unknown_plugin] % {plugin_name: plugin.name}
				end
			else
				#noinspection RubyResolve
				@responses[:no_permission] % {command: command}
			end
		end
	end
end