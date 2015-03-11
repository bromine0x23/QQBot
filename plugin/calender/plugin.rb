# -*- coding: utf-8 -*-

require 'English'

# noinspection RubyLocalVariableNamingConvention
中文数码 = '〇一二三四五六七八九'

# noinspection RubyLocalVariableNamingConvention
中文数字 = lambda do|num|
	result = ''
	while num > 0
		# noinspection RubyResolve
		result.prepend(中文数码[num % 中文数码.size])
		num /= 10
	end
	result
end

# noinspection RubyLocalVariableNamingConvention
周 = '日一二三四五六'

# noinspection RubyLocalVariableNamingConvention
公历日期 = lambda do |date|
	{
		year: date.year,
		month: date.month,
		day: date.day,
		week: date.wday,
		年: 中文数字.call(date.year),
		月: 中文数字.call(date.month),
		日: 中文数字.call(date.day),
		周: 周[date.wday],
	}
end

# noinspection RubyLocalVariableNamingConvention
天干 = '甲乙丙丁戊己庚辛壬癸'

# noinspection RubyLocalVariableNamingConvention
地支 = '子丑寅卯辰巳午未申酉戌亥'

# noinspection RubyLocalVariableNamingConvention
生肖 = '鼠牛虎兔龙蛇马羊猴鸡狗猪'

# noinspection RubyLocalVariableNamingConvention
农历月名 = %w(正月 二月 三月 四月 五月 六月 七月 八月 九月 十月 冬月 腊月)

# noinspection RubyLocalVariableNamingConvention
农历日名 = %w(〇 初一 初二 初三 初四 初五 初六 初七 初八 初九 初十 十一 十二 十三 十四 十五 十六 十七 十八 十九 二十 廿一 廿二 廿三 廿四 廿五 廿六 廿七 廿八 廿九 三十)

day_accumulation = [0, 0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]

month_sizes = [
	0x00A4B, 0x5164B, 0x006A5, 0x006D4, 0x415B5,
	0x002B6, 0x00957, 0x2092F, 0x00497, 0x60C96,
	0x00D4A, 0x00EA5, 0x50DA9, 0x005AD, 0x002B6,
	0x3126E, 0x0092E, 0x7192D, 0x00C95, 0x00D4A,
	0x61B4A, 0x00B55, 0x0056A, 0x4155B, 0x0025D,
	0x0092D, 0x2192B, 0x00A95, 0x71695, 0x006CA,
	0x00B55, 0x50AB5, 0x004DA, 0x00A5B, 0x30A57,
	0x0052B, 0x8152A, 0x00E95, 0x006AA, 0x615AA,
	0x00AB5, 0x004B6, 0x414AE, 0x00A57, 0x00526,
	0x31D26, 0x00D95, 0x70B55, 0x0056A, 0x0096D,
	0x5095D, 0x004AD, 0x00A4D, 0x41A4D, 0x00D25,
	0x81AA5, 0x00B54, 0x00B6A, 0x612DA, 0x0095B,
	0x0049B, 0x41497, 0x00A4B, 0xA164B, 0x006A5,
	0x006D4, 0x615B4, 0x00AB6, 0x00957, 0x5092F,
	0x00497, 0x0064B, 0x30D4A, 0x00EA5, 0x80D65,
	0x005AC, 0x00AB6, 0x5126D, 0x0092E, 0x00C96,
	0x41A95, 0x00D4A, 0x00DA5, 0x20B55, 0x0056A,
	0x7155B, 0x0025D, 0x0092D, 0x5192B, 0x00A95,
	0x00B4A, 0x416AA, 0x00AD5, 0x90AB5, 0x004BA,
	0x00A5B, 0x60A57, 0x0052B, 0x00A93, 0x40E95
]

