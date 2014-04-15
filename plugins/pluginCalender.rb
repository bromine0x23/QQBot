#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require 'json'
require 'net/http'
require 'uri'

class PluginCalender < PluginNicknameResponserBase
	NAME = '黄历插件'
	AUTHOR = 'BR'
	VERSION = '1.8'
	DESCRIPTION = '今日不宜：玩弄AI'
	MANUAL = <<MANUAL.strip
我的运势
今日黄历
掷骰子
<谁><动作>不<动作>XXXXX
有谁生日
MANUAL
	PRIORITY = 0

	THINGS = [
		{name: '组模型', good: '今天的喷漆会很完美', bad: '精神不集中板件被剪断了'},
		{name: '投稿情感区', good: '问题圆满解决', bad: '会被当事人发现'},
		{name: '逛匿名版', good: '今天也要兵库北', bad: '看到丧尸在晒妹'},
		{name: '和女神聊天', good: '女神好感度上升', bad: '我去洗澡了，呵呵'},
		{name: '熬夜', good: '夜间的效率更高', bad: '明天有很重要的事'},
		{name: '锻炼', good: '八分钟给你比利般的身材', bad: '会拉伤肌肉'},
		{name: '散步', good: '遇到妹子主动搭讪', bad: '走路会踩到水坑'},
		{name: '打排位赛', good: '遇到大腿上分500', bad: '我方三人挂机'},
		{name: '汇报工作', good: '被夸奖工作认真', bad: '上班偷玩游戏被扣工资'},
		{name: '抚摸猫咪', good: '才不是特意蹭你的呢', bad: '死开！愚蠢的人类'},
		{name: '遛狗', good: '遇见女神遛狗搭讪', bad: '狗狗随地大小便被罚款'},
		{name: '烹饪', good: '黑暗料理界就由我来打败', bad: '难道这就是……仰望星空派？'},
		{name: '告白', good: '其实我也喜欢你好久了', bad: '对不起，你是一个好人'},
		{name: '追新番', good: '完结之前我绝不会死', bad: '会被剧透'},
		{name: '打卡日常', good: '怒回首页', bad: '会被老板发现'},
		{name: '下副本', good: '配合默契一次通过', bad: '会被灭到散团'},
		{name: '抢沙发', good: '沙发入手弹无虚发', bad: '会被挂起来羞耻play'},
		{name: '网购', good: '商品大减价', bad: '问题产品需要退换'},
		{name: '跳槽', good: '新工作待遇大幅提升', bad: '再忍一忍就加薪了'},
		{name: '读书', good: '知识就是力量', bad: '注意力完全无法集中'},
		{name: '早睡', good: '早睡早起方能养生', bad: '会在半夜醒来，然后失眠'},
		{name: '逛街', good: '物美价廉大优惠', bad: '会遇到奸商'},
		{name: '写单元测试', good: '写单元测试将减少出错',bad: '写单元测试会降低你的开发效率'},
		{name: '洗澡', good: '你几天没洗澡了？',bad: '会把设计方面的灵感洗掉'},
		{name: '重构', good: '代码质量得到提高',bad: '你很有可能会陷入泥潭'},
		{name: '在妹子面前吹牛', good: '改善你矮穷挫的形象',bad: '会被识破'},
		{name: '打DOTA', good: '你将有如神助',bad: '你会被虐的很惨'},
		{name: '修复BUG', good: '你今天对BUG的嗅觉大大提高', bad: '新产生的BUG将比修复的更多'},
		{name: '上微博', good: '今天发生的事不能错过',bad: '今天的微博充满负能量'},
		{name: '上AB站', good: '还需要理由吗？',bad: '满屏兄贵亮瞎你的眼'},
		{name: '玩FlappyBird', good: '今天破纪录的几率很高',bad: '除非你想玩到把手机砸了'},
		{name: '玩2048', good: '今天组出248的几率很高',bad: '除非你想玩到把电脑砸了'}
	]

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

	COMMAND_FORTUNE  = '我的运势'
	COMMAND_CALENDER = '今日黄历'
	COMMAND_BIRTHDAY = '有谁生日'
	COMMAND_DICE     = '掷骰子'
	COMMAND_CHOOSE   = /^(?<谁>.??)(?<动作>\S)(?<否定词>[不没])\k<动作>(?<剩余>.*)/

	STRING_我 = '我'
	STRING_你 = '你'

	BIRTHDAY_DISPLAY_DOOR = 3

	JSON_KEY_RESULT = 'result'
	JSON_KEY_NAME = 'name'
	JSON_KEY_ORIGIN = 'origin'

	RESPONSE_FUCK = [
		'滚你妈逼 ⊂彡☆))д`)',
		'玩蛋去 ⊂彡☆))д´)',
		'TM就知道玩AI！',
		'老问这种问题有救不',
		'你以为我会告诉你吗',
		'我是不会回答这个问题的',
		'烦死了',
		'你猜',
		'…………',
		'不如问问隔壁安安子？',
		'别着急要答案，来杯淡定红茶吧 ( ・_ゝ・)'
	]

	def get_response(uin, sender_qq, sender_nickname, message, time)
		# super # FOR DEBUG
		case message
		when COMMAND_FORTUNE
			time = Time.now
			response = get_date_string(time)
			response << get_lunar_date_string(time)
			level = random(get_seed(time) * sender_qq, 6) % 100 # 迷之伪随机6
			response << "#{sender_nickname} 的运势指数：#{STR_FORTUNE_LEVELS[level / 5]}(#{level})"
		when COMMAND_CALENDER
			time = Time.now
			seed = get_seed(time)
			response = get_date_string(time)
			response << get_lunar_date_string(time)
			@things = THINGS.clone
			response << "宜：\n"
			good_things(seed).each { |thing| response << "#{thing[:name]}:#{thing[:good]}\n" }
			response << "忌：\n"
			bad_things(seed).each { |thing| response << "#{thing[:name]}:#{thing[:bad]}\n" }
			response
		when COMMAND_BIRTHDAY
			json_data = JSON.parse(Net::HTTP.get(URI('http://shiningco.sinaapp.com/api/birthday')))
			result = json_data[JSON_KEY_RESULT]
			if result
				response = ''
				result.sample(BIRTHDAY_DISPLAY_DOOR).each do |data|
					response << <<LINE
