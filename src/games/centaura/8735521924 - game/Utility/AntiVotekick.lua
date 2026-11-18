local AntiVotekick
local Mode
local teleportService = cloneref(game:GetService('TeleportService'))
local voteCounter
local rejoining

local function rejoin()
	pcall(function()
		lplr:Kick()
	end)
	pcall(function()
		teleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, lplr)
	end)
end

local function serverhop()
	pcall(function()
		lplr:Kick()
	end)
	local success, data = pcall(function()
		local response = game:HttpGet('https://games.roblox.com/v1/games/'..game.PlaceId..'/servers/Public?sortOrder=1&excludeFullGames=true&limit=100')
		return httpService:JSONDecode(response)
	end)
	if not success or type(data) ~= 'table' or type(data.data) ~= 'table' then return end

	for _, server in data.data do
		if server.id ~= game.JobId and tonumber(server.playing) < playersService.MaxPlayers then
			pcall(function()
				teleportService:TeleportToPlaceInstance(game.PlaceId, server.id, lplr)
			end)
			return
		end
	end
end

local function trigger()
	if rejoining then return end
	rejoining = true
	if Mode.Value == 'Serverhop' then
		serverhop()
	else
		rejoin()
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
	List = {'Rejoin', 'Serverhop'}
})
