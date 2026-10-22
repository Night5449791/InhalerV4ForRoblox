local AutoStomp
local StompRange
local StompDelay
local StompTeamCheck

-- E is the stomp key, the client sends CarryStompEvent:FireServer('EPress') from both the
-- StompButton and the keyboard binding, so the module repeats that call while a downed player is
-- close enough to be finished
AutoStomp = vape.Categories.Blatant:CreateModule({
	Name = 'AutoStomp',
	Function = function(callback)
		if not callback then return end

		repeat
			local root = sentence.root(lplr)

			if root then
				for _, plr in playersService:GetPlayers() do
					if plr == lplr or not sentence.isDowned(plr) then continue end
					if StompTeamCheck.Enabled and not sentence.isTarget(plr) then continue end

					local other = sentence.root(plr)
					if other and (other.Position - root.Position).Magnitude <= StompRange.Value then
						sentence.fire('CarryStompEvent', 'EPress')
						break
					end
				end
			end

			task.wait(StompDelay.Value)
		until not AutoStomp.Enabled or vape.Loaded == nil
	end,
	Tooltip = 'Presses the stomp key on downed players in range'
})
StompRange = AutoStomp:CreateSlider({
	Name = 'Range',
	Min = 1,
	Max = 20,
	Default = 6,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end
})
StompDelay = AutoStomp:CreateSlider({
	Name = 'Stomp delay',
	Min = 0.1,
	Max = 2,
	Decimal = 10,
	Default = 0.3,
	Suffix = function(val)
		return 's'
	end
})
StompTeamCheck = AutoStomp:CreateToggle({
	Name = 'Team check',
	Default = true,
	Tooltip = 'Skips teammates and friends'
})
