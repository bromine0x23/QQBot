# -*- coding: utf-8 -*-

require 'json'
require 'net/http'
require 'uri'
require 'rexml/document'

=begin
使用EVE国服市场中心的物价查询API
参见：http://www.ceve-market.org/api/
=end
class PluginEVE < PluginNicknameResponderCombineFunctionBase
	NAME = 'EVE插件'
	AUTHOR = 'BR'
	VERSION = '1.9'
	DESCRIPTION = '我们的征途的星辰大海'
	MANUAL = <<MANUAL.strip
== 吉他价格查询 ==
EVE 市场 <物品>
EVE 基础矿物
EVE 物品 <物品>
EVE 空间站 <星系>
MANUAL
	PRIORITY = 0

	COMMAND_HEADER = 'EVE'

	COMMAND_MINERAL = /^基础矿物$/
	COMMAND_ITEM_INFO = /^物品\s*(?<item_name>.+)/
	COMMAND_STATION_INFO = /^空间站\s*(?<system_name>.+)/
	COMMAND_SYSTEM_INFO = /^星系\s*(?<system_name>.+)/
	COMMAND_MARKET = /^市场\s*(?<item_name>.+)/

	URI_MINERAL = 'http://www.ceve-market.org/api/evemon'

	JSON_KEY_BUY, JSON_KEY_SELL = 'buy', 'sell'
	JSON_KEY_MAX, JSON_KEY_MIN = 'max', 'min'

	XPATH_MINERAL = 'minerals/mineral'

	PATTERN_THOUSAND_SEPARATOR = /(?<=\d)(?=(\d\d\d)+\.)/

	DB_FILE = file_path('pluginEVE.db')

	SQL_SELECT_ITEM_ID = <<SQL
SELECT id FROM items WHERE name = ?
SQL

	SQL_SELECT_ITEM = <<SQL
SELECT id, description, volume, mass, marketgroup_id FROM items WHERE name = ?
SQL

	SQL_SELECT_MARKETGROUP = <<SQL
SELECT name, parent_id FROM marketgroups WHERE id = ?
SQL

	SQL_SELECT_ITEM_ATTRIBUTES = <<SQL
SELECT attributes.name, item_attributes.value, units.name
FROM item_attributes, attributes, units
WHERE item_attributes.item_id = ? AND item_attributes.attribute_id = attributes.id AND attributes.unit_id = units.id
SQL

	SQL_SELECT_STATION_NAMES = <<SQL
SELECT name FROM stations WHERE system_id = (SELECT id FROM systems WHERE name = ?)
SQL

	SQL_SELECT_SYSTEM = <<SQL
SELECT id, security FROM systems WHERE name = ?
SQL

	SQL_SELECT_NEAR_SYSTEMS = <<SQL
SELECT name, security FROM systems WHERE id IN (SELECT to_id FROM system_jumps WHERE from_id = ?)
SQL

	def on_load
		super
		@db = SQLite3::Database.open DB_FILE
	end

	def on_unload
		super
		@db.close
	end

	#noinspection RubyResolve
	def format_price(price)
		price.round(2).to_s.gsub(PATTERN_THOUSAND_SEPARATOR, @thousand_separator)
	end

	#noinspection RubyResolve
	def function_mineral(_, _, command, _)
		if COMMAND_MINERAL =~ command
			response = ''
			REXML::Document.new(Net::HTTP.get(URI(URI_MINERAL))).each_element(XPATH_MINERAL) do |element|
				response << <<RESPONSE
#{element[0].text}：#{format_price(element[1].text)} #{@units[:price]}
RESPONSE
			end
			response
		end
	end

	#noinspection RubyResolve
	def function_market(_, _, command, _)
		if COMMAND_MARKET =~ command
			item_name = $~[:item_name]
			item_id = @db.get_first_value(SQL_SELECT_ITEM_ID, item_name)
			if item_id
				json_data = JSON.parse(Net::HTTP.get(URI("http://www.ceve-market.org/api/market/region/10000002/system/30000142/type/#{item_id}.json")))
				buy = json_data[JSON_KEY_BUY][JSON_KEY_MAX]
				sell = json_data[JSON_KEY_SELL][JSON_KEY_MIN]
				<<RESPONSE
#{item_name} 吉他报价
求购：#{buy ? format_price(buy) : @responses[:no_price]} #{@units[:price]}
出售：#{sell ? format_price(sell) : @responses[:no_price]} #{@units[:price]}
RESPONSE
			else
				@responses[:no_item] % {item_name: item_name}
			end
		end
	end

	#noinspection RubyResolve
	def function_item_info(_, _, command, _)
		if COMMAND_ITEM_INFO =~ command
			item_name = $~[:item_name]
			result = @db.get_first_row(SQL_SELECT_ITEM, item_name)
			if result
				item_id = result[0]
				description = result[1]
				volume = result[2]
				mass = result[3]
				marketgroup_id = result[4]
				marketgroup_names = []
				while marketgroup_id
					@db.execute(SQL_SELECT_MARKETGROUP, marketgroup_id) do |row|
						marketgroup_names << row[0]
						marketgroup_id = row[1]
					end
				end
				item_attributes = []
				@db.execute(SQL_SELECT_ITEM_ATTRIBUTES, item_id) do |row|
					item_attributes << "#{row[0]}：#{row[1]} #{row[2]}"
				end
				<<RESPONSE
#{item_name}
市场分类：#{marketgroup_names.reverse!.join(' - ')}
体积：#{volume} ㎥　质量：#{mass} ㎏
描述：#{description}
				#{item_attributes.join("\n")}
RESPONSE
			else
				@responses[:no_item] % {item_name: item_name}
			end
		end
	end

	#noinspection RubyResolve
	def function_station_info(_, _, command, _)
		if COMMAND_STATION_INFO =~ command
			system_name = $~[:system_name]
			result = @db.execute(SQL_SELECT_STATION_NAMES, system_name)
			if result
				result.map! { |row| row[0] }.join("\n")
			else
				@responses[:no_system] % system_name
			end
		end
	end

	#noinspection RubyResolve
	def function_system_info(_, _, command, _)
		if COMMAND_SYSTEM_INFO =~ command
			system_name = $~[:system_name]
			result = @db.get_first_row(SQL_SELECT_SYSTEM, system_name)
			if result
				system_id = result[0]
				security = result[1]
				near_systems = ''
				@db.execute(SQL_SELECT_NEAR_SYSTEMS, system_id) do |row|
					near_systems << "#{row[0]} #{row[1]}\n"
				end
				<<RESPONSE
#{system_name}
安等：#{security}
相邻星系：
#{near_systems.empty? ? '无' : near_systems}
RESPONSE
			else
				@responses[:no_system] % {system_name: system_name}
			end
		end
	end
end