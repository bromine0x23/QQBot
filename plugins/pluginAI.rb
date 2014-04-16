#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require 'sqlite3'

class PluginAI < PluginNicknameResponserBase
	NAME = 'AI插件'
	AUTHOR = 'BR'
	VERSION = '1.11'
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

	DB_FILE = "#{PLUGIN_DIRECTORY}/pluginAI.db"

	SQL_CREATE_TABLE_MESSAGES = <<SQL
CREATE TABLE messages (
	id         INTEGER PRIMARY KEY AUTOINCREMENT,
	message    TEXT NOT NULL,
	created_by INTEGER NOT NULL,
	created_at TIMESTAMP,
	CONSTRAINT uc_message UNIQUE (message)
)
SQL

	SQL_CREATE_TABLE_RESPONSES = <<SQL
CREATE TABLE responses (
	id         INTEGER PRIMARY KEY AUTOINCREMENT,
	response   TEXT NOT NULL,
	created_by INTEGER NOT NULL,
	created_at TIMESTAMP,
	CONSTRAINT uc_response UNIQUE (response)
)
SQL

	SQL_CREATE_TABLE_RELATIONS = <<SQL
CREATE TABLE relations (
	message_id  INTEGER REFERENCES messages (id),
	response_id INTEGER REFERENCES response (id),
	created_by  INTEGER NOT NULL,
	created_at  TIMESTAMP,
	CONSTRAINT pk_relation PRIMARY KEY (message_id, response_id)
)
SQL

	SQL_CREATE_INDEX_RELATIONS = <<SQL
CREATE INDEX index_message_id ON relations (message_id)
SQL

	SQL_CHECK_TABLE = <<SQL
SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name = ?
SQL

	SQL_GET_MESSAGE_ID = <<SQL
SELECT id FROM messages WHERE message = ?
SQL

	SQL_GET_RESPONSE_ID = <<SQL
SELECT id FROM responses WHERE response = ?
SQL

	SQL_INSERT_MESSAGE = <<SQL
INSERT OR IGNORE INTO messages (message, created_by, created_at) VALUES (?, ?, ?)
SQL

	SQL_INSERT_RESPONSE = <<SQL
INSERT OR IGNORE INTO responses (response, created_by, created_at) VALUES (?, ?, ?)
SQL

	SQL_INSERT_RELATION = <<SQL
INSERT OR IGNORE
	INTO relations (message_id, response_id, created_by, created_at)
	SELECT messages.id, responses.id, ?, ? FROM messages, responses WHERE message = ? AND response = ?
SQL

	SQL_SELECT_RESPONSES = <<SQL
SELECT response FROM responses
WHERE id = (
	SELECT response_id FROM relations
	WHERE message_id = (
		SELECT id FROM messages
		WHERE message = ?
	)
)
SQL

	SQL_DELETE_RELATIONS = <<SQL
DELETE FROM relations
WHERE message_id = (
	SELECT id FROM messages
	WHERE message = ?
)
SQL

	COMMAND_SAY             = /^说(?<response>.*)/m
	COMMAND_FORGET          = /^忘记(?<message>.*)/m
	COMMAND_LEARN           = /^学习(?<command>.*)/m
	COMMAND_BLACKLIST       = /^(\d+)\s*是坏人$/
	COMMAND_LEARN_ONELINE   = /^ (?<message>\S+) +(?<response>.+)/
	COMMAND_LEARN_TOWLINE   = /^[\r\n](?<message>[^\r\n]+)[\r\n]+(?<response>.+)/m
	COMMAND_LEARN_MULTILINE = /^=(?<delimiter>\w+)\s*[\r\n](?<message>.+?)[\r\n]\k<delimiter>(?<response>.+)/m

	PLACEHOLDER_I   = '{我}'
	PLACEHOLDER_YOU = '{你}'

	def on_load
		super
		prepare_db
	end

	def prepare_db
		@db = SQLite3::Database.open DB_FILE
		@db.execute SQL_CREATE_TABLE_MESSAGES  if @db.get_first_value(SQL_CHECK_TABLE, 'messages').zero?
		@db.execute SQL_CREATE_TABLE_RESPONSES if @db.get_first_value(SQL_CHECK_TABLE, 'responses').zero?
		if @db.get_first_value(SQL_CHECK_TABLE, 'relations').zero?
			@db.execute SQL_CREATE_TABLE_RELATIONS
			@db.execute SQL_CREATE_INDEX_RELATIONS
		end
		log('数据库准备完毕', Logger::DEBUG) if $-d
	end

	def on_unload
		super
		@db.close
		log('数据库连接断开', Logger::DEBUG) if $-d
	end

	def get_response(uin, sender_qq, sender_nickname, command, time)
		# super # FOR DEBUG
		function_say(command) or function_forget(command) or function_learn(command, sender_qq) or function_response(command, sender_nickname)
	end

	def function_say(command)
		$~[:response] if COMMAND_SAY =~ command
	end

	def function_forget(command)
		if COMMAND_FORGET =~ command
			@db.transaction do |db|
				db.execute(SQL_DELETE_RELATIONS, $~[:message].strip)
			end
			@responses[:forgeted].sample
		end
	end

	def function_learn(command, sender_qq)
		if COMMAND_LEARN =~ command
			command = $~[:command]
			if COMMAND_LEARN_MULTILINE =~ command or COMMAND_LEARN_TOWLINE =~ command or COMMAND_LEARN_ONELINE =~ command
				response = $~[:response].strip
				if response.length < @responce_limit
					message = $~[:message].strip
					@db.transaction do |db|
						time = Time.now.to_i
						db.execute(SQL_INSERT_MESSAGE, message, sender_qq, time) unless db.get_first_value(SQL_GET_MESSAGE_ID, message)
						db.execute(SQL_INSERT_RESPONSE, response, sender_qq, time) unless db.get_first_value(SQL_GET_RESPONSE_ID, response)
						db.execute(SQL_INSERT_RELATION, sender_qq, time, message, response)
					end
					@responses[:learned].sample
				else
					@responses[:toolong].sample
				end
			end
		end
	end

	def function_response(command, sender_nickname)
		result = @db.execute(SQL_SELECT_RESPONSES, command).map!{ |row| row[0] }.sample
		if result
			result.gsub(/#{PLACEHOLDER_I}|#{PLACEHOLDER_YOU}/, PLACEHOLDER_I => bot_name, PLACEHOLDER_YOU => sender_nickname)
		else
			@responses[:null].sample
		end
	end
end