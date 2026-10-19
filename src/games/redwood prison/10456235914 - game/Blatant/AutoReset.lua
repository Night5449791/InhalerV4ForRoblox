local AutoReset
local Distance
local OnArrest
local OnlyPrisoners

AutoReset = vape.Categories.Blatant:CreateModule({
	Name = 'AutoReset',
	Function = function(callback)
		if not callback then return end

		repeat
			local character = lplr.Character
			local reset = character ~= nil and OnArrest.Enabled and redwood.hasState(character, 'ArrestCurrent')

			if not reset and Distance.Value > 0 then
				if not OnlyPrisoners.Enabled or redwood.isTeam(lplr, redwood.Teams.Prisoners) or redwood.isTeam(lplr, redwood.Teams.Fugitive) then
					reset = redwood.nearestPlayer(redwood.Teams.Guards, Distance.Value) ~= nil
				end
			end

			if reset then
				redwood.fire('Reset')
				task.wait(0.5)
			else
				task.wait(0.1)
			end
		until not AutoReset.Enabled or vape.Loaded == nil
	end,
	Tooltip = 'Resets your character before a guard can arrest you'
})
Distance = AutoReset:CreateSlider({
	Name = 'Guard distance',
	Min = 0,
	Max = 60,
	Default = 12,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end,
	Tooltip = 'Resets when a guard gets this close, 0 disables the distance check'
})
OnArrest = AutoReset:CreateToggle({
	Name = 'Reset while being arrested',
	Default = true
})
OnlyPrisoners = AutoReset:CreateToggle({
	Name = 'Only as prisoner',
	Default = true,
	Tooltip = 'Only watches guards while you are a prisoner or a fugitive'
})
