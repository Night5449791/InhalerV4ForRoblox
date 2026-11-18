local AntiVotekick
local Mode
local voteCounter
local rejoining

local function trigger()
	if rejoining then return end
	rejoining = true

	pcall(function()
		lplr:Kick()
	end)

	local utility = vape.Categories.Utility
	local target = utility and utility[Mode.Value]
	if target then
		if target.Enabled then
			target:Toggle()
		end
		target:Toggle()
	end
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
