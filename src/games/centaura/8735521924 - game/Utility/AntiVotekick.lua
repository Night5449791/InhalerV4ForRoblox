local AntiVotekick
local teleportService = cloneref(game:GetService('TeleportService'))
local voteCounter
local rejoining

local function rejoin()
	if rejoining then return end
	rejoining = true
	pcall(function()
		teleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, lplr)
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
					rejoin()
				end

				AntiVotekick:Clean(voteCounter:GetPropertyChangedSignal('Value'):Connect(function()
					if voteCounter.Value > 0 then
						rejoin()
					end
				end))
			end
		else
			voteCounter = nil
		end
	end,
	Tooltip = 'Rejoins the server when someone votekicks you'
})
