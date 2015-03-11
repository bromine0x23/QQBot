# -*- coding: utf-8 -*-

require 'English'
require 'sqlite3'

install_hooks << lambda do
	local[:db] = db = SQLite3::Database.new(file_path('plugin.db'))
	db.execute <<-SQLITE
CREATE TABLE IF NOT EXISTS "messages" (
	"id"         INTEGER PRIMARY KEY AUTOINCREMENT,
	"message"    TEXT NOT NULL,
	"created_by" INTEGER NOT NULL,
	"created_at" INTEGER,
	CONSTRAINT "uc_message" UNIQUE ("message")
)
	SQLITE
	db.execute <<-SQLITE
CREATE TABLE IF NOT EXISTS "responses" (
	"id"         INTEGER PRIMARY KEY AUTOINCREMENT,
	"response"   TEXT NOT NULL,
	"created_by" INTEGER NOT NULL,
	"created_at" INTEGER,
	CONSTRAINT "uc_response" UNIQUE ("response")
)
	SQLITE
	db.execute <<-SQLITE
CREATE TABLE IF NOT EXISTS "relations" (
	"message_id"  INTEGER REFERENCES "messages" ("id"),
	"response_id" INTEGER REFERENCES "response" ("id"),
	"created_by"  INTEGER NOT NULL,
	"created_at"  INTEGER,
	CONSTRAINT "pk_relation" PRIMARY KEY ("message_id", "response_id")
)
	SQLITE
	db.execute <<-SQLITE
CREATE INDEX IF NOT EXISTS "index_message_id" ON "relations" ("message_id")
	SQLITE
end

uninstall_hooks << lambda do
	local[:db].close
end

functions << lambda do |_, sender, command, time|
	return unless command =~ /\A学习\s*(?<message>\S+)\s+(?<response>.+)\Z/m
	message, response = $LAST_MATCH_INFO[:message].strip, $LAST_MATCH_INFO[:response].strip

	if response.length < config[:response_limit]
		local[:db].transaction do |db|
			db.execute <<-SQLITE, [message, sender.number, time.to_i]
INSERT OR IGNORE
INTO "messages" ("message", "created_by", "created_at")
VALUES (?, ?, ?)
			SQLITE
			db.execute <<-SQLITE, [response, sender.number, time.to_i]
INSERT OR IGNORE
INTO "responses" ("response", "created_by", "created_at")
VALUES (?, ?, ?)
			SQLITE
			db.execute <<-SQLITE, [sender.number, time.to_i, message, response]
INSERT OR IGNORE
INTO "relations" ("message_id", "response_id", "created_by", "created_at")
SELECT "messages"."id", "responses"."id", ?, ?
FROM "messages", "responses"
WHERE "message" = ? AND "response" = ?
			SQLITE
		end
		config[:responses][:learned].sample
	else
		config[:responses][:too_long].sample
	end
end

functions << lambda do |_, _, command, _|
	return unless command =~ /\A忘记(?<message>.*)\Z/m
	local[:db].transaction do |db|
		db.execute <<-SQLITE, [$LAST_MATCH_INFO[:message].strip]
DELETE FROM "relations"
WHERE "message_id" = (
	SELECT "id" FROM "messages"
	WHERE "message" = ?
)
		SQLITE
	end
	config[:responses][:forgot].sample
end

result_argument = lambda do |my_name, your_name, from, time|
	{
		我: my_name,
		你: your_name,
		来自: from.friend? ? nil : from.name,
		year: time.year,
		month: time.month,
		day: time.day,
		hour: time.hour,
		minute: time.min,
		second: time.sec,
	}
end

functions << lambda do |from, sender, command, time|
	result = local[:db].execute(<<-SQLITE, [command]).flatten.sample
SELECT "response" FROM "responses"
WHERE "id" IN (
	SELECT "response_id" FROM "relations"
	WHERE "message_id" = (
		SELECT "id" FROM "messages"
		WHERE "message" = ?
	)
)
	SQLITE
	if result
		begin
			format(result, result_argument.call(qqbot.name, sender.name, from, time))
		rescue
			result
		end
	else
		config[:responses][:null].sample
	end
end