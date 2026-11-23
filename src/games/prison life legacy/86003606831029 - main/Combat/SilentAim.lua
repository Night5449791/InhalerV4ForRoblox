local SilentAim
local Targets
local Mode
local Range
local HitChance
local HeadshotChance
local AutoFire
local AutoFireRate
local UseGunRate
local AutoEquip
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

local function buildHit(gun)
	local character = lplr.Character
	local head = character and character:FindFirstChild('Head')
	local muzzle = gun:FindFirstChild('Muzzle')
	if not head or not muzzle then return end

	local data = getGunData(gun)
	local limit = data and data.Range or 800
	local target, targetPart = getTarget(head.Position, limit)
	if not target or not targetPart then return end

	return {{
		Hit = target.Character,
		Distance = (targetPart.Position - muzzle.Position).Magnitude,
		Cframe = CFrame.new(targetPart.Position, head.Position),
		RayObject = Ray.new(head.Position, (targetPart.Position - head.Position).Unit * limit)
	}}
end

local function hookFire(self, hitTable, gun, ...)
	if self ~= Remotes.ShootEvent or typeof(gun) ~= 'Instance' or not gun:IsA('Tool') then
		return old(self, hitTable, gun, ...)
	end

	return old(self, buildHit(gun) or hitTable, gun, ...)
end

SilentAim = vape.Categories.Combat:CreateModule({
	Name = 'SilentAim',
	Function = function(callback)
		if callback then
			AutoFireRate.Object.Visible = AutoFire.Enabled
			UseGunRate.Object.Visible = AutoFire.Enabled
			AutoEquip.Object.Visible = AutoFire.Enabled

			if hooked then return end
			hookedFn = Remotes.ShootEvent and Remotes.ShootEvent.FireServer
			local suc, result = pcall(function()
				return hookfunction(hookedFn, hookFire)
			end)
			if not suc or not result then
				vape:CreateNotification('SilentAim', 'Failed to hook ShootEvent', 5, 'alert')
				return
			end

			old = result
			hooked = hookedFn

			local fireDelay = 0
			repeat
				if AutoFire.Enabled and old and entitylib.isAlive and Remotes.ShootEvent then
					local now = os.clock()
					if now >= fireDelay then
						local character = lplr.Character
						local tool = character and character:FindFirstChildWhichIsA('Tool')
						local data = getGunData(tool)

						if not data and AutoEquip.Enabled then
							local backpack = lplr:FindFirstChildWhichIsA('Backpack')
							if backpack then
								for _, candidate in backpack:GetChildren() do
									if candidate:IsA('Tool') and candidate:FindFirstChild('GunStates') then
										character.Humanoid:EquipTool(candidate)
										break
									end
								end
							end
						elseif data and (data.CurrentAmmo or 1) > 0 then
							local hit = buildHit(tool)
							if hit then
								pcall(old, Remotes.ShootEvent, hit, tool)
								local rate = UseGunRate.Enabled and data.FireRate and (1 / math.max(data.FireRate, 0.01)) or AutoFireRate.Value
								fireDelay = now + 1 / math.max(rate, 1)
							end
						end
					end
				end
				task.wait()
			until not SilentAim.Enabled
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
AutoFire = SilentAim:CreateToggle({
	Name = 'Auto Fire',
	Function = function(callback)
		AutoFireRate.Object.Visible = callback
		UseGunRate.Object.Visible = callback
		AutoEquip.Object.Visible = callback
	end,
	Tooltip = 'Fires at the aimed target using the gun fire rate'
})
AutoFireRate = SilentAim:CreateSlider({
	Name = 'Fire Rate',
	Min = 1,
	Max = 30,
	Default = 10,
	Visible = false,
	Suffix = '/s'
})
UseGunRate = SilentAim:CreateToggle({
	Name = 'Use Gun Rate',
	Default = true,
	Visible = false,
	Tooltip = 'Uses the equipped gun fire rate instead of the slider'
})
AutoEquip = SilentAim:CreateToggle({
	Name = 'Auto Equip',
	Visible = false,
	Tooltip = 'Equips a gun from the backpack when none is held'
})
