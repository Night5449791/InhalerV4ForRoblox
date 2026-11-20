local urban = {
	Active = false,
	HeartbeatOK = false,
	BeatCalls = 0
}

local cloneref = cloneref or function(obj)
	return obj
end
local collectionService = cloneref(game:GetService('CollectionService'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))

local playerScripts
local beatRemote
local heartbeat
local connections = {}
local tasks = {}
local oldnamecall
local hooked

local function executorFunc(name)
	local fn = getgenv and getgenv()[name] or _G[name]
	return typeof(fn) == 'function' and fn or nil
end

local function isBait(obj)
	if typeof(obj) ~= 'Instance' then return false end

	if collectionService then
		local suc, tagged = pcall(function()
			return collectionService:GetTagged('Bait')
		end)
		if suc and type(tagged) == 'table' and table.find(tagged, obj) then
			return true
		end
	end

	for _, key in {'bait', 'Bait', 'IsBait', 'AntiCheatBait'} do
		if obj:GetAttribute(key) ~= nil then return true end
		if obj:FindFirstChild(key) then return true end
	end

	return false
end

local function refreshHeartbeat()
	local script = playerScripts and playerScripts:FindFirstChild('ClientAntiCheat')
	if not script then return end
	heartbeat = script

	local t = script:GetAttribute('t')
	urban.HeartbeatOK = type(t) == 'number' and os.clock() - t < 6

	if not urban.HeartbeatOK then
		script:SetAttribute('t', os.clock())
	end
end

local function watch()
	repeat
		refreshHeartbeat()
		task.wait(0.5)
	until not urban.Active
end

local function fireServerHook(...)
	urban.BeatCalls = urban.BeatCalls + 1
	return oldnamecall(...)
end

local function installBeatWatch()
	if hooked or typeof(beatRemote) ~= 'Instance' then return end
	local hookfunction = executorFunc('hookfunction')
	if not hookfunction then return end

	oldnamecall = hookfunction(beatRemote.FireServer, typeof(newcclosure) == 'function' and newcclosure(fireServerHook) or fireServerHook)
	hooked = true
end

local function restoreBeatWatch()
	if not hooked then return end
	if oldnamecall then
		pcall(restorefunction, beatRemote and beatRemote.FireServer or oldnamecall)
	end
	oldnamecall = nil
	hooked = nil
end

urban.IsBait = isBait

function urban.Start()
	if urban.Active then return end
	urban.Active = true

	playerScripts = cloneref(game:GetService('Players').LocalPlayer:FindFirstChild('PlayerScripts'))
	local remotes = replicatedStorage and replicatedStorage:FindFirstChild('Remotes')
	beatRemote = remotes and remotes:FindFirstChild('Beat')

	refreshHeartbeat()
	installBeatWatch()

	tasks[#tasks + 1] = task.spawn(watch)
end

function urban.Stop()
	urban.Active = false
	restoreBeatWatch()

	for _, thread in tasks do
		pcall(task.cancel, thread)
	end
	table.clear(tasks)
	table.clear(connections)

	beatRemote = nil
	heartbeat = nil
	urban.HeartbeatOK = false
end

return urban
