local run = function(func)
	func()
end
local cloneref = cloneref or function(obj)
	return obj
end

local playersService = cloneref(game:GetService('Players'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local httpService = game:GetService('HttpService')

local gameCamera = workspace.CurrentCamera
local lplr = playersService.LocalPlayer
local vape = shared.vape
local entitylib = vape.Libraries.entity
local targetinfo = vape.Libraries.targetinfo
local whitelist = vape.Libraries.whitelist

local friends = vape.Categories.Friends
local useFriends = friends.Options['Use friends']
local recolorFriends = friends.Options['Recolor visuals']
local friendsColor = friends.Options['Friends color']
local teamsByServer = vape.Settings.Modules.Options['Teams by server']
local useTeamColor = vape.Settings.Modules.Options['Use team color']

local bloxstrike = {
	CharacterRemote = nil,
	Inventory = nil,
	Melee = nil,
	Proxy = nil,
	Remotes = nil,
	Resolver = nil
}

local function isFriend(plr, recolor)
	if not useFriends.Enabled then return nil end

	local friend = table.find(friends.ListEnabled, plr.Name) and true
	if recolor then
		friend = friend and recolorFriends.Enabled
	end

	return friend
end

local function notif(...)
	return vape:CreateNotification(...)
end

function bloxstrike.character(obj)
	if typeof(obj) ~= 'Instance' then return end
	if obj:IsA('Player') then return obj.Character end
	if obj:IsA('Model') then return obj end
end

function bloxstrike.team(obj)
	return obj and obj:GetAttribute('Team') or nil
end

local function vitals(obj)
	local character = bloxstrike.character(obj)
	local isPlayer = typeof(obj) == 'Instance' and obj:IsA('Player')
	local health = character and character:GetAttribute('Health')
	local maxHealth = character and character:GetAttribute('MaxHealth')

	if typeof(health) ~= 'number' then
		health = isPlayer and obj:GetAttribute('Health') or nil
	end

	if typeof(maxHealth) ~= 'number' then
		maxHealth = isPlayer and obj:GetAttribute('MaxHealth') or nil
	end

	return typeof(health) == 'number' and health or 0, typeof(maxHealth) == 'number' and maxHealth or 100
end

function bloxstrike.health(obj)
	local health = vitals(obj)
	return health
end

function bloxstrike.maxHealth(obj)
	local _, maxHealth = vitals(obj)
	return maxHealth
end

function bloxstrike.dead(obj)
	local character = bloxstrike.character(obj)
	return character ~= nil and character:GetAttribute('Dead') == true
end

function bloxstrike.equipped(plr)
	local raw = typeof(plr) == 'Instance' and plr:IsA('Player') and plr:GetAttribute('CurrentEquipped') or nil
	if type(raw) ~= 'string' then return end

	local suc, data = pcall(httpService.JSONDecode, httpService, raw)
	if not suc or type(data) ~= 'table' then return end
	return data
end

run(function()
	local remotes = replicatedStorage:WaitForChild('NetworkRemotes', 30)
	bloxstrike.Remotes = remotes
	if not remotes then return end

	bloxstrike.Inventory = remotes:FindFirstChild('Inventory')
	bloxstrike.Melee = remotes:FindFirstChild('Melee')
	bloxstrike.CharacterRemote = remotes:FindFirstChild('Character')
end)

run(function()
	local components = replicatedStorage:WaitForChild('Components', 30)
	local common = components and components:WaitForChild('Common', 30)
	local module = common and common:FindFirstChild('CharacterResolver')
	if not module then return end

	local suc, resolver = pcall(require, module)
	bloxstrike.Resolver = suc and resolver or nil
end)

run(function()
	local database = replicatedStorage:WaitForChild('Database', 30)
	local security = database and database:WaitForChild('Security', 30)
	local module = security and security:FindFirstChild('Remotes')
	if not module then return end

	local suc, proxy = pcall(require, module)
	bloxstrike.Proxy = suc and proxy or nil
end)

function bloxstrike.send(section, name, packet)
	local proxy = bloxstrike.Proxy
	local remote = proxy and proxy[section] and proxy[section][name]
	if not (remote and typeof(remote.Send) == 'function') then return false end

	local suc = pcall(remote.Send, packet)
	return suc
end

local charactersFolder
local culledFolder

local function getCharacters()
	local folder = charactersFolder
	if folder and folder.Parent then return folder end

	charactersFolder = workspace:FindFirstChild('Characters')
	return charactersFolder
end

local function getCulled()
	local folder = culledFolder
	if folder and folder.Parent then return folder end

	culledFolder = replicatedStorage:FindFirstChild('_PVS_CulledCharacters')
	return culledFolder
end

local function hosted(char)
	local characters = getCharacters()
	if characters and char:IsDescendantOf(characters) then return true end

	local culled = getCulled()
	return culled ~= nil and char:IsDescendantOf(culled)
end

local function rendered(char)
	local characters = getCharacters()
	return characters ~= nil and char:IsDescendantOf(characters)
end

entitylib.Culled = {}

local function park(char)
	local entity, index = entitylib.getEntity(char)
	if not entity or not index then return end

	table.remove(entitylib.List, index)
	entitylib.Culled[char] = entity
	entitylib.Events.EntityRemoved:Fire(entity)
end

local function unpark(char)
	local entity = entitylib.Culled[char]
	if not entity then return end

	entitylib.Culled[char] = nil
	if table.find(entitylib.List, entity) then return end

	table.insert(entitylib.List, entity)
	entitylib.Events.EntityAdded:Fire(entity)
end

local function dropConnections(entity)
	for _, connection in entity.Connections do
		connection:Disconnect()
	end

	table.clear(entity.Connections)
end

local function discard(char)
	local entity = entitylib.Culled[char]
	if not entity then
		entitylib.removeEntity(char)
		return
	end

	entitylib.Culled[char] = nil
	dropConnections(entity)
end

run(function()
	local originalStop = entitylib.stop

	entitylib.stop = function()
		for _, entity in entitylib.Culled do
			dropConnections(entity)
		end

		table.clear(entitylib.Culled)
		originalStop()
	end
end)

run(function()
	local originalRemove = entitylib.removeEntity

	entitylib.removeEntity = function(char, isLocal)
		if char and entitylib.Culled[char] then
			discard(char)
			return
		end

		return originalRemove(char, isLocal)
	end
end)

local function registerCharacter(char)
	if not (typeof(char) == 'Instance' and char:IsA('Model')) then return end
	if char:GetAttribute('RagdollReady') or char:GetAttribute('RagdollStaged') then return end
	if char.Parent and char.Parent.Name == 'Debris' then return end
	if entitylib.getEntity(char) or entitylib.Culled[char] or entitylib.EntityThreads[char] then return end

	local plr = playersService:GetPlayerFromCharacter(char)
	if not plr then
		local userId = char:GetAttribute('PresentationOwnerUserId')
		if typeof(userId) == 'number' then
			plr = playersService:GetPlayerByUserId(userId)
		end
	end

	if not plr and bloxstrike.Resolver then
		local suc, found = pcall(bloxstrike.Resolver.getPlayerFromCharacter, char)
		plr = suc and found or nil
	end

	entitylib.addEntity(char, plr)
end

local watchContainer
local ParkTokens = {}

local function scanContainer(container)
	for _, child in container:GetChildren() do
		if child:IsA('Folder') then
			scanContainer(child)
		else
			registerCharacter(child)
		end
	end
end

watchContainer = function(container)
	table.insert(entitylib.Connections, container.ChildAdded:Connect(function(child)
		if child:IsA('Folder') then
			watchContainer(child)
			scanContainer(child)
			return
		end

		task.delay(0.1, registerCharacter, child)

		if rendered(child) then
			ParkTokens[child] = nil
			unpark(child)
		end
	end))

	table.insert(entitylib.Connections, container.ChildRemoved:Connect(function(child)
		if not child:IsA('Model') then return end

		task.defer(function()
			if rendered(child) then
				ParkTokens[child] = nil
				unpark(child)
				return
			end

			if not hosted(child) then
				ParkTokens[child] = nil
				discard(child)
				return
			end

			local token = {}
			ParkTokens[child] = token
			task.delay(0.5, function()
				if ParkTokens[child] ~= token then return end
				ParkTokens[child] = nil

				if rendered(child) then
					unpark(child)
				elseif hosted(child) then
					park(child)
				else
					discard(child)
				end
			end)
		end)
	end))
end

local function standInHumanoid(char, plr)
	local target = plr or char
	local health, maxHealth = vitals(target)

	return {
		Health = health,
		MaxHealth = maxHealth,
		GetState = function()
			return Enum.HumanoidStateType.Running
		end,
		MoveDirection = Vector3.zero,
		WalkSpeed = 0,
		JumpPower = 0,
		HipHeight = 0
	}
end

entitylib.addEntity = function(char, plr, teamfunc, spawntime)
	if not char then return end

	local thread = task.spawn(function()
		local root = char:FindFirstChild('HumanoidRootPart') or char:WaitForChild('HumanoidRootPart', 10)
		if not root then
			entitylib.EntityThreads[char] = nil
			return
		end

		local head = char:FindFirstChild('Head') or root
		local humanoid = char:FindFirstChildOfClass('Humanoid')
		local standIn = humanoid == nil and standInHumanoid(char, plr) or nil
		local target = plr or char
		local health, maxHealth = vitals(target)
		local entity = {
			Character = char,
			Connections = {},
			Health = health,
			Head = head,
			HipHeight = 3,
			Humanoid = humanoid or standIn,
			HumanoidRootPart = root,
			MaxHealth = maxHealth,
			NPC = plr == nil,
			Player = plr,
			RootPart = root,
			SpawnTime = spawntime or 0,
			StandIn = standIn,
			Team = bloxstrike.team(char) or bloxstrike.team(plr),
			TeamCheck = teamfunc
		}

		if plr == lplr then
			entitylib.character = entity
			entitylib.isAlive = not bloxstrike.dead(char) and entity.Health > 0
			entitylib.Events.LocalAdded:Fire(entity)

			for _, name in {'Health', 'Dead'} do
				table.insert(entity.Connections, char:GetAttributeChangedSignal(name):Connect(function()
					entity.Health = bloxstrike.health(char)
					entitylib.isAlive = not bloxstrike.dead(char)
				end))
			end
		else
			entity.Targetable = entitylib.targetCheck(entity)

			local function updateHealth()
				local health, maxHealth = vitals(target)
				entity.Health = health
				entity.MaxHealth = maxHealth

				if standIn then
					standIn.Health = entity.Health
					standIn.MaxHealth = entity.MaxHealth
				end

				entitylib.Events.EntityUpdated:Fire(entity)
			end

			local function updateGate()
				updateHealth()
				entity.Team = bloxstrike.team(char) or bloxstrike.team(plr)
				entity.Targetable = entitylib.targetCheck(entity)
			end

			for _, name in {'Health', 'MaxHealth'} do
				table.insert(entity.Connections, char:GetAttributeChangedSignal(name):Connect(updateHealth))
			end

			for _, name in {'Dead', 'Team'} do
				table.insert(entity.Connections, char:GetAttributeChangedSignal(name):Connect(updateGate))
			end

			if plr then
				for _, name in {'Dead', 'Team'} do
					table.insert(entity.Connections, plr:GetAttributeChangedSignal(name):Connect(updateGate))
				end
			end

			if rendered(char) then
				table.insert(entitylib.List, entity)
				entitylib.Events.EntityAdded:Fire(entity)
			else
				entitylib.Culled[char] = entity
			end
		end

		entitylib.EntityThreads[char] = nil
	end)

	if thread and coroutine.status(thread) ~= 'dead' then
		entitylib.EntityThreads[char] = thread
	end
end

entitylib.targetCheck = function(entity)
	if entity.TeamCheck then
		return entity:TeamCheck()
	end

	if entity.Health <= 0 then return false end

	if entity.Player then
		if isFriend(entity.Player) then return false end
		if not select(2, whitelist:get(entity.Player)) then return false end
	end

	if teamsByServer.Enabled then
		if workspace:GetAttribute('Gamemode') == 'Deathmatch' then return true end

		local myTeam = bloxstrike.team(lplr)
		if entity.Team == 'Terrorists' or entity.Team == 'Counter-Terrorists' then
			return myTeam ~= entity.Team
		end

		return false
	end

	return true
end

entitylib.addPlayer = function(plr)
	if entitylib.PlayerConnections[plr] then return end

	entitylib.PlayerConnections[plr] = {
		plr.CharacterAdded:Connect(function(char)
			task.wait(0.1)
			entitylib.refreshEntity(char, plr, os.clock() + 0.4)
		end),
		plr.CharacterRemoving:Connect(function(char)
			entitylib.removeEntity(char, plr == lplr)
		end),
		plr:GetAttributeChangedSignal('Team'):Connect(function()
			if plr == lplr then
				for _, entity in entitylib.List do
					entity.Targetable = entitylib.targetCheck(entity)
				end

				return
			end

			local entity = entitylib.getEntity(plr)
			if not entity then return end

			entity.Team = bloxstrike.team(plr)
			entity.Targetable = entitylib.targetCheck(entity)
		end)
	}

	if plr.Character then
		entitylib.refreshEntity(plr.Character, plr)
	end
end

entitylib.start = function()
	if entitylib.Running then
		entitylib.stop()
	end

	entitylib.Connections = {
		playersService.PlayerAdded:Connect(entitylib.addPlayer),
		playersService.PlayerRemoving:Connect(entitylib.removePlayer),
		workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(function()
			gameCamera = cloneref(workspace.CurrentCamera or workspace:FindFirstChildWhichIsA('Camera') or Instance.new('Camera'))
		end)
	}

	local characters = getCharacters()
	if characters then
		watchContainer(characters)
	end

	local culled = getCulled()
	if culled then
		watchContainer(culled)
	else
		table.insert(entitylib.Connections, replicatedStorage.ChildAdded:Connect(function(child)
			if child.Name ~= '_PVS_CulledCharacters' then return end

			watchContainer(child)
			scanContainer(child)
		end))
	end

	for _, plr in playersService:GetPlayers() do
		entitylib.addPlayer(plr)
	end

	if characters then
		scanContainer(characters)
	end

	if culled then
		scanContainer(culled)
	end

	local localCharacter = lplr.Character
	if localCharacter and not entitylib.character then
		entitylib.addEntity(localCharacter, lplr)
	end

	table.insert(entitylib.Connections, lplr.CharacterAdded:Connect(function(char)
		task.wait(0.1)
		entitylib.addEntity(char, lplr)
	end))

	entitylib.Running = true
end

run(function()
	entitylib.getEntityColor = function(ent)
		if not (ent.Player and useTeamColor.Enabled) then return end
		if isFriend(ent.Player, true) then
			return Color3.fromHSV(friendsColor.Hue, friendsColor.Sat, friendsColor.Value)
		end

		local team = ent.Team or bloxstrike.team(ent.Player)
		if team == 'Terrorists' then
			return Color3.fromRGB(214, 163, 74)
		elseif team == 'Counter-Terrorists' then
			return Color3.fromRGB(82, 148, 226)
		end
	end
end)

vape.Libraries.bloxstrike = bloxstrike
vape:Clean(function()
	vape.Libraries.bloxstrike = nil
	table.clear(bloxstrike)
end)

for _, v in {'AntiFall', 'DiedTP', 'Fly', 'HighJump', 'HitBoxes', 'Invisible', 'Jesus', 'Killaura', 'LongJump', 'MouseTP', 'Phase', 'Speed', 'SpinBot', 'Spider', 'Swim', 'TargetStrafe', 'Timer', 'Reach', 'AntiFeature'} do
	vape:Remove(v)
end

entitylib.start()
