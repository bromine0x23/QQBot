# -*- coding: utf-8 -*-

module WebQQProtocol

	# QQ实体
	class Entity
		TYPE = '实体'

		attr_reader :uin, :name, :number

		def initialize(uin, name, number)
			@uin, @name, @number = uin || 0, (name || '').force_encoding('utf-8'), number || 0
		end

		def to_s
			"[#{TYPE}]#{@name}(#{@number})"
		end
	end

	# QQ好友类
	class Friend < Entity
		TYPE = '好友'
	end

	class GroupMember < Entity
		TYPE = '群成员'
	end

	# QQ群类
	class Group < Entity
		TYPE = '群'

		attr_reader :members

		def initialize(uid, name, number, info, &on_uin_mismatch)
			super(uid, name, number)

			member_names = Hash[
				info['minfo'].map! { |minfo|
					[minfo['uin'], minfo['nick']]
				}
			].merge!(
				Hash[
					(info['cards'] || []).map! { |card|
						[card['muin'], card['card']]
					}
				]
			)

			@members = Hash.new do |members, uin|
				members[uin] = GroupMember.new(
					uin,
					member_names[uin],
					on_uin_mismatch.call(uin)
				)
			end
		end

		# @return [WebQQProtocol::QQGroupMember]
		def member_by_uin(uin)
			@members[uin]
		end

		# @return [WebQQProtocol::QQGroupMember]
		def member_by_name(name)
			@members.values.find do |member|
				member.name == name
			end
		end

		# @return [WebQQProtocol::QQGroupMember]
		def member_by_number(number)
			@members.values.find do |member|
				member.number == number
			end
		end
	end

	class Discuss < Entity
		TYPE = '讨论组'

		def initialize(uin, name)
			super(uin, name, 0)
		end
	end
end