local SilentAim
local Targets
local Mode
local Range
local HitChance
local HeadshotChance
local IgnoredScripts
-- the previous metamethod lives in a table because this execution environment copies closure
-- upvalues when a hook is installed, so a plain local filled in afterwards stays nil inside it
local hook = {}
local installed
local rand = Random.new()

-- every shot ends in workspace:Raycast(origin, direction), which the interpreter treats as a
-- namecall, so the direction can be rewritten on the way out. Only the direction changes: the
-- muzzle, the spread and the cooldown stay the game's, and the shot is still aimed at an enemy
-- the crosshair already covers
local function getTarget(origin)
	if rand.NextNumber(rand, 0, 100) > HitChance.Value then
		return
	end

	local part = rand.NextNumber(rand, 0, 100) < HeadshotChance.Value and 'Head' or 'RootPart'
	local entity = entitylib['Entity'..Mode.Value]({
		Range = Range.Value,
		Wallcheck = Targets.Walls.Enabled or nil,
		Part = part,
		Origin = origin,
		Players = Targets.Players.Enabled,
		NPCs = Targets.NPCs.Enabled
	})

	if entity then
		targetinfo.Targets[entity] = os.clock() + 1
	end

	return entity, entity and entity[part], origin
end

local function raycast(args)
	if typeof(args[1]) ~= 'Vector3' or typeof(args[2]) ~= 'Vector3' then return end
	if args[3] and typeof(args[3]) ~= 'RaycastParams' then return end

	local entity, part, origin = getTarget(args[1])
	if not entity then return end

	args[2] = CFrame.lookAt(origin, part.Position).LookVector * args[2].Magnitude
end

local function namecallHook(...)
	if not hook.Active or getnamecallmethod() ~= 'Raycast' or checkcaller() then
		return hook.Method(...)
	end

	local caller = getcallingscript()
	if typeof(caller) == 'Instance' and caller then
		if table.find(IgnoredScripts.ListEnabled, tostring(caller)) then
			return hook.Method(...)
		end
	end

	local self, args = ..., {select(2, ...)}
	raycast(args)
	return hook.Method(self, unpack(args))
end

-- the hook is installed once and only its flag is flipped afterwards: restoring __namecall with
-- restorefunction leaves the hook in place in this execution environment, and a second install
-- would then capture our own closure as the "original" and recurse on every namecall
local function installHook()
	if installed then return true end
	if typeof(hookmetamethod) ~= 'function' then return false end

	local rawMeta = getrawmetatable(game)
	if typeof(rawMeta) ~= 'table' or typeof(rawMeta.__namecall) ~= 'function' then return false end

	hook.Method = rawMeta.__namecall
	if hookmetamethod(game, '__namecall', namecallHook) == namecallHook then
		return false
	end

	installed = true
	return true
end

SilentAim = vape.Categories.Combat:CreateModule({
	Name = 'SilentAim',
	Function = function(callback)
		if not callback then
			hook.Active = false
			return
		end

		if not installHook() then
			vape:CreateNotification('SilentAim', 'This executor cannot hook the namecall metamethod', 10, 'warning')
			return
		end

		hook.Active = true
	end,
	Tooltip = 'Moves the shot onto the closest enemy, the crosshair itself never moves'
})
Targets = SilentAim:CreateTargets({
	Players = true,
	Walls = true
})
Mode = SilentAim:CreateDropdown({
	Name = 'Mode',
	List = {'Mouse', 'Position'},
	Tooltip = 'Mouse - looks for targets around the crosshair\nPosition - looks for the closest target around you'
})
Range = SilentAim:CreateSlider({
	Name = 'Range',
	Min = 1,
	Max = 1000,
	Default = 150,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end
})
HitChance = SilentAim:CreateSlider({
	Name = 'Hit chance',
	Min = 0,
	Max = 100,
	Default = 100,
	Suffix = '%'
})
HeadshotChance = SilentAim:CreateSlider({
	Name = 'Headshot chance',
	Min = 0,
	Max = 100,
	Default = 65,
	Suffix = '%'
})
IgnoredScripts = SilentAim:CreateTextList({
	Name = 'Ignored scripts',
	Default = {'CameraModule'}
})
