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

function ftap.isGrabbed(ent)
	if not ent or not ent.Character then return false end

	local ragdolled = ent.Character:FindFirstChild('Humanoid')
	ragdolled = ragdolled and ragdolled:FindFirstChild('Ragdolled')

	return ragdolled ~= nil and ragdolled.Value == true
end

function ftap.isToy(obj)
	if typeof(obj) ~= 'Instance' then return false end

	return obj:IsA('Model') and (obj:GetAttribute('ToyName') ~= nil or obj.Name:find('SpawnedInToys') ~= nil)
end

function ftap.resetRemotes()
	ftap.remotes = nil
	table.clear(ftap.toys)
	table.clear(ftap.grabbed)
end

run(function()
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

for _, module in {'AutoClicker', 'TriggerBot', 'HitBoxes', 'Killaura', 'Jesus', 'AutoRejoin', 'Disabler', 'MurderMystery', 'Parkour', 'Wallhop', 'Reach'} do
	vape:Remove(module)
end
