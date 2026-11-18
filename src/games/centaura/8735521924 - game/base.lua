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
local cloneref = cloneref or function(obj)
	return obj
end

local adonisLoaded, adonis = pcall(function()
	return loadstring(downloadFile('InhalerV4/libraries/adonis.lua'), 'adonis')()
end)
if adonisLoaded and adonis then
	pcall(adonis.Start)
elseif shared.vape then
	shared.vape:CreateNotification('Vape', 'Failed to load adonis bypass', 30, 'alert')
end

local playersService = cloneref(game:GetService('Players'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local runService = cloneref(game:GetService('RunService'))
local inputService = cloneref(game:GetService('UserInputService'))
local httpService = cloneref(game:GetService('HttpService'))
local guiService = cloneref(game:GetService('GuiService'))
local coreGui = cloneref(game:GetService('CoreGui'))

local gameCamera = workspace.CurrentCamera
local lplr = playersService.LocalPlayer
local vape = shared.vape
local entitylib = vape.Libraries.entity
local targetinfo = vape.Libraries.targetinfo
local prediction = vape.Libraries.prediction

local function canClick()
	local pos = (inputService:GetMouseLocation() - guiService:GetGuiInset())

	if gethui and gethui():IsA('BasePlayerGui') then
		for _, obj in gethui():GetGuiObjectsAtPosition(pos.X, pos.Y) do
			local holder = obj:FindFirstAncestorOfClass('ScreenGui')
			if obj.Active and obj.Visible and holder and holder.Enabled then
				return false
			end
		end
	end

	for _, obj in coreGui:GetGuiObjectsAtPosition(pos.X, pos.Y) do
		local holder = obj:FindFirstAncestorOfClass('ScreenGui')
		if obj.Active and obj.Visible and holder and holder.Enabled then
			return false
		end
	end

	for _, obj in lplr.PlayerGui:GetGuiObjectsAtPosition(pos.X, pos.Y) do
		local holder = obj:FindFirstAncestorOfClass('ScreenGui')
		if obj.Active and obj.Visible and holder and holder.Enabled then
			return false
		end
	end

	return (not vape.gui.ScaledGui.ClickGui.Visible) and (not inputService:GetFocusedTextBox())
end

local GunSettings

run(function()
	local trekModules = replicatedStorage:WaitForChild('TREKModules', 30)
	if not trekModules then return end
	GunSettings = trekModules:WaitForChild('GunSettings', 30)
end)

for _, v in {'Reach', 'Killaura', 'HitBoxes', 'AutoClicker', 'TargetStrafe', 'AntiFall', 'HighJump', 'LongJump', 'Invisible', 'Jesus', 'MouseTP', 'SpinBot', 'Spider', 'Swim', 'Timer', 'MurderMystery'} do
	vape:Remove(v)
end
