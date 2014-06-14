# -*- coding: utf-8 -*-

class PluginCore < PluginNicknameResponderCombineFunctionBase
	NAME = '核心插件'
	AUTHOR = 'BR'
	VERSION = '1.16'
	DESCRIPTION = 'QQBot核心'
	MANUAL = <<MANUAL.strip
==> 系统插件 <==
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
	end

	def on_unload
		super
		save_filter_list
	end

	FILTER_FILE = file_path('pluginCore.filter')

	def load_filter_list
		@filter = YAML.load_file(FILTER_FILE)
	end

	def save_filter_list
		File.open(FILTER_FILE, 'w') do |file|
			file << YAML.dump(@filter)
		end
	end

	def on_message(sender, message, time)
		return true if @filter.include? sender.number
		super
	end

	def on_group_message(from, sender, message, time)
		return true if @filter.include? sender.number
		super
	end

	COMMAND_LIST_PLUGINS = '插件列表'
	COMMAND_LIST_PRIORITIES = '插件优先级'
	COMMAND_RELOAD_PLUGINS = '重载插件'
	COMMAND_START_GC = '垃圾回收'
	COMMAND_OBJECT_CHECK = '检视对象'
	COMMAND_START_DEBUG = '开始调试'
	COMMAND_STOP_DEBUG = '结束调试'
	COMMAND_FILTER_LIST = '屏蔽列表'
	COMMAND_FILTER_ADD = /^屏蔽\s*(?<number>\d+)/
	COMMAND_FILTER_REMOVE = /^(停止|取消)屏蔽\s*(?<number>\d+)/
	COMMAND_PLUGIN_MANUAL = /^插件帮助\s*(?<plugin_name>.+)/
	COMMAND_PLUGIN_ENABLE = /^启用插件\s*(?<plugin_name>.+)/
	COMMAND_PLUGIN_DISABLE = /^停用插件\s*(?<plugin_name>.+)/

	# @param [WebQQProtocol::QQEntity] from
	# @param [String] command
	def function_list_plugins(from, _, command, _)
		if COMMAND_LIST_PLUGINS == command
			header = "已启用插件：\n"
			body = qqbot.plugins(from).join("\n")
			#noinspection RubyResolve
			header << (body.empty? ? @responses[:plugin_list_empty] : body)
		end
	end

	# @param [WebQQProtocol::QQEntity] from
	# @param [String] command
	def function_list_priorities(from, _, command, _)
		if COMMAND_LIST_PRIORITIES == command
			qqbot.plugins(from).map { |plugin| "#{plugin.name} => #{plugin.priority}" }.join("\n")
		end
	end

	# @param [WebQQProtocol::QQEntity] sender
	# @param [String] command
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

	# @param [WebQQProtocol::QQEntity] sender
	# @param [String] command
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

	# @param [WebQQProtocol::QQEntity] sender
	# @param [String] command
	def function_object_check(_, sender, command, _)
		if COMMAND_OBJECT_CHECK == command
			if qqbot.master?(sender)
				result = ObjectSpace.count_objects
				<<RESPONSE.strip!
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

	# @param [WebQQProtocol::QQEntity] sender
	# @param [String] command
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

	# @param [WebQQProtocol::QQEntity] sender
	# @param [String] command
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

	# @param [WebQQProtocol::QQEntity] from
	# @param [WebQQProtocol::QQEntity] sender
	# @param [String] command
	def function_display_filter_list(from, sender, command, _)
		if COMMAND_FILTER_LIST == command
			if qqbot.master?(sender) or qqbot.group_manager?(from, sender)
				#noinspection RubyResolve
				if @filter.empty?
					@responses[:filter_list_empty]
				elsif from.is_a?(WebQQProtocol::QQGroup)
					@filter.map { |number| from.member_by_number(number) || number }.join("\n")
				else
					@filter.join("\n")
				end
			else
				#noinspection RubyResolve
				@responses[:no_permission] % {command: command}
			end
		end
	end

	# @param [WebQQProtocol::QQEntity] from
	# @param [WebQQProtocol::QQEntity] sender
	# @param [String] command
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

	# @param [WebQQProtocol::QQEntity] from
	# @param [WebQQProtocol::QQEntity] sender
	# @param [String] command
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

	# @param [String] command
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

	# @param [WebQQProtocol::QQEntity] from
	# @param [WebQQProtocol::QQEntity] sender
	# @param [String] command
	def function_plugin_enable(from, sender, command, _)
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

	# @param [WebQQProtocol::QQEntity] from
	# @param [WebQQProtocol::QQEntity] sender
	# @param [String] command
	def function_plugin_disable(from, sender, command, _)
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