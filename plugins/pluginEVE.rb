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
	VERSION = '2.4'
	DESCRIPTION = '我们的征途的星辰大海'
	MANUAL = <<MANUAL.strip
== 吉他价格查询 ==
EVE 星系 <星系> # 查询星系信息
EVE 空间站 <空间站> # 查询空间站信息
EVE 势力 <势力> # 查询势力信息
EVE 种族 <种族> # 查询种族信息
EVE 物品 <物品> # 查询物品信息
EVE 市场 <物品> # 查询物品市场价格
EVE 矿物 # 查询市场矿物价格
MANUAL
	PRIORITY = 0

	COMMAND_HEADER = 'EVE'

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
		price.round(2).to_s.gsub(/(?<=\d)(?=(\d\d\d)+\.)/, @thousand_separator)
	end

	#noinspection RubyResolve
	def function_mineral(_, _, command, _)
		if /^矿物$/ =~ command
			response = ''
			REXML::Document.new(Net::HTTP.get(URI('http://www.ceve-market.org/api/evemon'))).each_element('minerals/mineral') do |element|
				response << <<RESPONSE
#{element[0].text}：#{format_price(element[1].text)} #{@units[:price]}
RESPONSE
			end
			response
		end
	end

	#noinspection RubyResolve
	def solar_system_info(solar_system_id, solar_system_name, solar_system_name_zh, faction_name, faction_name_zh, faction_name_ja, security)
		station_names = @db.execute(<<SQL, solar_system_id)
SELECT
	"stationName", "stationName_ZH"
FROM
	"stations"
WHERE
	"solarSystemID" = ?1
SQL
		@responses[:display_solar_system] % {
			solar_system_name:
				@format[:solar_system_name] % {
					solar_system_name: solar_system_name,
					solar_system_name_zh: solar_system_name_zh
				},
			faction_name: (
			if faction_name
				@format[:faction_name] % {
					faction_name: faction_name,
					faction_name_zh: faction_name_zh,
					faction_name_ja: faction_name_ja
				}
			else
				@format[:faction_name_none]
			end
			),
			security: security,
			station_names: (
				if station_names.empty?
					@format[:station_names_none]
				else
					station_names.map! { |station_name, station_name_zh|
						@format[:station_name] % {
							station_name: station_name,
							station_name_zh: station_name_zh
						}
					}.join("\n")
				end
			)
		}
	end

	#noinspection RubyResolve,RubyScope
	def function_solar_system_info(_, _, command, _)
		if /^星系\s*(?<query_name>.+)/ =~ command
			solar_system = @db.get_first_row(<<SQL, query_name)
SELECT
	"solarSystemID",
	"solarSystemName", "solarSystemName_ZH",
	"factionName", "factionName_ZH", "factionName_JA",
	"security"
FROM
	"solarSystems" LEFT JOIN "factions" ON "solarSystems"."factionID" = "factions"."factionID"
WHERE
	"solarSystemName" = ?1 OR "solarSystemName_ZH" = ?1
SQL
			if solar_system
				solar_system_info(*solar_system)
			else
				solar_systems = @db.execute(<<SQL, query_name + '%')
SELECT
	"solarSystemID",
	"solarSystemName", "solarSystemName_ZH",
	"factionName", "factionName_ZH", "factionName_JA",
	"security"
FROM
	"solarSystems" LEFT JOIN "factions" ON "solarSystems"."factionID" = "factions"."factionID"
WHERE
	"solarSystemName" LIKE ?1 OR "solarSystemName_ZH" LIKE ?1
SQL
				case solar_systems.size
				when 0
					@responses[:no_query_solar_system] % {query_name: query_name}
				when 1
					solar_system_info(*solar_systems.first)
				else
					solar_system_names = solar_systems.sample(@duplicate_display_door).map do |_, solar_system_name, solar_system_name_zh, _|
						@format[:solar_system_name] % {
							solar_system_name: solar_system_name,
							solar_system_name_zh: solar_system_name_zh
						}
					end
					@responses[
						if solar_systems.length > @duplicate_display_door
							:duplicate_solar_system_more
						else
							:duplicate_solar_system
						end
					] % {
						solar_system_names: solar_system_names.join("\n")
					}
				end

			end
		end
	end

	#noinspection RubyResolve
	def station_info(station_id, station_name, station_name_zh, operation_id, operation_name, operation_name_zh, operation_name_ja)
		service_names = @db.execute(<<SQL, operation_id)
SELECT
	"serviceName", "serviceName_ZH", "serviceName_JA"
