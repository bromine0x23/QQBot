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
	VERSION = '2.0'
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
	COMMAND_STATION_INFO = /^空间站\s*(?<system_name>.+)/
	COMMAND_SYSTEM_INFO = /^星系\s*(?<system_name>.+)/
	COMMAND_FACTION_INFO = /^势力\s*(?<faction_name>.+)/
	COMMAND_MARKET = /^市场\s*(?<item_name>.+)/

	URI_MINERAL = 'http://www.ceve-market.org/api/evemon'

	XPATH_MINERAL = 'minerals/mineral'

	PATTERN_THOUSAND_SEPARATOR = /(?<=\d)(?=(\d\d\d)+\.)/

	DB_FILE = file_path('pluginEVE.db')

	SQL_SELECT_ITEM_TYPE = <<SQL
SELECT "typeID", "typeName", "typeName_ZH", "typeName_JA"
	FROM "marketTypes"
	WHERE "typeName_ZH" = ?
SQL

	SQL_SELECT_ITEM_TYPES = <<SQL
SELECT "typeID", "typeName", "typeName_ZH", "typeName_JA"
	FROM "marketTypes"
	WHERE "typeName_ZH" LIKE ?
SQL

	SQL_SELECT_STATIONS = <<SQL
SELECT "stationName", "stationName_ZH"
	FROM "stations"
	WHERE "solarSystemID" = (
		SELECT "solarSystemID"
			FROM "solarSystems"
			WHERE "solarSystemName_ZH" = ?
	)
SQL

	SQL_SELECT_SOLAR_SYSTEM = <<SQL
SELECT "solarSystemName", "solarSystemName_ZH", "factions"."factionName_ZH", "security"
	FROM "solarSystems"
		JOIN "factions"
			ON "solarSystems"."factionID" = "factions"."factionID"
	WHERE "solarSystemName_ZH" = ?
SQL

	SQL_SELECT_FACTION = <<SQL
SELECT "factionName", "factionName_ZH", "factionName_JA",  "stationCount", "description_ZH"
	FROM "factions"
	WHERE "factionName_ZH" LIKE ?
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
	def format_market_result(type_id, type_name, type_name_zh, type_name_ja)
		json_data = JSON.parse(
			Net::HTTP.get(
				URI("http://www.ceve-market.org/api/market/region/10000002/system/30000142/type/#{type_id}.json")
			)
		)
		buy = json_data['buy']['max']
		sell = json_data['sell']['min']
		@responses[:display_price] % {
			type_name: type_name,
			type_name_zh: type_name_zh,
			type_name_ja: type_name_ja,
			buy_price: buy ? format_price(buy) + @units[:price] : @responses[:no_price],
			sell_price: sell ? format_price(sell) + @units[:price] : @responses[:no_price],
		}
	end

	#noinspection RubyResolve
	def function_market(_, _, command, _)
		if COMMAND_MARKET =~ command
			item_name = $~[:item_name]
			types = @db.get_first_row(SQL_SELECT_ITEM_TYPE, item_name)
			if types
				format_market_result(*types)
			else
				types = @db.execute(SQL_SELECT_ITEM_TYPES, item_name + '%')

				case types.length
				when 0
					@responses[:no_item] % {item_name: item_name}
				when 1
					format_market_result(*types[0])
				else
					type_names = types.map! {|type| type[2]}
					if type_names.length > @duplicate_display_door
						@responses[:duplicate_item_more] % {type_names:  type_names.first(@duplicate_display_door).join("\n")}
					else
						@responses[:duplicate_item] % {type_names: type_names.join("\n")}
					end
				end
			end
		end
	end

	#noinspection RubyResolve
	def function_station_info(_, _, command, _)
		if COMMAND_STATION_INFO =~ command
			system_name = $~[:system_name]
			stations = @db.execute(SQL_SELECT_STATIONS, system_name)
			if stations.empty?
				@responses[:no_system] % {system_name: system_name}
			else
				@responses[:display_stations] % {
					system_name: system_name,
					station_names: stations.map! { |row| "#{row[0]}\n　#{row[1]}" }.join("\n"),
				}
			end
		end
	end

	#noinspection RubyResolve
	def function_solar_system_info(_, _, command, _)
		if COMMAND_SYSTEM_INFO =~ command
			system_name = $~[:system_name]
			system = @db.get_first_row(SQL_SELECT_SOLAR_SYSTEM, system_name)
			if system
				@responses[:display_system] % {
					system_name: system[0],
					system_name_zh: system[1],
					faction_name: system[2],
					security: system[3],
				}
			else
				@responses[:no_system] % {system_name: system_name}
			end
		end
	end

	#noinspection RubyResolve
	def function_faction_info(_, _, command, _)
		if COMMAND_FACTION_INFO =~ command
			faction_name = $~[:faction_name]
			faction = @db.get_first_row(SQL_SELECT_FACTION, faction_name + '%')
			if faction
				@responses[:display_faction] % {
					faction_name: faction[0],
					faction_name_zh: faction[1],
					faction_name_ja: faction[2],
					station_count: faction[3],
					description: faction[4],
				}
			else
				@responses[:no_faction] % {faction_name: faction_name}
			end
		end
	end
end