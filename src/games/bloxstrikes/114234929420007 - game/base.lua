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

-- the option objects are created once when the gui loads and profiles only flip Enabled, so
-- they are resolved here instead of hashing the same three names on every target check
local friends = vape.Categories.Friends
local useFriends = friends.Options['Use friends']
local recolorFriends = friends.Options['Recolor visuals']
local friendsColor = friends.Options['Friends color']
local teamsByServer = vape.Settings.Modules.Options['Teams by server']
local useTeamColor = vape.Settings.Modules.Options['Use team color']

-- BloxStrike (universe 7633926880, this base is the root place 114234929420007) is a
-- client authoritative 5v5 shooter that also rotates into a zombies survival mode:
--   Workspace.Characters   every living model, players and bots alike (Folder Terrorists,
--                          Folder Counter-Terrorists, Folder Hostages, plus loose models)
--   Workspace.Debris       recycled ragdolls that still carry the Bot attribute
--   NetworkRemotes         Inventory.ShootWeapon / Inventory.BuyMenuPurchase / Melee.MeleeAttack
--   Remotes.BAC            the anti cheat endpoint
-- Players and bot models store their side in a 'Team' attribute ('Counter-Terrorists' or
-- 'Terrorists') and their health in 'Health' / 'MaxHealth' / 'Dead' attributes. There is no
-- Team service at all, and remote characters are presentation rigs without a Humanoid, so
-- both the team gate and the entity library have to read the attributes instead.
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

-- the health of a player lives on both the player and his character, a bot only has the
-- character copy, and a pooled ragdoll keeps the values of the bot it belonged to; the
-- character is resolved once for both numbers because every health update asks for both
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

-- the equipped item is serialized into a JSON attribute, and it is the only place that holds
-- the Identifier the shoot and melee packets are keyed on
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

-- every remote is used through Database.Security.Remotes, which returns proxy tables with a
-- Send method on top of NetworkRemotes (it encodes the payload before the FireServer), so
-- anything sent from here has to go through the same proxy instead of the RemoteEvent
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

-- the client only keeps the characters it currently renders in Workspace.Characters. Every
-- character it culls (behind you, across the map, or dead) is reparented into
-- ReplicatedStorage._PVS_CulledCharacters with its position and attributes left intact, so both
-- containers are tracked and a character moving between them must keep its entity: dropping it
-- on the move is what makes the esp and the aura appear and disappear on their own.
-- Both containers are looked up on every PVS border crossing (measured at ~7 crossings a
-- second on a full server), and FindFirstChild is a children scan, so the instance is kept
-- and only re-resolved when the cached one has been removed from the tree (map change).
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

-- a parked character is one the game stopped simulating: its rig is anchored in the PVS pool and
-- no new transform ever arrives, so drawing it would only paint a frozen corpse of a box. The
-- entity is kept out of entitylib.List (esp, aura and aim stop seeing it) but stays alive with
-- its connections, so the same object is put back when the game loads that part of the map again.
-- This is always on: culled characters are never drawn at their last known position.
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

-- the same disconnect pass runs when a parked entity is thrown away and when the library
-- stops, so it is one function instead of two copies
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

-- parked entities are not in the list, so the library's own removal would leave them connected
-- and a refresh would end up with two entities on the same character
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

-- everything that can be shot at is a model under Workspace.Characters, bots included: they
-- are not in Players, they carry Bot = true, and the recycled ragdolls in Workspace.Debris
-- carry the same attributes, so those are skipped before anything is registered
local function registerCharacter(char)
	if not (typeof(char) == 'Instance' and char:IsA('Model')) then return end
	if char:GetAttribute('RagdollReady') or char:GetAttribute('RagdollStaged') then return end
	if char.Parent and char.Parent.Name == 'Debris' then return end
	if entitylib.getEntity(char) or entitylib.Culled[char] or entitylib.EntityThreads[char] then return end

	-- the game keeps its own player <-> character map, so a character is resolved the way it
	-- does: Player.Character first, then PresentationOwnerUserId, then CharacterResolver. A
	-- model that resolves to nothing is a bot and is registered as an NPC.
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

		-- the rig parts are a moment behind the reparent, but the signal thread does not have
		-- to sit through it: the unpark below is independent of the rig being complete
		task.delay(0.1, registerCharacter, child)

		if rendered(child) then
			-- coming back cancels a park that was still waiting out the debounce
			ParkTokens[child] = nil
			unpark(child)
		end
	end))

	table.insert(entitylib.Connections, container.ChildRemoved:Connect(function(child)
		if not child:IsA('Model') then return end

		-- the model may only have moved into or out of the PVS pool, so give the reparent a
		-- frame and check where it landed before the entity is thrown away
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

			-- a character that keeps crossing the PVS border would otherwise add and drop its
			-- esp drawings every frame, so the park only lands after it stayed out for a moment
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

-- remote characters are presentation rigs (AnimationController only), so the framework gets a
-- stand in that answers the two fields the entity library and the render modules read
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

-- entitylib.getUpdateConnections is not overridden: the only caller is the library's own
-- addEntity, which this file replaces below, so the signals this product needs are the ones
-- addEntity connects itself

entitylib.addEntity = function(char, plr, teamfunc, spawntime)
	if not char then return end

	-- task.spawn runs the body right away and it only yields while the rig parts are missing, so
	-- a body that finished on this tick has to be dropped instead of stored back as a dead thread
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

			-- the local rig really does have a Humanoid, so only the entity copy is touched
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

			-- health changes on every hit, so it only refreshes the values; the team gate is the
			-- part that runs the friend and whitelist lookups and those only change on death or
			-- a side swap
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

			-- a character that enters the game outside of Workspace.Characters is already culled
			-- by the game, so it goes straight into the parked pool instead of the drawable list
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

-- the library default reads Player.Team and counts Team:GetPlayers(), neither of which exists
-- in this game, so the side is compared through the attribute that players and bots share
entitylib.targetCheck = function(entity)
	if entity.TeamCheck then
		return entity:TeamCheck()
	end

	-- dead players lose their Team attribute here, so without this a corpse would come back as
	-- targetable for everyone
	if entity.Health <= 0 then return false end

	if entity.Player then
		if isFriend(entity.Player) then return false end
		if not select(2, whitelist:get(entity.Player)) then return false end
	end

	-- mirror the game's own isEnemy (Controllers/ESPController): Deathmatch is free-for-all, and
	-- a target whose team is neither Terrorists nor Counter-Terrorists (nil during warmup) is not
	-- a valid enemy either
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

	-- the model is rebuilt on every death, and the character is a custom presentation model, so
	-- the entity is thrown away and rebuilt instead of being updated in place
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
				-- refresh() would remove and re-add every entity just to re-run the team gate,
				-- which drops and recreates every esp drawing on each side swap
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

-- the local rig is an anchored presentation model with no Humanoid, so the physics-based
-- universal Blatant modules cannot drive it; drop every one of them, plus the inapplicable
-- Combat/Utility modules
for _, v in {'AntiFall', 'DiedTP', 'Fly', 'HighJump', 'HitBoxes', 'Invisible', 'Jesus', 'Killaura', 'LongJump', 'MouseTP', 'Phase', 'Speed', 'SpinBot', 'Spider', 'Swim', 'TargetStrafe', 'Timer', 'Reach', 'AntiRagdoll'} do
	vape:Remove(v)
end

entitylib.start()
