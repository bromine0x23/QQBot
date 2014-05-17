# -*- coding: utf-8 -*-

require 'json'
require 'net/http'
require 'uri'

class PluginCalender < PluginNicknameResponderCombineFunctionBase
	NAME = '黄历插件'
	AUTHOR = 'BR'
	VERSION = '1.14'
	DESCRIPTION = '今日不宜：玩弄AI'
	MANUAL = <<MANUAL.strip
我的运势
今日黄历
掷骰子
<谁><动作>不<动作>XXXXX
<选择1>还是<选择2>
有谁生日
MANUAL
	PRIORITY = 0

	STR_TG    = '甲乙丙丁戊己庚辛壬癸'
	STR_DZ    = '子丑寅卯辰巳午未申酉戌亥'
	STR_SX    = '鼠牛虎兔龙蛇马羊猴鸡狗猪'
	STR_NUM   = '一二三四五六七八九十'
	STR_MONTH = '正二三四五六七八九十冬腊'
	STR_WEEK  = '日一二三四五六'
	STR_DAYS = %w(〇 初一 初二 初三 初四 初五 初六 初七 初八 初九 初十 十一 十二 十三 十四 十五 十六 十七 十八 十九 廿 二十一 二十二 二十三 二十四 二十五 二十六 二十七 二十八 二十九 三十 三十一 三十二 三十三 三十四 三十五 三十六 三十七 三十八 三十九 四十)
	STR_FORTUNE_LEVELS = %w(大凶 凶 凶 凶 末吉 末吉 末吉 末吉 末吉 末吉 半吉 半吉 吉 吉 小吉 小吉 中吉 中吉 大吉 大吉)

	SZ_STR_TG    = STR_TG.size
	SZ_STR_DZ    = STR_DZ.size
	SZ_STR_SX    = STR_SX.size
	SZ_STR_NUM   = STR_NUM.size
	SZ_STR_MONTH = STR_MONTH.size
	SZ_STR_WEEK  = STR_WEEK.size

	MONTH_DAY_ACC = [0, 0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]

	# 迷之数组
	CALENDAR_DATA = [
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

	CHINESE_DIGIT_TO_ARAB_DIGIT = {
		'一' => 1,
		'二' => 2,
		'三' => 3,
		'四' => 4,
		'五' => 5,
		'六' => 6,
		'七' => 7,
		'八' => 8,
		'九' => 9,
		'十' => 10,
	}

	COMMAND_FORTUNE    = /^我的运势$/
	COMMAND_CALENDER   = /^今日黄历$/
=begin
/^(?<date>
	(?<month>0?[13578]|1[02])月(?<day>0?[1-9]|[12][0-9]|3[01])[日号]|
	(?<month>0?[469]|11)月(?<day>0?[1-9]|[12][0-9]|30)[日号]|
	(?<month>0?2)月(?<day>0?[1-9]|[12][0-9])[日号]|
	(?<month>0?[13578]|1[02])[-.\/](?<day>0?[1-9]|[12][0-9]|3[01])|
	(?<month>0?[469]|11)[-.\/](?<day>0?[1-9]|[12][0-9]|30)|
	(?<month>0?2)[-.\/](?<day>0?[1-9]|[12][0-9])|
	(?<month>[一三五七八]|十二?)月(?<day>[一二三四五六七八九]|二?十[一二三四五六七八九]?|三十一?)[日号]|
	(?<month>[四六九]|十一)月(?<day>[一二三四五六七八九]|二?十[一二三四五六七八九]?|三十)[日号]|
	(?<month>二)月(?<day>[一二三四五六七八九]|二?十[一二三四五六七八九]?)[日号]
)?(有谁)?生日/x
=end
	COMMAND_BIRTHDAY   = /^(?<date>(?<month>0?[13578]|1[02])月(?<day>0?[1-9]|[12][0-9]|3[01])[日号]|(?<month>0?[469]|11)月(?<day>0?[1-9]|[12][0-9]|30)[日号]|(?<month>0?2)月(?<day>0?[1-9]|[12][0-9])[日号]|(?<month>0?[13578]|1[02])[-.\/](?<day>0?[1-9]|[12][0-9]|3[01])|(?<month>0?[469]|11)[-.\/](?<day>0?[1-9]|[12][0-9]|30)|(?<month>0?2)[-.\/](?<day>0?[1-9]|[12][0-9])|(?<month>[一三五七八]|十二?)月(?<day>[一二三四五六七八九]|二?十[一二三四五六七八九]?|三十一?)[日号]|(?<month>[四六九]|十一)月(?<day>[一二三四五六七八九]|二?十[一二三四五六七八九]?|三十)[日号]|(?<month>二)月(?<day>[一二三四五六七八九]|二?十[一二三四五六七八九]?)[日号])?(有谁)?生日/
	COMMAND_DICE       = /^掷骰子$/
	COMMAND_TRUE_FALSE = /^(?<WHO>\S*?)(?<ACT>\S+)(?<NEG>[不没])\k<ACT>(?<ETC>\S*)([呢]?)([?？]?)$/
	COMMAND_SELECT     = /^(?<SELECT1>\S+)还是(?<SELECT2>\S+?)([呢]?)([?？]?)$/
	COMMAND_LOTTERY    = /^双色球$/

	STRING_I = '我'
	STRING_YOU = '你'

	JSON_KEY_RESULT = 'result'
	JSON_KEY_NAME   = 'name'
	JSON_KEY_ORIGIN = 'origin'

	def on_load
		super
	end

	FUNCTIONS = [
		:function_fortune,
		:function_calender,
		:function_dice,
		:function_birthday,
		:function_true_false,
		:function_select,
		:function_lottery
	]

	def function_fortune(_, sender, command, time)
		if COMMAND_FORTUNE =~ command
			return "#{get_date_string(time)}#{get_lunar_date_string(time)}#{sender.name} 的运势指数：＋∞(Ultra Lucky!)" if time.year == 2014 and time.month == 5 and time.month == 18
			level = random(get_seed(time) * sender.number, 6) % 100 # 迷之伪随机6
			"#{get_date_string(time)}#{get_lunar_date_string(time)}#{sender.name} 的运势指数：#{STR_FORTUNE_LEVELS[level / 5]}(#{level})"
		end
	end

	def function_calender(_, _, command, time)
		if COMMAND_CALENDER =~ command
			seed = get_seed(time)
			response = get_date_string(time) << get_lunar_date_string(time)
			#noinspection RubyResolve
			@tmp_things = @things.clone
			response << "宜：\n"
			good_things(seed).each { |thing| response << "#{thing[:thing]}：#{thing[:good]}\n" }
			response << "忌：\n"
			bad_things(seed).each { |thing| response << "#{thing[:thing]}：#{thing[:bad]}\n" }
			response
		end
	end

	def function_dice(_, sender, command, time)
		if COMMAND_DICE =~ command
			"#{qqbot_name} 掷出了 #{random(get_seed(time) | time.sec | sender.number, 5) % 6 + 1}" # 迷之伪随机5
		end
	end

	def function_birthday(_, _, command, time)
		if COMMAND_BIRTHDAY =~ command
			if $~[:date]
				specify_date = true
				month = try_convert_to_integer($~[:month])
				day   = try_convert_to_integer($~[:day])
				result = JSON.parse(Net::HTTP.get(URI("http://shiningco.sinaapp.com/api/birthday?day=#{month}/#{day}")))[JSON_KEY_RESULT]
			else
				specify_date = false
				month = time.month
				day = time.day
				result = JSON.parse(Net::HTTP.get(URI('http://shiningco.sinaapp.com/api/birthday')))[JSON_KEY_RESULT]
			end

			if result
				response = specify_date ? "#{month}月#{day}日 生日：\n" : "今日（#{month}月#{day}日）生日：\n"
				#noinspection RubyResolve
				result.sample(@birthday[:display_line]).each do |data|
					response << "#{data[JSON_KEY_NAME]}（#{data[JSON_KEY_ORIGIN]}）\n"
				end
				response
			else
				#noinspection RubyResolve
				specify_date ? "#{month}月#{day}日 #{@responses[:nobody_birthday].sample}" : "今日（#{month}月#{day}日）#{@responses[:nobody_birthday].sample}"
			end
		end
	end

	def function_true_false(_, sender, command, time)
		if COMMAND_TRUE_FALSE =~ command
			who = $~[:WHO]
			act = $~[:ACT]
			neg = $~[:NEG]
			etc = $~[:ETC]
			if who == STRING_YOU
				#noinspection RubyResolve
				@responses[:fuck].sample
			elsif who != ''
				if who == STRING_I
					random(get_seed(time) * (act.sum * etc.sum) | sender.number, 3).odd? ? "#{act}#{etc}！" : "#{neg}#{act}#{etc}……" # 迷之伪随机3
				else
					random(get_seed(time) * (who.sum * act.sum * etc.sum), 3).odd? ? "#{who}#{act}#{etc}！" : "#{who}#{neg}#{act}#{etc}……" # 迷之伪随机3
				end
			else
				#noinspection RubyResolve
				@responses[:who].sample
			end
		end
	end

	def function_select(_, _, command, time)
		if COMMAND_SELECT =~ command
			select1 = $~[:SELECT1]
			select2 = $~[:SELECT2]

			select1, select2 = select2, select1 if select1.sum > select2.sum

			if select1 == select2
				#noinspection RubyResolve
				@responses[:same].sample
			else
				random(get_seed(time) * (select1.sum * select2.sum), 2).odd? ? select1 : select2 # 迷之伪随机2
			end
		end
	end

	def function_lottery(_, sender, command, time)
		if command =~ COMMAND_LOTTERY
			seed = get_seed(time) | sender.number
			<<RESPONSE
红复：#{Array.new(6) { |i| '%02d' % (random(seed, i) % 33 + 1) }.join(' ')}
蓝单：#{random(seed, 6) % 16 + 1}
RESPONSE
		end
	end

	# @return [Integer]
	def try_convert_to_integer(string)
		integer = string.to_i
		return integer if integer != 0
		string.each_char { |chinese_digit| (chinese_digit == '十') ? integer *= 10 : integer += CHINESE_DIGIT_TO_ARAB_DIGIT[chinese_digit] }
		integer == 0 ? 10 : integer
	end

	# 迷之伪随机
	# @return [Integer]
	def random(a, b)
		n = a % 11117
		(25+b).times { n = n * n % 11117 }
		n
	end

	# @return [Integer]
	def get_seed(date)
		date.year * 37621 + (date.month + 1) * 539 + date.day
	end

	# @return [String]
	def get_date_string(date)
		<<STRING
#{date.year}年#{date.month}月#{date.day}日 周#{STR_WEEK[date.wday]}
STRING
	end

	# @return [String]
	def get_lunar_date_string(date)
		year  = date.year
		month = date.month
		day   = date.day
		total_day = (year - 1921) * 365 + (year - 1921) / 4 + MONTH_DAY_ACC[month] + day - 38
		total_day += 1 if year % 4 == 0 && month > 1

		is_end = false
		m, n, k = 0, 0, 0
		while m < 100
			n = k = CALENDAR_DATA[m] < 0x00FFF ? 11 : 12
			while n >= 0
				is_end = total_day <= 29 + CALENDAR_DATA[m][n]
				break if is_end
				total_day -= 29 + CALENDAR_DATA[m][n]
				n -= 1
			end
			break if is_end
			m += 1
		end

		year  = 1921 + m
		month = k - n + 1
		day   = total_day

		if k == 12
			door = CALENDAR_DATA[m] / 0x10000 + 1
			if month == door
				month = 1 - month
			elsif month > door
				month -= 1
			end
		end

		<<DATE
#{STR_TG[(year-4)%SZ_STR_TG]}#{STR_DZ[(year-4)%SZ_STR_DZ]}#{STR_SX[(year-4)%SZ_STR_SX]}年#{month < 1 ? "闰#{STR_MONTH[-month-1]}" : STR_MONTH[month-1]}月#{STR_DAYS[day]}
DATE
	end

	# @return [Array[Hash]]
	def good_things(seed)
		good_things = []
		sg = random(seed, 8) % 100 # 迷之伪随机8
		#noinspection RubyResolve
		(random(seed, 9) % (@max_good - @min_good) + @min_good).times do # 迷之伪随机9
			good_things << @tmp_things.delete_at((sg * 0.01 * @tmp_things.size).to_i)
		end
		good_things
	end

	# @return [Array[Hash]]
	def bad_things(seed)
		bad_things = []
		sb = random(seed, 4) % 100 # 迷之伪随机4
		#noinspection RubyResolve
		(random(seed, 7) % (@max_bad - @min_bad) + @min_bad).times do # 迷之伪随机7
			bad_things << @tmp_things.delete_at((sb * 0.01 * @tmp_things.size).to_i)
		end
		bad_things
	end
end