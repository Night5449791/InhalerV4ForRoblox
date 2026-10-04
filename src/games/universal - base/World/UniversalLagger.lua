local UniversalLagger
local Message

local DEFAULT_MESSAGE = 'join https://discord.gg/bMZ4BSUR47 and have fun :v'

UniversalLagger = vape.Categories.World:CreateModule({
	Name = 'UniversalLagger',
	Function = function(callback)
		if callback then
			local random = Random.new()

            notif('UniversalLagger', 'yo nigga lets see their reaction !1!1!11!', 5)
			repeat
				local character = lplr.Character
				local animator = character and character:FindFirstChildWhichIsA('Animator', true) or nil

				if animator then
					local text = Message.Value or ''
					if text == '' then
						text = DEFAULT_MESSAGE
					end

					-- both the preset and custom messages get the same padding
					local animation = Instance.new('Animation')
					animation.AnimationId = 'http=507770677\1'..random:NextInteger(1, 1000000)..'\n \n'..text..'\n \n'
					local loaded = animator:LoadAnimation(animation)
					loaded:Play(0, 0.0001, 0)
				end

				task.wait()
			until not UniversalLagger.Enabled
		end
	end,
	Tooltip = 'lags ur server, thx v3rm'
})
Message = UniversalLagger:CreateTextBox({
	Name = 'Message',
	Placeholder = 'Message',
	Tooltip = 'leave it blank to use preset',
	Function = function()
        UniversalLagger:Toggle()
		UniversalLagger:Toggle()
    end,
})