#{data[JSON_KEY_NAME]}（#{data[JSON_KEY_ORIGIN]}）
LINE
				end
				response
			else
				'没人生日'
			end
		when COMMAND_DICE
			time = Time.now
			"#{bot_name} 掷出了 #{random(get_seed(time) | time.sec | sender_qq, 5) % 6 + 1}" # 迷之伪随机5
		else
			if COMMAND_CHOOSE =~ message

				谁 = $~[:谁]
				动作 = $~[:动作]
				否定词 = $~[:否定词]
				剩余 = $~[:剩余]

				if 谁 == STRING_你
					RESPONSE_FUCK.sample
				elsif 谁 != ''
					if 谁 == STRING_我
						if random(get_seed(Time.now) * (动作.sum * 剩余.sum) | sender_qq, 3) % 2 == 0 # 迷之伪随机3
							"#{动作}#{剩余}！"
						else
							"#{否定词}#{动作}#{剩余}……"
						end
					else
						if random(get_seed(Time.now) * (谁.sum  * 动作.sum * 剩余.sum), 3) % 2 == 0 # 迷之伪随机3
							"#{谁}#{动作}#{剩余}！"
						else
							"#{谁}#{否定词}#{动作}#{剩余}……"
						end
					end
				else
					'你问谁？'
				end

			end
		end
	end

	# 迷之伪随机
	def random(a, b)
		n = a % 11117
		(25+b).times { n = n * n % 11117 }
		n
	end

	def get_seed(date)
		date.year * 37621 + (date.month + 1) * 539 + date.day
	end

	def get_date_string(date)
		<<STRING
#{date.year}年#{date.month}月#{date.day}日 周#{STR_WEEK[date.wday]}
STRING
	end

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

	def good_things(seed)
		good_things = []
		sg = random(seed, 8) % 100 # 迷之伪随机8
		(random(seed, 9) % 3 + 1).times do # 迷之伪随机9
			good_things << @things.delete_at((sg * 0.01 * @things.size).to_i)

		end
		good_things
	end

	def bad_things(seed)
		bad_things = []
		sb = random(seed, 4) % 100 # 迷之伪随机4
		(random(seed, 7) % 3 + 1).times do # 迷之伪随机7
			bad_things << @things.delete_at((sb * 0.01 * @things.size).to_i)
		end
		bad_things
	end
end