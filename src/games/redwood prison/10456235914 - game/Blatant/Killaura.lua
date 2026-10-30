local Killaura
local Range
local Part
local Delay
local TeamCheck

-- picks the closest valid target once per tick instead of attacking everyone in range:
-- one InflictTarget per swing is what the server expects, extra calls are wasted
-- bandwidth and trip the Adonis rate checks
local function closestTarget(root, range, teamCheck)
	local best, bestDistance
	for _, plr in playersService:GetPlayers() do
		if plr ~= lplr and (not teamCheck or redwood.isTarget(plr)) then
			local character = plr.Character
			local other = character and character:FindFirstChild('HumanoidRootPart')
			if other then
				local distance = (other.Position - root.Position).Magnitude
				if distance <= range and (not bestDistance or distance < bestDistance) then
					best, bestDistance = plr, distance
				end
			end
		end
	end

	return best
end

Killaura = vape.Categories.Blatant:CreateModule({
	Name = 'Killaura',
	Function = function(callback)
		if not callback then return end

		local swingAt = 0

		repeat
			local tool = redwood.meleeTool()
			local character = lplr.Character
			local root = character and character:FindFirstChild('HumanoidRootPart')

			if tool and root and os.clock() >= swingAt then
				local target = closestTarget(root, Range.Value, TeamCheck.Enabled)
				if target then
					redwood.attack(target, Part.Value)
					swingAt = os.clock() + Delay.Value
				end
			end

			task.wait(0.05)
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
