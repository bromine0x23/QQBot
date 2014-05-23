# -*- coding: utf-8 -*-

module WebQQProtocol

	# 异常类：通信错误
	class ErrorCode < Exception
		attr_reader :retcode, :data

		def initialize(retcode, data = nil)
			super()
			@retcode, @data = retcode, data
		end

		def message
			"[ErrorCode] retcode: #{@retcode}, raw_data: #{@data}"
		end
	end

	# 异常类：密码错误
	class PasswordWrong < Exception
		def message
			'[PasswordWrong] 密码错误'
		end
	end

	# 异常类：登录失败
	class LoginFailed < Exception
		attr_reader :state, :info

		def initialize(state, info)
			super()
			@state, @info = state, info
		end

		def message
			"[LoginFailed] login failed: {state: #{@state}, info: #{@info}}"
		end
	end

	# 异常类：未登录
	class NotLogin < Exception
	end
end