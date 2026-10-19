local AutoLobby
local Mode
local PickNearest
local PartySize
local Delay
local RequireSpace

run(function()
	local function position()
		local character = entitylib.character
		local root = character and character.RootPart
		if root then return root.Position end

		local localCharacter = lplr.Character
		root = localCharacter and localCharacter:FindFirstChild('HumanoidRootPart')
		return root and root.Position
	end

	-- picks a match the way the lobby does: skip the ones still being created or locked to
	-- friends, then either the closest pad or the first id
	local function findMatch()
		local models = deadlydelivery.models()
		local origin = position()
		local bestId, bestDistance

		for id, match in deadlydelivery.matches() do
			if deadlydelivery.joinable(match) then
				local model = models[id]
				local pad = model and model.PrimaryPart

				if PickNearest.Enabled and origin and pad then
					local distance = (pad.Position - origin).Magnitude
					if not bestDistance or distance < bestDistance then
						bestId, bestDistance = id, distance
					end
				else
					bestId = bestId or id
				end
			end
		end

		return bestId
	end

	-- the difficulty the client itself allows: relaxed needs floor 5, hardcore needs floor 15
	local function difficulty()
		local level = deadlydelivery.dungeonLevel()
		local mode = Mode.Value
		if mode == 'Easy' and level < 5 then
			mode = 'Normal'
		elseif mode == 'Hard' and level < 15 then
			mode = 'Normal'
		end

		return mode == 'Any' and 'Normal' or mode
	end

	AutoLobby = vape.Categories.Utility:CreateModule({
		Name = 'AutoLobby',
		Function = function(callback)
			if not callback then return end

			local lastJoin = 0
			local uploaded

			repeat
				local id = deadlydelivery.matchId()

				if not id then
					uploaded = nil
					local hasSpace = not RequireSpace.Enabled or not deadlydelivery.backpackFull()
					if hasSpace and os.clock() - lastJoin >= Delay.Value then
						local target = findMatch()
						if target and deadlydelivery.join(target) then
							lastJoin = os.clock()
						end
					end
				elseif uploaded ~= id then
					-- the match only starts once the party settings are uploaded, and the game
					-- opens its Match panel for them; drop the panel after sending ours
					local match = deadlydelivery.matches()[id]
					if match and match.matchState == 'Creating' then
						uploaded = id
						deadlydelivery.upload({
							size = PartySize.Value,
							mode = difficulty(),
							onlyFriends = false
						})
						deadlydelivery.closeMatchUI()
					end
				end

				task.wait(0.5)
			until not AutoLobby.Enabled or vape.Loaded == nil
		end,
		Tooltip = 'Joins a match from the lobby by itself and uploads the party settings so the run starts'
	})

	Mode = AutoLobby:CreateDropdown({
		Name = 'Mode',
		List = {'Any', 'Normal', 'Easy', 'Hard'},
		Tooltip = 'Difficulty uploaded with the party, falls back to Normal when the floor is too low'
	})
	PickNearest = AutoLobby:CreateToggle({
		Name = 'Nearest pad',
		Default = true,
		Tooltip = 'Picks the closest pad, off picks the first joinable match'
	})
	PartySize = AutoLobby:CreateSlider({
		Name = 'Party size',
		Min = 1,
		Max = 5,
		Default = 5
	})
	Delay = AutoLobby:CreateSlider({
		Name = 'Delay',
		Min = 1,
		Max = 30,
		Default = 3,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end
	})
	RequireSpace = AutoLobby:CreateToggle({
		Name = 'Require space',
		Default = true,
		Tooltip = 'Does not join while the backpack is full, the lobby blocks that too'
	})
end)
