# -*- coding: utf-8 -*-

require 'English'

functions << lambda do |_from, sender, command, _time|
	return unless qqbot.administrator?(sender)
	return unless command == '重载插件'
	begin
		format(config[:display][:plugins_reloaded], count: qqbot.reload_plugins)
	rescue
		config[:display][:plugins_reloaded_failed]
	end
end

functions << lambda do |from, sender, command, _time|
	return unless from.group?
	return unless qqbot.administrator?(sender) || qqbot.manager?(from, sender)
	return unless command =~ /\A>(?<action>启用|停用)插件\s*(?<plugin_name>.+)\Z/
	action, plugin_name = $LAST_MATCH_INFO[:action], $LAST_MATCH_INFO[:plugin_name]
	case action
	when '启用'
		plugin = qqbot.find_plugin(sender, plugin_name, false)
		if plugin
			plugin.enable(from)
			format(config[:display][:plugin_enabled], name: plugin.name)
		else
			format(config[:display][:unknown_plugin], name: plugin_name)
		end
	when '停用'
		plugin = qqbot.find_plugin(sender, plugin_name, true)
		if plugin
			plugin.disable(from)
			format(config[:display][:plugin_disabled], name: plugin.name)
		else
			format(config[:display][:unknown_plugin], name: plugin_name)
		end
	else
		fail 'Invalid Action'
	end
end

functions << lambda do |from, _sender, command, _time|
	return unless command == '插件列表'
	format(config[:display][:plugin_list], plugins: qqbot.filtered_plugins(from).join("\n"))
end

functions << lambda do |from, _sender, command, _time|
	return unless command =~ /\A插件帮助\s*(?<plugin_name>.+)\Z/
	plugin_name = $LAST_MATCH_INFO[:plugin_name]
	plugin = qqbot.find_plugin(from, plugin_name, true)
	if plugin
		format(config[:display][:plugin_help], name: plugin.name, manual: plugin.manual)
	else
		config[:display][:unknown_plugin] % {name: plugin_name}
	end
end