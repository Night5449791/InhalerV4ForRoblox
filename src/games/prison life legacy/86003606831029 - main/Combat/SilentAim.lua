local SilentAim
local Targets
local Mode
local Range
local HitChance
local HeadshotChance
local old
local hooked
local hookedFn
local rand = Random.new()

local function getGunData(tool)
	if not tool then return end
	local module = tool:FindFirstChild('GunStates')
	if not module then return end

	local suc, data = pcall(require, module)
	if suc and type(data) == 'table' then return data end
end

local function getTarget(origin, limit)
	if rand:NextNumber(0, 100) > HitChance.Value then return end

	local part = rand:NextNumber(0, 100) < HeadshotChance.Value and 'Head' or 'RootPart'
	local entity = entitylib['Entity'..Mode.Value]({
		Range = Range.Value,
		RangePosition = limit,
		Part = part,
		Origin = origin,
		Players = Targets.Players.Enabled,
		NPCs = Targets.NPCs.Enabled,
		Wallcheck = Targets.Walls.Enabled and true or nil
	})

	if entity then
		targetinfo.Targets[entity] = os.clock() + 1
	end
	return entity, entity and entity[part]
end

local function hookFire(self, hitTable, gun, ...)
	if self ~= Remotes.ShootEvent or typeof(gun) ~= 'Instance' or not gun:IsA('Tool') then
		return old(self, hitTable, gun, ...)
	end

	local character = lplr.Character
	local head = character and character:FindFirstChild('Head')
	local muzzle = gun:FindFirstChild('Muzzle')
	if not head or not muzzle then
		return old(self, hitTable, gun, ...)
	end

	local data = getGunData(gun)
	local limit = data and data.Range or 800
	local target, targetPart = getTarget(head.Position, limit)
	if not target or not targetPart then
		return old(self, hitTable, gun, ...)
	end

	local hit = {{
		Hit = target.Character,
		Distance = (targetPart.Position - muzzle.Position).Magnitude,
		Cframe = CFrame.new(targetPart.Position, head.Position),
		RayObject = Ray.new(head.Position, (targetPart.Position - head.Position).Unit * limit)
	}}

	return old(self, hit, gun, ...)
end

SilentAim = vape.Categories.Combat:CreateModule({
	Name = 'SilentAim',
	Function = function(callback)
		if callback then
			if hooked then return end
			hookedFn = Remotes.ShootEvent and Remotes.ShootEvent.FireServer
			local suc, result = pcall(function()
				return hookfunction(hookedFn, hookFire)
			end)
			if suc and result then
				old = result
				hooked = hookedFn
			else
				vape:CreateNotification('SilentAim', 'Failed to hook ShootEvent', 5, 'alert')
			end
		else
			if hooked then
				if restorefunction then
					pcall(restorefunction, hooked)
				elseif old then
					pcall(hookfunction, hooked, old)
				end
				hooked = nil
				old = nil
			end
		end
	end,
	Tooltip = 'Silences aim by replacing the shot hit table'
})
Targets = SilentAim:CreateTargets({Players = true})
Mode = SilentAim:CreateDropdown({
	Name = 'Mode',
	List = {'Mouse', 'Position'},
	Function = function() end
})
Range = SilentAim:CreateSlider({
	Name = 'Range',
	Min = 50,
	Max = 1000,
	Default = 500,
	Suffix = 'studs'
})
HitChance = SilentAim:CreateSlider({
	Name = 'Hit Chance',
	Min = 1,
	Max = 100,
	Default = 100,
	Suffix = '%'
})
HeadshotChance = SilentAim:CreateSlider({
	Name = 'Headshot Chance',
	Min = 0,
	Max = 100,
	Default = 50,
	Suffix = '%'
})
