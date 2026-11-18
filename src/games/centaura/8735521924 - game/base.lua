local run = function(func)
	func()
end
local cloneref = cloneref or function(obj)
	return obj
end

local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))

local gameCamera = workspace.CurrentCamera
local vape = shared.vape
local entitylib = vape.Libraries.entity
local targetinfo = vape.Libraries.targetinfo

local GunSettings

run(function()
	local trekModules = replicatedStorage:WaitForChild('TREKModules', 30)
	if not trekModules then return end
	GunSettings = trekModules:WaitForChild('GunSettings', 30)
end)

for _, v in {'SilentAim', 'Reach', 'Killaura', 'HitBoxes', 'AutoClicker', 'TargetStrafe', 'AntiFall', 'HighJump', 'LongJump', 'Invisible', 'Jesus', 'MouseTP', 'Phase', 'Fly', 'Speed', 'SpinBot', 'Spider', 'Swim', 'Timer', 'AntiFeature', 'MurderMystery'} do
	vape:Remove(v)
end
