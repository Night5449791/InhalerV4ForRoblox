local AutoArrest
local ArrestRange
local ArrestDelay

AutoArrest = vape.Categories.Blatant:CreateModule({
	Name = 'AutoArrest',
	Function = function(callback)
		if not callback then return end

		repeat
			local root = sentence.root(lplr)

			if root and sentence.isCop(lplr) then
				local range = ArrestRange.Value
				local origin = root.Position

				for _, plr in playersService:GetPlayers() do
					if plr == lplr or not sentence.isDowned(plr) or not sentence.isTarget(plr) then continue end

					local other = sentence.root(plr)
					if not other or (other.Position - origin).Magnitude > range then continue end

					local prompt = other:FindFirstChild('ArrestPrompt')
					if not prompt then continue end

					prompt.MaxActivationDistance = range
					prompt.HoldDuration = 0
					pcall(prompt.InputHoldBegin, prompt)
					task.wait()
					pcall(prompt.InputHoldEnd, prompt)
					task.wait(ArrestDelay.Value)
					break
				end
			end

			task.wait(0.2)
		until not AutoArrest.Enabled or vape.Loaded == nil
	end,
	Tooltip = 'Arrests downed enemies in range through their own arrest prompt'
})
ArrestRange = AutoArrest:CreateSlider({
	Name = 'Range',
	Min = 5,
	Max = 30,
	Default = 12,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end,
	Tooltip = 'Keep it close, the server still rejects arrests made from too far away'
})
ArrestDelay = AutoArrest:CreateSlider({
	Name = 'Arrest delay',
	Min = 0.1,
	Max = 2,
	Decimal = 10,
	Default = 0.3,
	Suffix = function(val)
		return 's'
	end
})
