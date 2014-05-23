# -*- coding: utf-8 -*-

module WebQQProtocol

	# 哈希算法
	module Utility
		# 哈希密码
		def self.hash_password(password, verify_code, key)
			md5(md5(hex2ascii(md5(password) + key.gsub!(/\\x/, ''))) + verify_code)
		end

		# 腾讯迷の哈希
		#noinspection SpellCheckingInspection
		def self.hash_friends(uin, ptwebqq)
			l = [
				uin >> 24 & 255,
				uin >> 16 & 255,
				uin >> 8 & 255,
				uin >> 0 & 255,
			]
			values = ptwebqq.chars.map { |char| char.ord }
			stack = [[0, values.length - 1]]
			while stack.size > 0
				left, right = stack.pop
				if left <= right and 0 <= left and right < values.length
					if left + 1 == right
						values[left], values[right] = values[right], values[left] if values[left] > values[right]
					else
						i, j = left, right
						pivot = values[i]
						while i < j
							while i < j and values[j] >= pivot
								j -= 1
								l[0] = l[0] + 3 & 255
							end
							if i < j
								values[i] = values[j]
								i += 1
								l[1] = l[1] * 13 + 43 & 255
							end
							while i < j and values[i] <= pivot
								i += 1
								l[2] = l[2] - 3 & 255
							end
							if i < j
								values[j] = values[i]
								j -= 1
								l[3] = (l[0] ^ l[1] ^ l[2] ^ l[3] + 1) & 255
							end
						end
						values[i] = pivot
						stack << [left, i - 1] << [i + 1, right]
					end
				end
			end
			'%02X%02X%02X%02X' % l
		end

		private

		# 将十六进制数字串每两个编码为ASCII码对应的字符
		def self.hex2ascii(hex_str)
			hex_str.scan(/\w{2}/).map { |byte_str| byte_str.to_i(16).chr }.join
		end

		# MD5哈希
		#noinspection RubyResolve
		def self.md5(src)
			Digest::MD5.hexdigest(src).upcase
		end
	end
end