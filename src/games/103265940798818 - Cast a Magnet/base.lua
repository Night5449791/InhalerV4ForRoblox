local run = function(func)
	func()
end
local cloneref = cloneref or function(obj)
	return obj
end

local playersService = cloneref(game:GetService('Players'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local starterPlayer = cloneref(game:GetService('StarterPlayer'))
local inputService = cloneref(game:GetService('UserInputService'))

local vape = shared.vape
local sessioninfo = vape.Libraries.sessioninfo

local Remotes
local FishingAction
local FishingEvent
local PlayerData
local FishingController
local StoreController
local GameConfig
local CastConfig
local Casts
local Catches

local function notif(...)
	return vape:CreateNotification(...)
end

local function getContext()
	for _, v in getgc(true) do
		if type(v) == 'table' and rawget(v, 'FishingController') and rawget(v, 'PlayerData') and rawget(v, 'StoreController') then
			return v
		end
	end
end

local function canCast()
	if not FishingController or not FishingAction then return false end
	if FishingController:GetState() ~= 'Idle' then return false end
	if not FishingController:IsInZone() then return false end
	if not PlayerData.Loaded or not PlayerData.Data then return false end
	local magnet = PlayerData.Data.EquippedMagnet
	return magnet ~= nil and magnet ~= ''
end

local function perfectHold(offset)
	local zone = CastConfig.PerfectZone
	local position = math.clamp(1 - (zone / 2) + ((offset or 0) / 100), 0, 1)
	return CastConfig.CycleTime / 2 * position
end

local function currentCastId()
	if not FishingController then return nil end
	local state = FishingController:QA()
	return type(state) == 'table' and state.CastId or nil
end

local function pressCast()
	if mouse1press then
		mouse1press()
	end
end

local function releaseCast()
	if mouse1release then
		mouse1release()
	end
end

local function castAndHold(offset)
	pressCast()
	task.wait(perfectHold(offset))
	releaseCast()
end

run(function()
	local controllers = starterPlayer.StarterPlayerScripts:WaitForChild('Controllers', workspace.StreamingEnabled and math.huge or 30)
	local sharedFolder = replicatedStorage:WaitForChild('Shared', 30)

	if not controllers or not sharedFolder then return end

	Remotes = replicatedStorage:WaitForChild('Remotes', 30)
	if not Remotes then return end

	FishingAction = Remotes:WaitForChild('FishingAction')
	FishingEvent = Remotes:WaitForChild('FishingEvent')

	GameConfig = require(sharedFolder.Config.GameConfig)
	CastConfig = GameConfig.Cast

	local ctx
	repeat
		ctx = getContext()
		if not ctx then task.wait(0.25) end
	until ctx or vape.Loaded == nil

	if vape.Loaded == nil then return end

	PlayerData = ctx.PlayerData
	FishingController = ctx.FishingController
	StoreController = ctx.StoreController

	Casts = sessioninfo:AddItem('Casts', 0, nil, false)
	Catches = sessioninfo:AddItem('Catches', 0, nil, false)

	vape:Clean(FishingEvent.OnClientEvent:Connect(function(message, data)
		if message == 'ChargeAck' then
			Casts:Increment()
		elseif message == 'Caught' then
			Catches:Increment()
		end
	end))
end)

for _, v in {'AimAssist', 'Reach', 'SilentAim', 'TriggerBot', 'Killaura', 'HitBoxes', 'TargetStrafe', 'AutoClicker', 'Speed'} do
	vape:Remove(v)
end