FROM
	"operationServices" JOIN "services" ON "operationServices"."serviceID" = "services"."serviceID"
WHERE
	"operationID" = ?1
SQL
		@responses[:display_station] % {
			station_name: @format[:station_name] % {
				station_name: station_name,
				station_name_zh: station_name_zh
			},
			operation_name: @format[:operation_name] % {
				operation_name: operation_name,
				operation_name_zh: operation_name_zh,
				operation_name_ja: operation_name_ja
			},
			service_names: service_names.map! { |service_name, service_name_zh, service_name_ja|
				@format[:service_name] % {
					service_name: service_name,
					service_name_zh: service_name_zh,
					service_name_ja: service_name_ja,
				}
			}.join(' ／ ')
		}
	end

	#noinspection RubyResolve
	def function_station_info(_, _, command, _)
		if /^空间站\s*(?<query_name>.+)/ =~ command
			station = @db.get_first_row(<<SQL, query_name)
SELECT
	"stationID",
	"stationName", "stationName_ZH",
	"stations"."operationID",
	"operationName", "operationName_ZH", "operationName_JA"
FROM
	"stations" JOIN "operations" ON "stations"."operationID" = "operations"."operationID"
WHERE
	"stationName" = ?1 OR "stationName_ZH" = ?1
SQL
			if station
				station_info(*station)
			else
				stations = @db.execute(<<SQL, query_name + '%')
SELECT
	"stationID",
	"stationName", "stationName_ZH",
	"stations"."operationID",
	"operationName", "operationName_ZH", "operationName_JA"
FROM
	"stations" JOIN "operations" ON "stations"."operationID" = "operations"."operationID"
WHERE
	"stationName" LIKE ?1 OR "stationName_ZH" LIKE ?1
SQL
				case stations.length
				when 0
					@responses[:no_query_station] % {query_name: query_name}
				when 1
					station_info(*stations.first)
				else
					station_names = stations.sample(@duplicate_display_door).map do |_, station_name, station_name_zh, _|
						@format[:station_name] % {
							station_name: station_name,
							station_name_zh: station_name_zh
						}
					end
					@responses[
						if stations.length > @duplicate_display_door
							:duplicate_station_more
						else
							:duplicate_station
						end
					] % {
						station_names: station_names.join("\n")
					}
				end
			end
		end
	end

	#noinspection RubyResolve
	def function_faction_info(_, _, command, _)
		if /^势力\s*(?<query_name>.+)/ =~ command
				faction_name, faction_name_zh, faction_name_ja,
				description, description_zh, description_ja,
				station_count, solar_system_count = @db.get_first_row(<<SQL, query_name + '%')
SELECT
	"factionName", "factionName_ZH", "factionName_JA",
	"description", "description_ZH", "description_JA",
	"stationCount", "solarSystemCount"
FROM
	"factions"
WHERE
	"factionName" LIKE ?1 OR "factionName_ZH" LIKE ?1 OR "factionName_JA" LIKE ?1
SQL
			if faction_name
				@responses[:display_faction] % {
					faction_name: @format[:faction_name] % {
						faction_name: faction_name,
						faction_name_zh: faction_name_zh,
						faction_name_ja: faction_name_ja
					},
					description: (
						if description
							@format[:description] % {
								description: description,
								description_zh: description_zh,
								description_ja: description_ja
							}
						else
							@format[:description_none]
						end
					),
					station_count: station_count,
					solar_system_count: solar_system_count,
				}
			else
				@responses[:no_query_faction] % {query_name: query_name}
			end
		end
	end

	#noinspection RubyResolve
	def function_race_info(_, _, command, _)
		if /^种族\s*(?<query_name>.+)/ =~ command
			race_name, race_name_zh, race_name_ja,
				description, description_zh, description_ja = @db.get_first_row(<<SQL, query_name + '%')
SELECT
	"raceName",    "raceName_ZH",    "raceName_JA",
	"description", "description_ZH", "description_JA"
FROM
	"races"
WHERE
	"raceName" LIKE ?1 OR "raceName_ZH" LIKE ?1 OR "raceName_JA" LIKE ?1
SQL
			if race_name
				@responses[:display_race] % {
					race_name: @format[:race_name] % {
						race_name: race_name,
						race_name_zh: race_name_zh,
						race_name_ja: race_name_ja
					},
					description: (
						if description
							@format[:description] % {
								description: description,
								description_zh: description_zh,
								description_ja: description_ja
							}
						else
							@format[:description_none]
						end
					),
				}
			else
				@responses[:no_query_race] % {query_name: query_name}
			end
		end
	end

	#noinspection RubyResolve
	def item_info(type_id, type_name, type_name_zh, type_name_ja, description, description_zh, description_ja, mass, volume)
		attributes = @db.execute(<<SQL, type_id)
