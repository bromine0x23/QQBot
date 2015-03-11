# -*- coding: utf-8 -*-

require 'concurrent'
require 'sqlite3'

install_hooks << lambda do
	local[:db] = db = SQLite3::Database.new(file_path('plugin.db'))
	db.execute <<-SQLITE
CREATE TABLE IF NOT EXISTS "message"(
	"time"          INTEGER,
	"sender_number" INTEGER,
	"sender_name"   TEXT,
	"message"       TEXT
)
	SQLITE
	db.execute <<-SQLITE
CREATE TABLE IF NOT EXISTS "group_message"(
	"time"          INTEGER,
	"group_number"  INTEGER,
	"group_name"    TEXT,
	"sender_number" INTEGER,
	"sender_name"   TEXT,
	"message"       TEXT
)
	SQLITE
	db.execute <<-SQLITE
CREATE TABLE IF NOT EXISTS "discuss_message"(
	"time"          INTEGER,
	"discuss_name"  TEXT,
	"sender_number" INTEGER,
	"sender_name"   TEXT,
	"message"       TEXT
)
	SQLITE

	local[:task] = Concurrent::SingleThreadExecutor.new
end

uninstall_hooks << lambda do
	local[:task].shutdown
	local[:db].close
end

define_singleton_method :deal_message do |*args|
	local[:task].post(*args) do |sender, message, time, |
		unless message.empty?
			local[:db].execute <<-SQLITE, time: time.to_i, sender_number: sender.number, sender_name: sender.name, message: message
INSERT INTO
	"message"("time", "sender_number", "sender_name", "message")
VALUES
	(:time, :sender_number, :sender_name, :message)
			SQLITE
		end
	end
	nil
end

define_singleton_method :deal_group_message do |*args|
	local[:task].post(*args) do |group, sender, message, time, |
		unless message.empty?
			local[:db].execute <<-SQLITE, time: time.to_i, group_number: group.number, group_name: group.name, sender_number: sender.number, sender_name: sender.name, message: message
INSERT INTO
	"group_message"("time", "group_number", "group_name", "sender_number", "sender_name", "message")
VALUES
	(:time, :group_number, :group_name, :sender_number, :sender_name, :message)
			SQLITE
		end
	end
	nil
end

define_singleton_method :deal_discuss_message do |*args|
	local[:task].post(*args) do |discuss, sender, message, time, |
		unless message.empty?
			local[:db].execute <<-SQLITE, time: time.to_i, discuss_name: discuss.name, sender_number: sender.number, sender_name: sender.name, message: message
INSERT INTO
	"discuss_message"("time", "discuss_name", "sender_number", "sender_name", "message")
VALUES
	(:time, :discuss_name, :sender_number, :sender_name, :message)
			SQLITE
		end
	end
	nil
end