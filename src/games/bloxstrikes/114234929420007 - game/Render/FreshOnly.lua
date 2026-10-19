local FreshOnly

run(function()
	-- BloxStrike parks a character the moment its part of the map leaves the view set: the rig is
	-- anchored in ReplicatedStorage._PVS_CulledCharacters and no transform ever arrives again. Off,
	-- those characters stay in the entity list and everything draws them at their last known
	-- position (a frozen, possibly outdated box). On, they are moved out of the list so only the
	-- characters the game is still simulating are drawn.
	FreshOnly = vape.Categories.Render:CreateModule({
		Name = 'Only fresh targets',
		Function = function(callback)
			bloxstrike.FreshOnly = callback

			if callback then
				bloxstrike.parkStale()
			else
				bloxstrike.unparkAll()
			end
		end,
		Tooltip = 'Hides targets the game stopped simulating instead of drawing them at their last known position'
	})
end)
