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
	VERSION = '2.2'
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
	COMMAND_FACTION_INFO = /^势力\s*(?<faction_name>.+)/
	COMMAND_RACE_INFO = /^种族\s*(?<race_name>.+)/
	COMMAND_MARKET = /^市场\s*(?<item_name>.+)/

	URI_MINERAL = 'http://www.ceve-market.org/api/evemon'

	XPATH_MINERAL = 'minerals/mineral'

	PATTERN_THOUSAND_SEPARATOR = /(?<=\d)(?=(\d\d\d)+\.)/

	DB_FILE = file_path('pluginEVE.db')

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
	def item_info(type_id, type_name, type_name_zh, type_name_ja, description, mass, volume)
		attributes = @db.execute(<<SQL, type_id)
SELECT "attributes"."displayName_ZH", "value", "units"."displayName_ZH"
FROM
	"typeAttributes"
	JOIN "attributes"
		ON "typeAttributes"."attributeID" = "attributes"."attributeID"
	JOIN "units"
		ON "attributes"."unitID" = "units"."unitID"
WHERE
	"typeAttributes"."typeID" = ?1
	AND "attributes"."displayName_ZH" IS NOT NULL
SQL
		@responses[:display_item] % {
			type_name: type_name,
			type_name_zh: type_name_zh,
			type_name_ja: type_name_ja,
			description: description,
			mass: mass,
			volume: volume,
			attributes: attributes.map{ |attribute_name, value, unit_name| "#{attribute_name}：#{value} #{unit_name}"}.join("\n"),
		}
	end

	#noinspection RubyResolve
	def function_item_info(_, _, command, _)
		if COMMAND_ITEM_INFO =~ command
			item_name = $~[:item_name]
			types = @db.get_first_row(<<SQL, item_name)
SELECT
	"typeID",
	"typeName",
	"typeName_ZH",
	"typeName_JA",
	"description_ZH",
	"mass",
	"volume"
FROM
	"types"
WHERE
	"typeName" = ?1
	OR "typeName_ZH" = ?1
	OR "typeName_JA" = ?1
SQL
			if types
				item_info(*types)
			else
				types = @db.execute(<<SQL, item_name + '%')
SELECT
	"typeID",
	"typeName",
	"typeName_ZH",
	"typeName_JA",
	"description_ZH",
	"mass",
	"volume"
FROM
	"types"
WHERE
	"typeName" LIKE ?1
	OR "typeName_ZH" LIKE ?1
	OR "typeName_JA" LIKE ?1
SQL
				case types.length
				when 0
					@responses[:no_item] % {item_name: item_name}
				when 1
					item_info(*types[0])
				else
					type_names = types.map! do |_, type_name, type_name_zh, type_name_ja, _, _, _|
						"#{type_name} ／ #{type_name_zh} ／ #{type_name_ja}"
					end
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
			types = @db.get_first_row(<<SQL, item_name)
SELECT
	"typeID",
	"typeName",
	"typeName_ZH",
	"typeName_JA"
FROM
	"marketTypes"
WHERE
	"typeName" = ?1
	OR "typeName_ZH" = ?1
	OR "typeName_JA" = ?1
SQL
			if types
				format_market_result(*types)
			else
				types = @db.execute(<<SQL, item_name + '%')
SELECT
	"typeID",
	"typeName",
	"typeName_ZH",
	"typeName_JA"
FROM
	"marketTypes"
WHERE
	"typeName" LIKE ?1
	OR "typeName_ZH" LIKE ?1
	OR "typeName_JA" LIKE ?1
SQL
				case types.length
				when 0
					@responses[:no_item] % {item_name: item_name}
				when 1
					format_market_result(*types[0])
				else
					type_names = types.map! do |_, type_name, type_name_zh, type_name_ja|
						"#{type_name} ／ #{type_name_zh} ／ #{type_name_ja}"
					end
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
			stations = @db.execute(<<SQL, system_name)
SELECT
	"stationName_ZH"
FROM
	"stations"
WHERE
	"solarSystemID" = (
		SELECT
			"solarSystemID"
		FROM
			"solarSystems"
		WHERE
			"solarSystemName" = ?1
			OR "solarSystemName_ZH" = ?1
			OR "solarSystemName_JP" = ?1
	)
SQL
			if stations.empty?
				@responses[:no_system] % {system_name: system_name}
			else
				@responses[:display_stations] % {
					system_name: system_name,
					station_names: stations.map! { |row| "#{row[0]}" }.join("\n"),
				}
			end
		end
	end

	#noinspection RubyResolve
	def function_solar_system_info(_, _, command, _)
		if COMMAND_SYSTEM_INFO =~ command
			system_name = $~[:system_name]
			system = @db.get_first_row(<<SQL, system_name)
SELECT
	"solarSystems"."solarSystemName",
	"solarSystems"."solarSystemName_ZH",
	"factions"."factionName_ZH",
	"solarSystems"."security"
FROM
	"solarSystems"
	JOIN "factions"
		ON "solarSystems"."factionID" = "factions"."factionID"
WHERE
	"solarSystems"."solarSystemName" = ?1
	OR "solarSystems"."solarSystemName_ZH" = ?1
SQL
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
			faction = @db.get_first_row(<<SQL, faction_name + '%')
SELECT
	"factionName",
	"factionName_ZH",
	"factionName_JA",
	"stationCount",
	"solarSystemCount",
	"description",
	"description_ZH",
	"description_JA"
FROM
	"factions"
WHERE
	"factionName" LIKE ?1
	OR "factionName_ZH" LIKE ?1
	OR "factionName_JA" LIKE ?1
SQL
			if faction
				@responses[:display_faction] % {
					faction_name: faction[0],
					faction_name_zh: faction[1],
					faction_name_ja: faction[2],
					station_count: faction[3],
					solar_system_count: faction[4],
					description: faction[5],
					description_zh: faction[6],
					description_ja: faction[7],
				}
			else
				@responses[:no_faction] % {faction_name: faction_name}
			end
		end
	end

	#noinspection RubyResolve
	def function_race_info(_, _, command, _)
		if COMMAND_RACE_INFO =~ command
			race_name = $~[:race_name]
			race = @db.get_first_row(<<SQL, race_name + '%')
SELECT
	"raceName",
	"raceName_ZH",
	"raceName_JA",
	"description",
	"description_ZH",
	"description_JA"
FROM
	"races"
WHERE
	"raceName" LIKE ?1
	OR "raceName_ZH" LIKE ?1
	OR "raceName_JA" LIKE ?1
SQL
			if race
				@responses[:display_race] % {
					race_name: race[0],
					race_name_zh: race[1],
					race_name_ja: race[2],
					description: race[3],
					description_zh: race[4],
					description_ja: race[5],
				}
			else
				@responses[:no_race] % {race_name: race_name}
			end
		end
	end
end