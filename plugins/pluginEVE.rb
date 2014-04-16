#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require 'yaml'
require 'json'
require 'net/http'
require 'uri'
require 'rexml/document'

=begin
使用EVE国服市场中心的物价查询API
参见：http://www.ceve-market.org/api/
=end
class PluginEVE < PluginNicknameResponserBase
	NAME = 'EVE插件'
	AUTHOR = 'BR'
	VERSION = '1.5'
	DESCRIPTION = '我们的征途的星辰大海'
	MANUAL = <<MANUAL.strip
== 吉他价格查询 ==
EVE 市场 <物品>（用逗号(,，)分割）
EVE 基础矿物
MANUAL
	PRIORITY = 0

	CONFIG_FILE = file_path __FILE__, 'pluginEVE.data'
	
	COMMAND_PATTERN = /^EVE\s*(?<command>.+)/i
	MARKET_PATTERN  = /^市场\s*(?<item_names>.+)/
	MINERAL_PATTERN = /^基础矿物$/i

	URI_MINERAL = 'http://www.ceve-market.org/api/evemon'

	JSON_KEY_BUY, JSON_KEY_SELL  = 'buy', 'sell'
	JSON_KEY_MAX, JSON_KEY_MIN  = 'max', 'min'

	NO_PRICE = '暂无出价'

	XPATH_MINERAL = 'minerals/mineral'

	PATTERN_ITEM_NAMES_SEPARATOR = /,|，/
	PATTERN_THOUSAND_SEPARATOR = /(?<=\d)(?=(\d\d\d)+\.)/
	THOUSAND_SEPARATOR = ','

	def on_load
		# super # FOR DEBUG
		@items = YAML.load_file CONFIG_FILE
		log('物品名数据加载完毕', Logger::DEBUG) if $-d
	end

	def format_price(price)
		price.gsub(PATTERN_THOUSAND_SEPARATOR, THOUSAND_SEPARATOR)
	end

	def get_response(uin, sender_qq, sender_nickname, message, time)
		# super # FOR DEBUG

		if COMMAND_PATTERN =~ message
			command = $~[:command]
			if MINERAL_PATTERN =~ command
				response = self.response_header_with_nickname(sender_nickname)
				REXML::Document.new(Net::HTTP.get(URI(URI_MINERAL))).each_element(XPATH_MINERAL) do |element|
					response << <<RESPONSE
#{element[0].text}：#{format_price(element[1].text)} ISK
RESPONSE
				end
				response
			elsif MARKET_PATTERN =~ command 
				response = response_header_with_nickname sender_nickname
				$~[:item_names].split(PATTERN_ITEM_NAMES_SEPARATOR).each do |item_name|
					if @items.has_key? item_name
						json_data = JSON.parse(Net::HTTP.get(URI("http://www.ceve-market.org/api/market/region/10000002/system/30000142/type/#{@items[item_name]}.json")))
						buy  = json_data[JSON_KEY_BUY][JSON_KEY_MAX]
						sell = json_data[JSON_KEY_SELL][JSON_KEY_MIN]
						response << <<RESPONSE
#{item_name} 吉他报价
求购：#{buy  ? format_price( buy.round(2).to_s) : NO_PRICE} ISK
出售：#{sell ? format_price(sell.round(2).to_s) : NO_PRICE} ISK
RESPONSE
					else
						response << <<RESPONSE
不存在物品：#{item_name}
RESPONSE
					end
				end
				response
			end
		end
	end
end