local UniversalBroadcast
local Message
local rand = Random.new()
local defaultmsg = 'Join https://discord.gg/bMZ4BSUR47 get better exploits or have fun :v'

UniversalBroadcast = vape.Categories.World:CreateModule({
	Name = 'UniversalBroadcast',
	Function = function(callback)
		if callback then
			local useSignal = true

			repeat
				if entitylib.isAlive then
					local animator = entitylib.character.Humanoid:FindFirstChildWhichIsA('Animator')

					if animator then
						-- fall back to the default message when the textbox is empty
						local text = (Message.Value and Message.Value ~= '') and Message.Value or defaultmsg
						local payload = ('http=507770677'..utf8.char(rand:NextInteger(1, 65535))..text):sub(1, 256)

						if replicatesignal and useSignal then
							useSignal = pcall(replicatesignal, animator.OnCombinedUpdate, payload, true, 0, 0.0001, 0, 0, Enum.AnimationPriority.Core, true, 255)
						else
							local anim = Instance.new('Animation')
							anim.AnimationId = payload
							local track = animator:LoadAnimation(anim)
							track:Play(0, 0.0001, 0)
						end
					end
				end

				task.wait()
			until not UniversalBroadcast.Enabled
		end
	end,
	Tooltip = 'Use animations to spam the console of people ingame'
})
Message = UniversalBroadcast:CreateTextBox({
	Name = 'Message',
	Placeholder = 'text (242 character limit)'
})