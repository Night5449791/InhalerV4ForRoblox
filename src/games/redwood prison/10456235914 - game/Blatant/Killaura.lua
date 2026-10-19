local Killaura
local Range
local Part
local Delay
local TeamCheck

Killaura = vape.Categories.Blatant:CreateModule({
	Name = 'Killaura',
	Function = function(callback)
		if not callback then return end

		repeat
			local tool = redwood.meleeTool()
			local character = lplr.Character
			local root = character and character:FindFirstChild('HumanoidRootPart')

			if tool and root then
				for _, plr in playersService:GetPlayers() do
					if not Killaura.Enabled then break end
					if not TeamCheck.Enabled or redwood.isTarget(plr) then
						local targetCharacter = plr.Character
						local other = targetCharacter and targetCharacter:FindFirstChild('HumanoidRootPart')
						if other and (other.Position - root.Position).Magnitude <= Range.Value then
							redwood.attack(plr, Part.Value)
						end
					end
				end
			end

			task.wait(Delay.Value)
		until not Killaura.Enabled or vape.Loaded == nil
	end,
	Tooltip = 'Hits everyone in range with your equipped melee weapon'
})
Range = Killaura:CreateSlider({
	Name = 'Range',
	Min = 1,
	Max = 30,
	Default = 10,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end,
	Tooltip = 'Keep it close to the weapon range, the server still validates the distance'
})
Part = Killaura:CreateDropdown({
	Name = 'Part',
	List = {'Head', 'RootPart'}
})
Delay = Killaura:CreateSlider({
	Name = 'Attack delay',
	Min = 0.1,
	Max = 2,
	Decimal = 10,
	Default = 0.2,
	Suffix = function(val)
		return 's'
	end
})
TeamCheck = Killaura:CreateToggle({
	Name = 'Team check',
	Default = true,
	Tooltip = 'Skips teammates and friends'
})
