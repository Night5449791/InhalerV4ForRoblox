-- Life Sentence (Real Heat Studios). Two per player state holders instead of one:
-- <player>.Backpack.Stats is a Tool whose values are the transient ones (Downed, RagDolled,
-- Carrying, BeingCarried, Dead) and ReplicatedStorage.PlayerStats.<name> holds the persistent
-- ones (Cash, Bounty, Strength, Cop, SolitaryTime). Both are replicated for every player, which
-- is what the game's own client reads, so the product reads them instead of the attributes.
-- Teams are the real Teams service (Guards / Inmates / Escaped) and every remote lives in
-- ReplicatedStorage.Events.
local run = function(func)
	func()
end
local cloneref = cloneref or function(obj)
	return obj
end

local playersService = cloneref(game:GetService('Players'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))

local lplr = playersService.LocalPlayer
local vape = shared.vape
local entitylib = vape.Libraries.entity
local whitelist = vape.Libraries.whitelist
local targetinfo = vape.Libraries.targetinfo
local sessioninfo = vape.Libraries.sessioninfo

-- the option objects are created once when the gui loads and profiles only flip Enabled, so
-- they are resolved here instead of hashing the same names on every per-player check
local friends = vape.Categories.Friends
local useFriends = friends.Options['Use friends']
local recolorFriends = friends.Options['Recolor visuals']
local friendsColor = friends.Options['Friends color']
local teamsByServer = vape.Settings.Modules.Options['Teams by server']
local useTeamColor = vape.Settings.Modules.Options['Use team color']

local sentence = {
	Teams = {
		Guards = 'Guards',
		Inmates = 'Inmates',
		Escaped = 'Escaped'
	},
	Events = nil
}

local function isFriend(plr, recolor)
	if not useFriends.Enabled then return nil end

	local friend = table.find(friends.ListEnabled, plr.Name) and true
	if recolor then
		friend = friend and recolorFriends.Enabled
	end

	return friend
end

local playerStatsFolder = replicatedStorage:FindFirstChild('PlayerStats')

-- ReplicatedStorage.PlayerStats.<name>, the persistent value folder of one player
function sentence.playerStats(plr)
	if not plr then return end

	playerStatsFolder = playerStatsFolder or replicatedStorage:FindFirstChild('PlayerStats')
	return playerStatsFolder and playerStatsFolder:FindFirstChild(plr.Name) or nil
end

-- the "Stats" tool, normally inside the backpack and only moved into the character when it is
-- equipped, so both parents are checked
function sentence.stats(plr)
	if not plr then return end

	local backpack = plr:FindFirstChild('Backpack')
	local stats = backpack and backpack:FindFirstChild('Stats')
	if stats then return stats end

	local character = plr.Character
	return character and character:FindFirstChild('Stats') or nil
end

-- persistent value, e.g. sentence.value(plr, 'Cash')
function sentence.value(plr, name)
	local folder = sentence.playerStats(plr)
	local value = folder and folder:FindFirstChild(name)
	if value then
		return value.Value
	end
end

-- transient value, e.g. sentence.status(plr, 'Downed')
function sentence.status(plr, name)
	local stats = sentence.stats(plr)
	local value = stats and stats:FindFirstChild(name)
	if value then
		return value.Value
	end
end

function sentence.team(plr)
	return plr and plr.Team and plr.Team.Name or nil
end

function sentence.isTeam(plr, name)
	return sentence.team(plr) == name
end

function sentence.isCop(plr)
	return sentence.value(plr, 'Cop') == true
end

function sentence.isDowned(plr)
	return sentence.status(plr, 'Downed') == true
end

function sentence.root(plr)
	local character = plr and plr.Character
	return character and character:FindFirstChild('HumanoidRootPart') or nil
end

function sentence.isTarget(plr)
	if not plr or plr == lplr then return false end
	if isFriend(plr) then return false end
	if not select(2, whitelist:get(plr)) then return false end
	if teamsByServer.Enabled then
		local team = sentence.team(plr)
		return team ~= nil and team ~= sentence.team(lplr)
	end
	return true
end

function sentence.nearestPlayer(team, range)
	local root = sentence.root(lplr)
	if not root then return end

	local closest, distance = nil, range or math.huge
	for _, plr in playersService:GetPlayers() do
		if plr ~= lplr and (not team or sentence.isTeam(plr, team)) then
			local other = sentence.root(plr)
			if other then
				local magnitude = (other.Position - root.Position).Magnitude
				if magnitude < distance then
					closest, distance = plr, magnitude
				end
			end
		end
	end

	return closest
