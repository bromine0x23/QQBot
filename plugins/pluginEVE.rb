#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require_relative 'plugin'

require 'yaml'
require 'json'
require 'net/http'
require 'uri'

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
EVE市场 <物品>（用逗号(,，)分割）
MANUAL
	PRIORITY = 0

	CONFIG_FILE = File.expand_path(File.dirname(__FILE__) + '/pluginEVE.yaml')
	COMMAND_PATTERN = /^EVE\s*市场\s*(?<item_names>.+)/i

	URI_FORMAT = 'http://www.ceve-market.org/api/market/region/10000002/system/30000142/type/%d.json'

	KEY_BUY = 'buy'
	KEY_SELL = 'sell'
	KEY_MAX = 'max'
	KEY_MIN = 'min'
	PRICE_PATTERN = '%.2f'
	NO_PRICE = '暂无出价'

	PATTERN_ITEM_NAMES_SEPARATOR = /,|，/
	PATTERN_THOUSAND_SEPARATOR = /(?<=\d)(?=(\d\d\d)+\.)/
	THOUSAND_SEPARATOR = ','

	def on_load
		super
		log('加载物品名数据……')
		@items = YAML.load_file(CONFIG_FILE)
		log('加载完毕')
	end

	def get_response(uin, sender_qq, sender_nickname, message, time)
		super
		if COMMAND_PATTERN =~ message
			response = <<RESPONSE
回 #{sender_nickname} 大人：
RESPONSE
			$~[:item_names].split(PATTERN_ITEM_NAMES_SEPARATOR).each do |item_name|
				response << if @items.has_key? item_name
					data = JSON.parse(Net::HTTP.get(URI(URI_FORMAT % @items[item_name])))
					buy, sell = data[KEY_BUY][KEY_MAX], data[KEY_SELL][KEY_MIN]
					<<RESPONSE
#{item_name} 吉他报价
求购：#{buy  ? ( buy.round(2).to_s).gsub(PATTERN_THOUSAND_SEPARATOR, THOUSAND_SEPARATOR) : NO_PRICE} ISK
出售：#{sell ? (sell.round(2).to_s).gsub(PATTERN_THOUSAND_SEPARATOR, THOUSAND_SEPARATOR) : NO_PRICE} ISK
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