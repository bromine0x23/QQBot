# -*- coding: utf-8 -*-

class PluginMC < PluginNicknameResponderCombineFunctionBase
	NAME = 'MC插件'
	AUTHOR = 'BR'
	VERSION = '1.9'
	DESCRIPTION = 'MC合成表查询'
	MANUAL = <<MANUAL.strip
== 合成表查询 ==
MC 合成 <物品>
MANUAL
	PRIORITY = 0

	COMMAND_HEADER = 'MC'

	COMMAND_RECIPE = /^合成\s*(?<item_name>.+)/

	#noinspection RubyResolve
	def on_load
		super
		@alias = @data['alias']
		@recipe = @data['recipe']
		@alias .default_proc = proc { |hash, key| hash[key] = key }
		@recipe.default_proc = proc { |hash, key| hash[key] = "不存在物品：#{key} 的合成公式" }
	end

	def function_recipe(_, _, command, _)
		if COMMAND_RECIPE =~ command
			@recipe[@alias[$~[:item_name]]]
		end
	end
end