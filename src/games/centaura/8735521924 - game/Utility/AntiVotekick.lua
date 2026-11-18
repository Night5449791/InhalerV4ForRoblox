local AntiVotekick
local Mode
local voteCounter
local rejoining

local function trigger()
	if rejoining then return end
	rejoining = true

	task.spawn(function()
		task.wait(2.5)

		pcall(function()
			lplr:Kick('Inhaler: Anti Votekick is working')
		end)

		local target = vape.Modules and vape.Modules[Mode.Value]
		if target and not target.Enabled then
			target:Toggle()
		end
	end)
end

AntiVotekick = vape.Categories.Utility:CreateModule({
	Name = 'AntiVotekick',
	Function = function(callback)
		rejoining = nil
		if callback then
			repeat
				local votekickValues = replicatedStorage:FindFirstChild('VotekickValues')
				voteCounter = votekickValues and votekickValues:FindFirstChild(lplr.Name)
			until voteCounter and voteCounter:IsA('IntValue') or not AntiVotekick.Enabled
			if voteCounter and voteCounter:IsA('IntValue') then
				if voteCounter.Value > 0 then
					trigger()
				end

				AntiVotekick:Clean(voteCounter:GetPropertyChangedSignal('Value'):Connect(function()
					if voteCounter.Value > 0 then
						trigger()
					end
				end))
			end
		else
			voteCounter = nil
		end
	end,
	Tooltip = 'Rejoins or serverhops when someone votekicks you'
})
Mode = AntiVotekick:CreateDropdown({
	Name = 'Mode',
	List = {'Rejoin', 'ServerHop'}
})
