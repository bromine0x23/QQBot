#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require_relative 'plugin'

require 'logger'
require 'sqlite3'

class PluginChatLogger < PluginResponserBase
	NAME = '消息记录插件'
	AUTHOR = 'BR'
	VERSION = '1.3'
	DESCRIPTION = '记记记记记'
	MANUAL = <<MANUAL
记记记记记
MANUAL
	PRIORITY = 16

	TABLE_MESSAGES = 'messages'

	SQL_CREATE_TABLE_MESSAGES = <<SQL
CREATE TABLE messages (
	id           INTEGER PRIMARY KEY AUTOINCREMENT,
	message_type INTEGER,
	from_number  INTEGER,
	from_name    TEXT,
	send_number  INTEGER,
	send_name    TEXT,
	message      TEXT,
	created_at   TIMESTAMP
)
SQL

	SQL_CHECK_TABLE = <<SQL
SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name = ?
SQL

	SQL_INSERT_MESSAGE = <<SQL
INSERT INTO messages (
	message_type,
	from_number,
	from_name,
	send_number,
	send_name,
	message,
	created_at
) VALUES (?, ?, ?, ?, ?, ?, ?)
SQL

	DB_FILE = File.expand_path(File.dirname(__FILE__) + '/pluginChatLogger.db')

	TYPEID_MESSAGE       = 0
	TYPEID_GROUP_MESSAGE = 1

	def on_load
		super
		log('连接数据库……')
		@db = SQLite3::Database.open DB_FILE
		@db.execute SQL_CREATE_TABLE_MESSAGES if @db.get_first_value(SQL_CHECK_TABLE, TABLE_MESSAGES).zero?
	end

	def on_unload
		super
		log('断开数据库连接')
		@db.close
	end

	def deal_message(uin, sender_qq, sender_nickname, content, time)
		@db.transaction do |db|
			db.execute SQL_INSERT_MESSAGE, TYPEID_MESSAGE, sender_qq, sender_nickname, sender_qq, sender_nickname, QQBot.message(content), time
		end
		nil
	end

	def deal_group_message(guin, sender_qq, sender_nickname, content, time)
		group = @qqbot.group(guin)
		@db.transaction do |db|
			db.execute SQL_INSERT_MESSAGE, TYPEID_GROUP_MESSAGE, group.group_number, group.group_name, sender_qq, sender_nickname, QQBot.message(content), time
		end
		nil
	end
end