local AutoReset
local ResetDistance
local ResetWhileDowned

-- the reset button is wired to WeaponEvent:FireServer('Reset'), which is also the cheapest way
-- out of an arrest: a downed player that respawns cannot be handcuffed any more
AutoReset = vape.Categories.Blatant:CreateModule({
	Name = 'AutoReset',
	Function = function(callback)
		if not callback then return end

		repeat
			local reset = ResetWhileDowned.Enabled and sentence.status(lplr, 'Downed') == true

			if not reset and ResetDistance.Value > 0 then
				reset = sentence.nearestPlayer(sentence.Teams.Guards, ResetDistance.Value) ~= nil
			end

			if reset then
				sentence.fire('WeaponEvent', 'Reset')
				task.wait(0.5)
			else
				task.wait(0.1)
			end
		until not AutoReset.Enabled or vape.Loaded == nil
	end,
	Tooltip = 'Resets your character before a guard can arrest you'
})
ResetDistance = AutoReset:CreateSlider({
	Name = 'Guard distance',
	Min = 0,
	Max = 60,
	Default = 12,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end,
	Tooltip = 'Resets when a guard gets this close, 0 disables the distance check'
})
ResetWhileDowned = AutoReset:CreateToggle({
	Name = 'Reset while downed',
	Default = true
})
