#!ruby -w -E utf-8

require 'English'
require 'pp'
require 'readline'

require_relative 'qqbot'

loop do
	begin
		case Readline.readline('> ', true)
		when /\Ainit\Z/i
			QQBot.instance.init
		when /\Alogin\Z/i
			QQBot.instance.login
		when /\Alogout\Z/i
			QQBot.instance.logout
		when /\Arelink\Z/i
			QQBot.instance.relink
		when /\Aplugin\s*(?<command>\w*)\Z/i
			case $LAST_MATCH_INFO[:command]
			when /\Aload\Z/i
				QQBot.instance.load_plugins
			when /\Aunload\Z/i
				QQBot.instance.unload_plugins
			when /\Areload\Z/i
				QQBot.instance.reload_plugins
			when /\Alist\Z/i
				puts QQBot.instance.instance_variable_get(:@plugins).map(&:inspect).join("\n")
			else
				puts '无效指令'
			end
		when /\Ahandle\s*(?<command>\w*)\Z/i
			case $LAST_MATCH_INFO[:command]
			when /\Astart\Z/i
				QQBot.instance.start_handle
			when /\Astop\Z/i
				QQBot.instance.stop_handle
			else
				puts '无效指令'
			end
		when /\Adebug\s*(?<switch>on|off)\Z/i
			$-d = ($LAST_MATCH_INFO[:switch] == 'on')
			case $1
			when /\Aon\Z/i
				$-d = true
				puts '进入DEBUG模式'
			when /\Aoff\Z/i
				$-d = false
				puts '退出DEBUG模式'
			else
				puts '无效指令'
			end
		when /\Aexit\Z/i
			break
		when /\Aeval\s+(?<command>.*)\Z/i
			pp self.instance_eval($LAST_MATCH_INFO[:command])
		when /\Ahelp\Z/i
			puts <<-HELP
init            QQBot初始化
login           QQBot登陆
logout          QQBot登出
relink          QQBot重连
plugin *        插件相关指令
       load     载入插件
       unload   卸载插件
       reload   重载插件
handle *        消息处理
       start    开始消息处理
       stop     停止消息处理
debug on|off    开启|关闭调试
eval            求值
exit            退出
help            显示此帮助
			HELP
		else
			puts '无效指令'
		end
	rescue => ex
		puts '指令执行中发生异常', ex.class, ex.message, ex.backtrace
	end
end