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
		def self.hash_get(uin, ptwebqq)
			t = ''
			n = ptwebqq + 'password error'
			v = []
			loop do
				if t.length <= n.length
					t << uin.to_s
					break if t.length == n.length
				else
					t = t[0, n.length]
					break
				end
			end
			t.length.times do |i|
				v[i] = t[i].ord ^ n[i].ord
			end
			n = '0123456789ABCDEF'
			t = ''
			v.each do |x|
				t << n[x >> 4 & 15] << n[x & 15]
			end
			t
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