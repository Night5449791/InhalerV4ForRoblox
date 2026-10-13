local UniversalBroadcast
local Message
local random = Random.new()
local DEFAULT_MESSAGE = 'Join https://discord.gg/bMZ4BSUR47 get better exploits or have fun :v'

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
						local id = 'http=507770677\1'..random:NextInteger(1, 1000000)..'\n \n'
						local text = Message.Value ~= '' and Message.Value or DEFAULT_MESSAGE
						-- cap the message so the id + both "\n \n" pads stay under 256
						local payload = id..text:sub(1, 256 - #id - 3)..'\n \n'

						if replicatesignal and useSignal then
							useSignal = pcall(replicatesignal, animator.OnCombinedUpdate, payload, true, 0, 0.0001, 0, 0, Enum.AnimationPriority.Core, true, 255)
						else
							local animation = Instance.new('Animation')
							animation.AnimationId = payload
							local track = animator:LoadAnimation(animation)
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
	Placeholder = 'text (~228 character limit)'
})