# noinspection RubyLocalVariableNamingConvention
农历日期 = lambda do |date|
	year, month, day = date.year, date.month, date.day
	total_day = (year - 1921) * 365 + (year - 1921) / 4 + day_accumulation[month] + day - 38 + (year % 4 == 0 && month > 1 ? 1 : 0)

	y, m, t = 0, 0, 0
	while y < 100
		t = m = ((month_size = month_sizes[y]) < 0x00FFF ? 12 : 13)
		total_day -= 29 + month_size[t -= 1] while t > 0 and total_day > 0
		break unless total_day > 0
		y += 1
	end
	total_day += 29 + month_sizes[y][t] if total_day <= 0

	year, month, day  = 1921 + y, m - t, total_day

	if t == 12
		door = month_sizes[y] / 0x10000 + 1
		if month == door
			month = 1 - month
		elsif month > door
			month -= 1
		end
	end

	{
		天干: 天干[(year-4) % 天干.size],
		地支: 地支[(year-4) % 地支.size],
		生肖: 生肖[(year-4) % 生肖.size],
		月: month < 1 ? "闰#{农历月名[-month-1]}" : 农历月名[month-1],
		日: 农历日名[day],
	}
end

fortune_judge = %w(大凶 凶 凶 凶 末吉 末吉 末吉 末吉 末吉 末吉 半吉 半吉 吉 吉 小吉 小吉 中吉 中吉 大吉 大吉 秀吉 溢出)

judge = lambda do |level|
	fortune_judge[level / 5]
end

functions << lambda do |_from, sender, command, time|
	return unless /\A(?:我的)?运势\Z/ =~ command
	level = pseudo_random(date_seed(time, 11111, 111, 1) ^ sender.number, 11) % 102 - 1
	format(
		config[:display][:fortune],
		公历日期: format(config[:display][:公历日期], 公历日期.call(time)),
		农历日期: format(config[:display][:农历日期], 农历日期.call(time)),
		name: sender.name,
		level: level,
		judge: judge.call(level),
	)
end

ac_pick_items = lambda do |items, seed, min_thing, max_thing, select_index, size_index|
	select = pseudo_random(seed, select_index, 11117) % 100
	size = pseudo_random(seed, size_index, 11117) % (max_thing - min_thing) + min_thing
	Array.new(size) { items.delete_at((select * 0.01 * items.size).to_i) }
end

eve_pick_items = lambda do |items, seed, size|
	result = items.clone
	(items.size - size).times do |i|
		result.delete_at(pseudo_random(seed, 100 + i) % result.size)
	end
	result
end

functions << lambda do |_from, _sender, command, time|
	return unless /\A(?:今日)?\s*(?<type>\S*)?\s*黄历\Z/ =~ command
	case $LAST_MATCH_INFO[:type]
	when /\AEVE\Z/i
		seed = date_seed(time, 10000, 100, 1)
		good_num, bad_num = pseudo_random(seed, 198, 11117) % 3 + 2, pseudo_random(seed, 187, 11117) % 3 + 2
		items = eve_pick_items.call(config[:calender][:eve][:items], seed, good_num + bad_num)
		good_items, bad_items = items.shift(good_num), items
	when /\A舰娘\Z/i
		seed = date_seed(time, 10000, 100, 1)
		good_num, bad_num = pseudo_random(seed, 198, 11117) % 3 + 2, pseudo_random(seed, 187, 11117) % 3 + 2
		items = eve_pick_items.call(config[:calender][:kan][:items], seed, good_num + bad_num)
		good_items, bad_items = items.shift(good_num), items
	else
		items = config[:calender][:ac][:items].clone
		seed = date_seed(time, 37621, 539, 1)
		good_items, bad_items =
			ac_pick_items.call(items, seed, 2, 5, 33, 34), ac_pick_items.call(items, seed, 2, 5, 29, 32)
	end
	format(
		config[:display][:items],
		公历日期: format(config[:display][:公历日期], 公历日期.call(time)),
		农历日期: format(config[:display][:农历日期], 农历日期.call(time)),
		good_items: good_items.map{ |item|
			format(
				config[:display][:item],
				name: item[:name],
				description: item[:good]
			)
		}.join("\n"),
		bad_items: bad_items.map{ |item|
			format(
				config[:display][:item],
				name: item[:name],
				description: item[:bad]
			)
		}.join("\n")
	)
end