end

-- ReplicatedStorage.Events.<name>:FireServer, guarded because the folder is rebuilt on teleport
function sentence.fire(name, ...)
	local events = sentence.Events
	local remote = events and events:FindFirstChild(name)
	if not remote or typeof(remote.FireServer) ~= 'function' then return end

	pcall(remote.FireServer, remote, ...)
end

vape.Libraries.sentence = sentence
vape:Clean(function()
	vape.Libraries.sentence = nil
	sentence.Events = nil
end)

run(function()
	local events = replicatedStorage:FindFirstChild('Events') or replicatedStorage:WaitForChild('Events', 30)
	if vape.Loaded == nil then return end
	sentence.Events = events
end)

run(function()
	entitylib.targetCheck = function(entity, skip)
		if entity.TeamCheck then
			return entity:TeamCheck()
		end
		if entity.NPC then return true end
		return sentence.isTarget(entity.Player)
	end

	-- the downed flag decides whether a player is arrestable, so render/targeting updates on it
	entitylib.getUpdateConnections = function(entity)
		local humanoid = entity.Humanoid
		local connections = {
			humanoid:GetPropertyChangedSignal('Health'),
			humanoid:GetPropertyChangedSignal('MaxHealth')
		}

		local stats = sentence.stats(entity.Player)
		if stats then
			for _, name in {'Downed', 'Ragdolled', 'Dead'} do
				local value = stats:FindFirstChild(name)
				if value then
					table.insert(connections, value:GetPropertyChangedSignal('Value'))
				end
			end
		end

		return connections
	end

	entitylib.isVulnerable = function(entity, attackCheck, skipCheck)
		if entity.Health <= 0 then return false end
		if entity.Character:FindFirstChildWhichIsA('ForceField') then return false end
		if entity.Humanoid:GetState() == Enum.HumanoidStateType.Dead then return false end
		return entity.SpawnTime < os.clock()
	end

	entitylib.getEntityColor = function(entity)
		if not (entity.Player and useTeamColor.Enabled) then return end
		if isFriend(entity.Player, true) then
			return Color3.fromHSV(friendsColor.Hue, friendsColor.Sat, friendsColor.Value)
		end

		local team = entity.Player.Team
		return team and team.TeamColor.Color or nil
	end

	entitylib.start()
end)

-- jobs, showers, store fronts and the vents are all ProximityPrompts, and the ones that matter
-- carry a hold time between one and five seconds. The hold runs client side, so zeroing it makes
-- the prompt fire on the first frame while the server still sees a normal trigger. It lives here
-- rather than in a module because there is nothing to toggle, and the hold is rewritten every
-- time SetPromptsAndBuildBoards rebuilds a board, hence the loop
local instantPrompts = {}

local function instantPrompt(prompt)
	if instantPrompts[prompt] then return end

	instantPrompts[prompt] = true
	prompt.HoldDuration = 0
end

run(function()
	-- the selector runs inside the engine instead of walking every descendant of the map
	for _, object in workspace:QueryDescendants('ProximityPrompt') do
		instantPrompt(object)
	end

	vape:Clean(workspace.DescendantAdded:Connect(function(object)
		if object:IsA('ProximityPrompt') then
			instantPrompt(object)
		end
	end))

	vape:Clean(task.spawn(function()
		repeat
			for prompt in instantPrompts do
				if prompt.Parent then
					if prompt.HoldDuration > 0 then
						prompt.HoldDuration = 0
					end
				else
					instantPrompts[prompt] = nil
				end
			end

			task.wait(1)
		until vape.Loaded == nil
	end))
end)

run(function()
	sessioninfo:AddItem('Cash', 0, function()
		return tostring(sentence.value(lplr, 'Cash') or 0)
	end, false)

	sessioninfo:AddItem('Bounty', 0, function()
		return tostring(sentence.value(lplr, 'Bounty') or 0)
	end, false)

	sessioninfo:AddItem('Strength', 0, function()
		return tostring(sentence.value(lplr, 'Strength') or 0)
	end, false)

	table.insert(whitelist.tagcallback, function(plr, plrtag, rich)
		if not plr or not entitylib.getEntity(plr) then return end

		if sentence.isDowned(plr) then
			table.insert(plrtag, {text = rich and '💀' or 'Downed'})
		elseif sentence.isCop(plr) then
			table.insert(plrtag, {text = rich and '🛡️' or 'Guard'})
		end
	end)
end)

vape:Remove('MurderMystery')
