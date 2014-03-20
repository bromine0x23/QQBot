#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require_relative 'plugin'

require 'sqlite3'

class PluginAI < PluginNicknameResponserBase
	NAME = 'AI插件'
	AUTHOR = 'BR'
	VERSION = '1.9'
	DESCRIPTION = '人家才不是AI呢'
	MANUAL = <<MANUAL.strip!
== 复述 ==
说 <复述内容>
== 整句学习 ==
================
学习 <行内句子1> <行内句子2>
================
学习
<单行句子1>
<多行句子2>
================
学习=<分界符>
<多行句子1>
<分界符>
<多行句子2>
================
忘记 <句子>
MANUAL
	PRIORITY = -8

	DB_FILE = file_path __FILE__, 'pluginAI.db'

	SQL_CREATE_TABLE_MESSAGES = <<SQL
CREATE TABLE messages (
	id         INTEGER PRIMARY KEY AUTOINCREMENT,
	message    TEXT NOT NULL,
	created_at TIMESTAMP
)
SQL

	SQL_CREATE_TABLE_RESPONSES = <<SQL
CREATE TABLE responses (
	id         INTEGER PRIMARY KEY AUTOINCREMENT,
	message_id INTEGER REFERENCES messages (id),
	response   TEXT,
	created_by INTEGER NOT NULL,
	created_at TIMESTAMP
)
SQL

	SQL_CREATE_INDEX_ON_RESPONSES = <<SQL
CREATE INDEX index_message_id ON responses (message_id)
SQL

	SQL_CHECK_TABLE = <<SQL
SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name = ?
SQL

	SQL_GET_MESSAGE_ID = <<SQL
SELECT id
FROM messages
WHERE message = ?
SQL

	SQL_GET_RESPONSES = <<SQL
SELECT response
FROM responses
WHERE message_id IN (
	SELECT id
	FROM messages
	WHERE message = ?
)
SQL

	SQL_SET_MESSAGE = <<SQL
INSERT INTO messages (message, created_at) VALUES (?, ?)
SQL

	SQL_SET_RESPONSE = <<SQL
INSERT INTO responses (message_id, response, created_by, created_at)
SELECT id, ?, ?, ?
FROM messages
WHERE message = ?
SQL

	SQL_REMOVE_RESPONSES = <<SQL
DELETE
FROM responses
WHERE message_id IN (
	SELECT id
	FROM messages
	WHERE message = ?
)
SQL

	TABLE_MESSAGES  = 'messages'
	TABLE_RESPONSES = 'responses'

	COMMAND_SAY             = /^说(?<response>.*)/m
	COMMAND_FORGET          = /^忘记(?<message>.*)/m
	COMMAND_LEARN           = /^学习(?<command>.*)/m
	COMMAND_BLACKLIST       = /^(\d+)\s*是坏人$/
	COMMAND_LEARN_ONELINE   = /^ (?<message>\S+) +(?<response>.+)/
	COMMAND_LEARN_TOWLINE   = /^[\r\n](?<message>[^\r\n]+)[\r\n]+(?<response>.+)/m
	COMMAND_LEARN_MULTILINE = /^=(?<delimiter>\w+)\s*[\r\n](?<message>.+?)[\r\n]\k<delimiter>(?<response>.+)/m

	RESPONSE_TOOLONG      = %w(那太长了…… 这么长人家完全记不住嘛 好长……)
	RESPONSE_LEARNED      = %w(诶……是这样嘛? 了解了 哦，原来如此 恩 了解)
	RESPONSE_FORGETED     = %w(Accept 记忆已清除)
	RESPONSE_NULL         = %w(喵 喵呜 汪)
	RESPONSE_UNKOWN_ERROR = %w(未知错误 好像哪里不对)
	RESPONSE_DOOR = 512

	def on_load
		# super # FOR DEBUG
		@db = SQLite3::Database.open DB_FILE
		@db.execute SQL_CREATE_TABLE_MESSAGES if @db.get_first_value(SQL_CHECK_TABLE, TABLE_MESSAGES).zero?
		if @db.get_first_value(SQL_CHECK_TABLE, TABLE_RESPONSES).zero?
			@db.execute SQL_CREATE_TABLE_RESPONSES
			@db.execute SQL_CREATE_INDEX_ON_RESPONSES
		end
		log('数据库连接完毕')
	end

	def on_unload
		# super # FOR DEBUG
		log('断开数据库连接')
		@db.close
	end

	def get_response(uin, sender_qq, sender_nickname, message, time)
		# super # FOR DEBUG
		if COMMAND_SAY =~ message
			$~[:response]
		elsif COMMAND_FORGET =~ message
			forget $~[:message].strip
			RESPONSE_FORGETED.sample
		elsif COMMAND_LEARN =~ message
			command = $~[:command]
			if COMMAND_LEARN_MULTILINE =~ command or COMMAND_LEARN_TOWLINE =~ command or COMMAND_LEARN_ONELINE =~ command
				response = $~[:response].strip
				if response.length < RESPONSE_DOOR
					learn $~[:message].strip, response, sender_qq
					RESPONSE_LEARNED.sample
				else
					RESPONSE_TOOLONG.sample
				end
			end
		else
			response(message, sender_nickname)
		end
	end

	def learn(message, response, created_by)
		@db.transaction do |db|
			time = Time.now.to_i
			unless db.get_first_value SQL_GET_MESSAGE_ID, message
				db.execute SQL_SET_MESSAGE, message, time
			end
			db.execute SQL_SET_RESPONSE, response, created_by, time, message
		end
	end

	def forget(message, _ = nil)
		@db.transaction do |db|
			db.execute SQL_REMOVE_RESPONSES, message
		end
	end

	PLACEHOLDER_I = '{我}'
	PLACEHOLDER_YOU = '{你}'

	def response(message, sender_nickname)
		result = @db.execute(SQL_GET_RESPONSES, message).map!{ |row| row[0] }.sample
		result.gsub(/\{我\}|\{你\}/, PLACEHOLDER_I => bot_name, PLACEHOLDER_YOU => sender_nickname) if result
	end
end