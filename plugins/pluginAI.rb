# -*- coding: utf-8 -*-

require 'sqlite3'

class PluginAI < PluginNicknameResponderCombineFunctionBase
	NAME = 'AI插件'
	AUTHOR = 'BR'
	VERSION = '1.12'
	DESCRIPTION = '人家才不是AI呢'
	MANUAL = <<MANUAL.strip!
======== 复述 ========
说 <复述内容>
======== 忘记 =======
忘记 <消息>
======== 学习 ========
==== 替代 ====
　%{我} -> 机器人昵称
　%{你} -> 消息发送者昵称
===== 短语消息 =====
学习 <消息短语> <响应短语>
===== 单行消息 ====
学习
<单行消息句子>
<多行响应句子>
===== 多行消息 ====
学习=<分界符>
<多行消息句子>
<分界符>
<多行响应句子>
MANUAL
	PRIORITY = -8

	DB_FILE = file_path('pluginAI.db')

	SQL_CREATE_TABLE_MESSAGES = <<SQL
CREATE TABLE IF NOT EXISTS messages (
	id         INTEGER PRIMARY KEY AUTOINCREMENT,
	message    TEXT NOT NULL,
	created_by INTEGER NOT NULL,
	created_at TIMESTAMP,
	CONSTRAINT uc_message UNIQUE (message)
)
SQL

	SQL_CREATE_TABLE_RESPONSES = <<SQL
CREATE TABLE IF NOT EXISTS responses (
	id         INTEGER PRIMARY KEY AUTOINCREMENT,
	response   TEXT NOT NULL,
	created_by INTEGER NOT NULL,
	created_at TIMESTAMP,
	CONSTRAINT uc_response UNIQUE (response)
)
SQL

	SQL_CREATE_TABLE_RELATIONS = <<SQL
CREATE TABLE IF NOT EXISTS relations (
	message_id  INTEGER REFERENCES messages (id),
	response_id INTEGER REFERENCES response (id),
	created_by  INTEGER NOT NULL,
	created_at  TIMESTAMP,
	CONSTRAINT pk_relation PRIMARY KEY (message_id, response_id)
)
SQL

	SQL_CREATE_INDEX_RELATIONS = <<SQL
CREATE INDEX IF NOT EXISTS index_message_id ON relations (message_id)
SQL

	SQL_INSERT_MESSAGE = <<SQL
INSERT OR IGNORE
INTO messages (message, created_by, created_at)
VALUES (?, ?, ?)
SQL

	SQL_INSERT_RESPONSE = <<SQL
INSERT OR IGNORE
INTO responses (response, created_by, created_at)
VALUES (?, ?, ?)
SQL

	SQL_INSERT_RELATION = <<SQL
INSERT OR IGNORE
INTO relations (message_id, response_id, created_by, created_at)
	SELECT messages.id, responses.id, ?, ?
	FROM messages, responses
	WHERE message = ? AND response = ?
SQL

	SQL_SELECT_RESPONSES = <<SQL
SELECT response FROM responses
WHERE id IN (
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

	COMMAND_SAY = /^说(?<response>.*)/m
	COMMAND_FORGET = /^忘记(?<message>.*)/m
	COMMAND_LEARN = /^学习(?<command>.*)/m
	COMMAND_BLACKLIST = /^(\d+)\s*是坏人$/
	COMMAND_LEARN_ONELINE = /^ (?<message>\S+) +(?<response>.+)/
	COMMAND_LEARN_TOWLINE = /^[\r\n](?<message>[^\r\n]+)[\r\n]+(?<response>.+)/m
	COMMAND_LEARN_MULTILINE = /^=(?<delimiter>\w+)\s*[\r\n](?<message>.+?)[\r\n]\k<delimiter>(?<response>.+)/m

	def on_load
		super
		prepare_db
	end

	def prepare_db
		@db = SQLite3::Database.open DB_FILE
		@db.transaction do |db|
			db.execute SQL_CREATE_TABLE_MESSAGES
			db.execute SQL_CREATE_TABLE_RESPONSES
			db.execute SQL_CREATE_TABLE_RELATIONS
			db.execute SQL_CREATE_INDEX_RELATIONS
		end
	end

	def on_unload
		super
		@db.close
	end

	def function_say(_, _, command, _)
		$~[:response] if COMMAND_SAY =~ command
	end

	def function_forget(_, _, command, _)
		if COMMAND_FORGET =~ command
			@db.transaction do |db|
				db.execute(SQL_DELETE_RELATIONS, $~[:message].strip)
			end
			#noinspection RubyResolve
			@responses[:forgot].sample
		end
	end

	def function_learn(_, sender, command, time)
		if COMMAND_LEARN =~ command
			command = $~[:command]
			if COMMAND_LEARN_MULTILINE =~ command or COMMAND_LEARN_TOWLINE =~ command or COMMAND_LEARN_ONELINE =~ command
				message = $~[:message].strip
				response = $~[:response].strip
				#noinspection RubyResolve
				if response.length < @response_limit
					@db.transaction do |db|
						db.execute(SQL_INSERT_MESSAGE, message, sender.number, time.to_i)
						db.execute(SQL_INSERT_RESPONSE, response, sender.number, time.to_i)
						db.execute(SQL_INSERT_RELATION, sender.number, time.to_i, message, response)
					end
					@responses[:learned].sample
				else
					@responses[:too_long].sample
				end
			end
		end
	end

	def function_response(_, sender, command, _)
		result = @db.execute(SQL_SELECT_RESPONSES, command).map! { |row| row[0] }.sample
		if result
			result % {我: nick, 你: sender.name}
		else
			#noinspection RubyResolve
			@responses[:null].sample
		end
	end
end