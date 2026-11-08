local run = function(func)
	func()
end
local cloneref = cloneref or function(obj)
	return obj
end

local playersService = cloneref(game:GetService('Players'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local collectionService = game:GetService('CollectionService')

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

-- everything this product reaches into the game through. the grab system is the whole
-- game: a player drags a toy to their plot, grabs a part or another player with it, and
-- flings whatever is attached by fighting the network owner
local ftap = {
	remotes = nil,
	toys = {},
	grabbed = {},
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

-- a grabbed player is ragdolled and rides on the grabber's network ownership, so the
-- two things every module asks about are "is this thing being held" and "who holds it"
function ftap.isGrabbed(ent)
	if not ent or not ent.Character then return false end

	local ragdolled = ent.Character:FindFirstChild('Humanoid')
	ragdolled = ragdolled and ragdolled:FindFirstChild('Ragdolled')

	return ragdolled ~= nil and ragdolled.Value == true
end

function ftap.isToy(obj)
	if typeof(obj) ~= 'Instance' then return false end

	-- a toy is a model the game tags when it spawns it, in the plot of whoever bought it
	return obj:IsA('Model') and (obj:GetAttribute('ToyName') ~= nil or obj.Name:find('SpawnedInToys') ~= nil)
end

function ftap.resetRemotes()
	ftap.remotes = nil
	table.clear(ftap.toys)
	table.clear(ftap.grabbed)
end

run(function()
	-- the game loads its remotes a moment after the character spawns, so this waits with a
	-- bound instead of blocking the whole product on a slow server
	local function grabRemotes()
		local menuToys = replicatedStorage:WaitForChild('MenuToys', 15)
		local grabEvents = replicatedStorage:WaitForChild('GrabEvents', 15)
		local characterEvents = replicatedStorage:WaitForChild('CharacterEvents', 15)

		if not menuToys or not grabEvents then return end

		ftap.remotes = {
			spawnToy = menuToys:FindFirstChild('SpawnToyRemoteFunction'),
			canSpawnToy = menuToys:FindFirstChild('CanSpawnToy'),
			destroyToy = menuToys:FindFirstChild('DestroyToy'),
			setNetworkOwner = grabEvents:FindFirstChild('SetNetworkOwner'),
			grabPart = grabEvents:FindFirstChild('GrabPart'),
			plusGrabPart = grabEvents:FindFirstChild('PlusGrabPart'),
			endGrabEarly = grabEvents:FindFirstChild('EndGrabEarly'),
			createGrabLine = grabEvents:FindFirstChild('CreateGrabLine'),
			extendGrabLine = grabEvents:FindFirstChild('ExtendGrabLine'),
			ragdoll = characterEvents and characterEvents:FindFirstChild('RagdollRemote'),
			struggle = characterEvents and characterEvents:FindFirstChild('Struggle'),
		}
	end

	task.spawn(function()
		repeat
			if not ftap.remotes then grabRemotes() end
			if not ftap.remotes then
				task.wait(1)
			end
		until ftap.remotes or not vape.Loaded
	end)

	-- a toy is anything the game tags once it exists in the world; the tag is what the
	-- plot uses to clean up, so it is stable across updates
	local function trackToy(obj)
		if not obj:IsA('Model') then return end
		ftap.toys[obj] = true
	end

	local function untrackToy(obj)
		ftap.toys[obj] = nil
	end

	for _, tag in {'Toy', 'SpawnedToy'} do
		for _, obj in collectionService:GetTagged(tag) do
			trackToy(obj)
		end

		vape:Clean(collectionService:GetInstanceAddedSignal(tag):Connect(trackToy))
		vape:Clean(collectionService:GetInstanceRemovedSignal(tag):Connect(untrackToy))
	end
end)

-- the game hands out a plot per player; a module that spawns toys needs the plot the local
-- player owns, and the name is always "<Name>SpawnedInToys"
function ftap.plot()
	return workspace:FindFirstChild(lplr.Name .. 'SpawnedInToys')
end

function ftap.spawnToy(toy, position)
	if not ftap.remotes or not ftap.remotes.spawnToy then return false end
	if not toy or toy == '' then return false end

	local suc = pcall(function()
		ftap.remotes.spawnToy:InvokeServer(toy, position or ftap.plot() or Vector3.zero, Vector3.zero)
	end)

	return suc
end

function ftap.destroyToy(obj)
	if not ftap.remotes or not ftap.remotes.destroyToy then return false end
	if not obj then return false end

	return pcall(function()
		ftap.remotes.destroyToy:FireServer(obj)
	end)
end

-- The fling itself: the grabber owns the network of what it holds, so handing that
-- ownership back and forth with a large velocity is what throws the target. The game
-- keeps the grab alive through SetNetworkOwner, so every fling re-asserts it.
function ftap.setOwner(part, camera)
	if not ftap.remotes or not ftap.remotes.setNetworkOwner then return false end
	if not part then return false end

	return pcall(function()
		ftap.remotes.setNetworkOwner:FireServer(part, camera or gameCamera.CFrame)
	end)
end

local function updateVelocity(ent)
	if not ent.Character then return end

	local humanoid = ent.Humanoid
	if humanoid then
		humanoid.PlatformStand = false
	end
end

vape:Clean(entitylib.Events.LocalAdded:Connect(updateVelocity))

-- every entity that is not the local player is a candidate: the game has no teams, so
-- "targetable" is decided by the friend list and the whitelist alone
entitylib.targetCheck = function(ent)
	if ent == entitylib.character then return false end
	if ent.Player and isFriend(ent.Player) then return false end

	if ent.Player then
		local level, attackable = whitelist:get(ent.Player)
		if level > 0 and not attackable then return false end
	end

	return true
end

entitylib.isVulnerable = function(ent)
	return ent.Health > 0
end

entitylib.getEntityColor = function(ent)
	if ent.Player then
		local friend = isFriend(ent.Player, true)
		if friend then
			return friendsColor.Value
		end
	end

	return nil
end

entitylib.start()

vape:Clean(ftap.resetRemotes)

-- universal ships modules that either do nothing here or would collide with this
-- product's own: `Reach` is the important one, since GamepassReach replaces it and two
-- modules under one name overwrite each other in vape.Modules
for _, module in {'AutoClicker', 'TriggerBot', 'HitBoxes', 'Killaura', 'Jesus', 'AutoRejoin', 'Disabler', 'MurderMystery', 'Parkour', 'Wallhop', 'Reach'} do
	vape:Remove(module)
end