SELECT
	"attributes"."displayName_ZH", "value", "units"."displayName_ZH"
FROM
	"typeAttributes"
	JOIN "attributes" ON "typeAttributes"."attributeID" = "attributes"."attributeID"
	JOIN "units" ON "attributes"."unitID" = "units"."unitID"
WHERE
	"typeAttributes"."typeID" = ?1 AND "attributes"."displayName_ZH" IS NOT NULL
SQL
		@responses[:display_item] % {
			type_name: @format[:type_name] % {
				type_name: type_name,
				type_name_zh: type_name_zh,
				type_name_ja: type_name_ja
			},
			description: (
			if description
				@format[:description] % {
					description: description,
					description_zh: description_zh,
					description_ja: description_ja
				}
			else
				@format[:description_none]
			end
			),
			mass: mass,
			volume: volume,
			attributes: attributes.map{ |attribute_name, value, unit_name|
				@format[:attribute] % {
					attribute_name: attribute_name,
					value: value,
					unit_name: unit_name,
				}
			}.join("\n"),
		}
	end

	#noinspection RubyResolve,RubyScope
	def function_item_info(_, _, command, _)
		if /^物品\s*(?<query_name>.+)/ =~ command
			type = @db.get_first_row(<<SQL, query_name)
SELECT
	"typeID",
	"typeName", "typeName_ZH", "typeName_JA",
	"description", "description_ZH", "description_JA",
	"mass", "volume"
FROM
	"types"
WHERE
	"typeName" = ?1 OR "typeName_ZH" = ?1 OR "typeName_JA" = ?1
SQL
			if type
				item_info(*type)
			else
				types = @db.execute(<<SQL, query_name + '%')
SELECT
	"typeID",
	"typeName", "typeName_ZH", "typeName_JA",
	"description", "description_ZH", "description_JA",
	"mass", "volume"
FROM
	"types"
WHERE
	"typeName" LIKE ?1 OR "typeName_ZH" LIKE ?1 OR "typeName_JA" LIKE ?1
SQL
				case types.length
				when 0
					@responses[:no_query_item] % {query_name: query_name}
				when 1
					item_info(*types.first)
				else
					type_names = types.sample(@duplicate_display_door).map! do |_, type_name, type_name_zh, type_name_ja, _|
						@format[:type_name] % {
							type_name: type_name,
							type_name_zh: type_name_zh,
							type_name_ja: type_name_ja
						}
					end
					@responses[
						if types.length > @duplicate_display_door
							:duplicate_item_more
						else
							:duplicate_item
						end
					] % {
						type_names: type_names.join("\n")
					}
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
			type_name: @format[:type_name] % {
				type_name: type_name,
				type_name_zh: type_name_zh,
				type_name_ja: type_name_ja
			},
			buy_price: buy ? format_price(buy) + @units[:price] : @responses[:no_price],
			sell_price: sell ? format_price(sell) + @units[:price] : @responses[:no_price],
		}
	end

	#noinspection RubyResolve,RubyScope
	def function_market(_, _, command, _)
		if /^市场\s*(?<query_name>.+)/ =~ command
			type = @db.get_first_row(<<SQL, query_name)
SELECT
	"typeID",
	"typeName", "typeName_ZH", "typeName_JA"
FROM
	"marketTypes"
WHERE
	"typeName" = ?1 OR "typeName_ZH" = ?1 OR "typeName_JA" = ?1
SQL
			if type
				format_market_result(*type)
			else
				types = @db.execute(<<SQL, query_name + '%')
SELECT
	"typeID",
	"typeName", "typeName_ZH", "typeName_JA"
FROM
	"marketTypes"
WHERE
	"typeName" LIKE ?1 OR "typeName_ZH" LIKE ?1 OR "typeName_JA" LIKE ?1
SQL
				case types.length
				when 0
					@responses[:no_query_item] % {query_name: query_name}
				when 1
					format_market_result(*types.first)
				else
					type_names = types.sample(@duplicate_display_door).map! do |_, type_name, type_name_zh, type_name_ja, _|
						@format[:type_name] % {
							type_name: type_name,
							type_name_zh: type_name_zh,
							type_name_ja: type_name_ja
						}
					end
					@responses[
						if types.length > @duplicate_display_door
							:duplicate_item_more
						else
							:duplicate_item
						end
					] % {
						type_names: type_names.join("\n")
					}
				end
			end
		end
	end
end