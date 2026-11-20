local loadstring = function(...)
	local res, err = loadstring(...)
	if err and vape then vape:CreateNotification('Vape', 'Failed to load : '..err, 30, 'alert') end
	return res
end
local isfile = isfile or function(file)
	local suc, res = pcall(function() return readfile(file) end)
	return suc and res ~= nil and res ~= ''
end
local function downloadFile(path, func)
	if not isfile(path) then
		local suc, res = pcall(function() return game:HttpGet('https://raw.githubusercontent.com/Night5449791/InhalerCompiled/'..(isfile('InhalerV4/profiles/commit.txt') and readfile('InhalerV4/profiles/commit.txt') or 'main')..'/'..select(1, path:gsub('InhalerV4/', '')), true) end)
		if not suc or res == '404: Not Found' then error(res) end
		if path:find('.lua') then res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after inhaler updates.\n'..res end
		writefile(path, res)
	end
	return (func or readfile)(path)
end
local run = function(func)
	func()
end
local queue_on_teleport = queue_on_teleport or function() end
local cloneref = cloneref or function(obj)
	return obj
end

local playersService = cloneref(game:GetService('Players'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local runService = cloneref(game:GetService('RunService'))
local inputService = cloneref(game:GetService('UserInputService'))
local httpService = cloneref(game:GetService('HttpService'))
local teamsService = cloneref(game:GetService('Teams'))

local gameCamera = cloneref(workspace.CurrentCamera or workspace:FindFirstChildWhichIsA('Camera'))
local lplr = playersService.LocalPlayer
local vape = shared.vape
local entitylib = vape.Libraries.entity
local targetinfo = vape.Libraries.targetinfo
local sessioninfo = vape.Libraries.sessioninfo
local whitelist = vape.Libraries.whitelist

local urbanLoaded, urban = pcall(function()
	return loadstring(downloadFile('InhalerV4/libraries/urbananticheat.lua'), 'urbananticheat')()
end)
if urbanLoaded and urban then
	pcall(urban.Start)
	vape.Libraries.urbananticheat = urban
	vape:Clean(function()
		pcall(urban.Stop)
		vape.Libraries.urbananticheat = nil
	end)
end

local WeaponData
local Remotes = {}

run(function()
	local weapons = replicatedStorage:FindFirstChild('Weapons')
	local data = weapons and weapons:FindFirstChild('WeaponData')
	if data and data:IsA('ModuleScript') then
		local suc, result = pcall(require, data)
		if suc and type(result) == 'table' then WeaponData = result end
	end

	local remotes = replicatedStorage:FindFirstChild('Remotes')
	if remotes then
		for _, name in {'Shoot', 'Fire', 'Hit'} do
			local event = remotes:FindFirstChild(name)
			if event then Remotes[name] = event end
		end
	end

	local events = replicatedStorage:FindFirstChild('Events')
	if events then
		local dealDamage = events:FindFirstChild('DealDamage')
		if dealDamage then Remotes.DealDamage = dealDamage end
	end
end)

entitylib.targetCheck = function(entity)
	if entity.TeamCheck then
		return entity:TeamCheck()
	end
	if entity.NPC then return true end
	if table.find(vape.Categories.Friends.ListEnabled, entity.Player.Name) then return false end
	if not select(2, whitelist:get(entity.Player)) then return false end

	local team, targetTeam = lplr.Team, entity.Player.Team
	if not team or not targetTeam then return true end
	return team ~= targetTeam
end

entitylib.getEntityColor = function(entity)
	entity = entity.Player
	if not (entity and vape.Settings.Modules.Options['Use team color'].Enabled) then return end
	if table.find(vape.Categories.Friends.ListEnabled, entity.Name) then
		return Color3.fromHSV(vape.Categories.Friends.Options['Friends color'].Hue, vape.Categories.Friends.Options['Friends color'].Sat, vape.Categories.Friends.Options['Friends color'].Value)
	end
	return tostring(entity.TeamColor) ~= 'White' and entity.TeamColor.Color or nil
end

entitylib.start()

for _, v in {'Reach', 'Killaura', 'HitBoxes', 'AutoClicker', 'TargetStrafe', 'AntiFall', 'HighJump', 'LongJump', 'Invisible', 'Jesus', 'MouseTP', 'Phase', 'Fly', 'Speed', 'SpinBot', 'Spider', 'Swim', 'Timer', 'MurderMystery'} do
	vape:Remove(v)
end
