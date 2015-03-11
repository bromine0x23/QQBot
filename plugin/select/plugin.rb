# -*- coding: utf-8 -*-

require 'English'

functions << lambda do |_, _, command, time|
	return unless command =~ /\A(?<select0>\S+)还是(?<select1>\S+?)(?:[啦呢啊阿!?！？]*)\Z/
	select0, select1 = $LAST_MATCH_INFO[:select0], $LAST_MATCH_INFO[:select1]
	select0.upcase!
	select1.upcase!

	if select0 == select1
		config[:display][:same].sample
	else
		select0_sum, select1_sum = select0.sum, select1.sum
		if select0_sum < select1_sum
			[select0, select1][pseudo_random(date_seed(time), select1_sum - select0_sum, 11113) & 1]
		else
			[select1, select0][pseudo_random(date_seed(time), select0_sum - select1_sum, 11113) & 1]
		end
	end
end

functions << lambda do |_, _, command, time|
	return unless command =~ /\A(?<who>\S*?)(?<act>\S+)(?<neg>[不没])\k<act>(?<etc>\S*?)(?:[啦呢啊阿!?！？]*)\Z/
	who, act, neg, etc = $LAST_MATCH_INFO[:who], $LAST_MATCH_INFO[:act], $LAST_MATCH_INFO[:neg], $LAST_MATCH_INFO[:etc]
	if pseudo_random(date_seed(time), (who.sum ^ act.sum ^ etc.sum), 11113).odd?
		"#{who}#{act}#{etc}！"
	else
		"#{who}#{neg}#{act}#{etc}……"
	end
end

