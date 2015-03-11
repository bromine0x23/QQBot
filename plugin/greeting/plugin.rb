# -*- coding: utf-8 -*-

pattern = {
	morning: /\A.*?(?:早(?:安|上好)|哦[嗨哈]哟).*\Z/,
	evening: /\A.*?(?:晚安|睡觉?去?了?).*\Z/
}

define_singleton_method :pattern_with_name do
	@pattern_with_name ||= pattern_without_name
end

functions << lambda do |_from, sender, command, time|
	zone =
		case time.hour
		when 5...10
			:morning
		when 21...24, 0...3
			:evening
		else
			return
		end
	return unless command =~ pattern[zone]
	format(config[:responses][zone].sample, name: sender.name)
end