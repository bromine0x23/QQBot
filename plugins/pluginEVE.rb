#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require_relative 'plugin'

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
	VERSION = '1.3'
	DESCRIPTION = '我们的征途的星辰大海'
	MANUAL = <<MANUAL
== 吉他价格查询 ==
EVE 市场 <物品>（用逗号(,，)分割）
EVE 基础矿物
MANUAL
	PRIORITY = 0

	CONFIG_FILE = File.expand_path(File.dirname(__FILE__) + '/pluginEVE.yaml')
	
	COMMAND_PATTERN = /^EVE\s*(?<command>.+)/i
	MARKET_PATTERN  = /^市场\s*(?<item_names>.+)/i
	MINERAL_PATTERN = /^基础矿物$/i

	URI_MARKET  = 'http://www.ceve-market.org/api/market/region/10000002/system/30000142/type/%d.json'
	URI_MINERAL = 'http://www.ceve-market.org/api/evemon'

	KEY_BUY  = 'buy'
	KEY_SELL = 'sell'
	KEY_MAX  = 'max'
	KEY_MIN  = 'min'

	NO_PRICE = '暂无出价'

	XPATH_MINERAL = 'minerals/mineral'

	PATTERN_ITEM_NAMES_SEPARATOR = /,|，/
	PATTERN_THOUSAND_SEPARATOR = /(?<=\d)(?=(\d\d\d)+\.)/
	THOUSAND_SEPARATOR = ','

	def on_load
		super
		log('加载物品名数据……')
		@items = YAML.load_file(CONFIG_FILE)
		log('加载完毕')
	end

	def fix_price(price)
		price.gsub(PATTERN_THOUSAND_SEPARATOR, THOUSAND_SEPARATOR)
	end

	def get_response(uin, sender_qq, sender_nickname, message, time)
		super
		if COMMAND_PATTERN =~ message
			command = $~[:command]
			if MINERAL_PATTERN =~ command
				response = response_header_with_nickname(sender_nickname)
				REXML::Document.new(Net::HTTP.get(URI(URI_MINERAL))).each_element(XPATH_MINERAL) do |element|
					response << <<RESPONSE
#{element[0].text}：#{fix_price(element[1].text)} ISK
RESPONSE
				end
				response
			elsif MARKET_PATTERN =~ command 
				response = <<RESPONSE
回 #{sender_nickname} 大人：
RESPONSE
				$~[:item_names].split(PATTERN_ITEM_NAMES_SEPARATOR).each do |item_name|
					response << if @items.has_key? item_name
						data = JSON.parse(Net::HTTP.get(URI(URI_MARKET % @items[item_name])))
						buy, sell = data[KEY_BUY][KEY_MAX], data[KEY_SELL][KEY_MIN]
						<<RESPONSE
#{item_name} 吉他报价
求购：#{buy  ? fix_price( buy.round(2).to_s) : NO_PRICE} ISK
出售：#{sell ? fix_price(sell.round(2).to_s) : NO_PRICE} ISK
RESPONSE
					else
						<<RESPONSE
不存在物品：#{item_name}
RESPONSE
					end
				end
				response
			end
		end
	end
end