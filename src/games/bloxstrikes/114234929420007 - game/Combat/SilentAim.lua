local SilentAim
local Targets
local Mode
local HitChance
local HeadshotChance
local Range
local ShowTarget
local AutoFire
local OriginalCreate
local rand = Random.new()

run(function()
	local components = replicatedStorage:FindFirstChild('Components')
	local weapon = components and components:FindFirstChild('Weapon')
	local classes = weapon and weapon:FindFirstChild('Classes')
	local module = classes and classes:FindFirstChild('Bullet')
	if not module then return end

	local suc, Bullet = pcall(require, module)
	if not suc or typeof(Bullet.create) ~= 'function' then return end

	local entityMouse = entitylib.EntityMouse
	local entityPosition = entitylib.EntityPosition

	local function getTarget(origin)
		if rand:NextNumber(0, 100) > HitChance.Value then return end

		local targetPart = rand:NextNumber(0, 100) < HeadshotChance.Value and 'Head' or 'RootPart'
		local fromMouse = Mode.Value == 'Mouse'
		local entity = (fromMouse and entityMouse or entityPosition)({
			Part = targetPart,
			Range = Range.Value,
			MouseOrigin = fromMouse and gameCamera.ViewportSize / 2 or nil,
			Origin = fromMouse and nil or origin,
			Players = Targets.Players.Enabled,
			NPCs = Targets.NPCs.Enabled
		})

		return entity, entity and entity[targetPart]
	end

	local ignore = {}

	local weapon, hookBullet

	local function findWeapon()
		if typeof(getgc) ~= 'function' then return end

		for _, v in getgc(true) do
			if type(v) == 'table' and rawget(v, 'IsEquipped') == true and type(rawget(v, 'Identifier')) == 'string' then
				return v
			end
		end
	end

	local function currentWeapon()
		local active = weapon
		if active and rawget(active, 'IsEquipped') == true and rawget(active, 'IsDestroyed') ~= true then
			return active
		end

		weapon = findWeapon()
		return weapon
	end

	local gateIgnore = {}

	local function reachable()
		local localEntity = entitylib.character
		if not (entitylib.isAlive and localEntity) then return false end

		local root = localEntity.RootPart
		if not root then return false end

		local origin = root.Position
		local entity = entityPosition({
			Part = 'RootPart',
			Range = Range.Value,
			Origin = origin,
			Players = Targets.Players.Enabled,
			NPCs = Targets.NPCs.Enabled
		})

		if not entity or not entity.RootPart then return false end

		gateIgnore[1] = localEntity.Character
		gateIgnore[2] = entity.Character

		return entitylib.Wallcheck(origin, entity.RootPart.Position, gateIgnore) == nil
	end

	local gateSeconds = 0.15

	local function autoFireLoop()
		local gateUntil, gateOk = 0, false

		repeat
			task.wait()

			if AutoFire.Enabled and SilentAim.Enabled and Bullet.create == hookBullet then
				local now = os.clock()
				if now >= gateUntil then
					gateOk = reachable()
					gateUntil = now + gateSeconds
				end

				local active = gateOk and currentWeapon()
				if active then
					pcall(active.shoot, active)
				end
			end
		until not AutoFire.Enabled
	end

	hookBullet = function(self, aimingOptions, isAiming)
		weapon = rawget(self, 'Weapon') or weapon

		local bullet = OriginalCreate(self, aimingOptions, isAiming)
		if not SilentAim.Enabled or type(bullet) ~= 'table' then return bullet end

		local origin, direction = bullet.Origin, bullet.Direction
		if typeof(origin) ~= 'Vector3' or typeof(direction) ~= 'Vector3' then return bullet end

		local entity, part = getTarget(origin)
		if not part then return bullet end

		local position = part.Position
		ignore[1] = entity.Character

		if entitylib.Wallcheck(origin, position, ignore) then
			return bullet
		end

		bullet.Direction = (position - origin).Unit
		if ShowTarget.Enabled then
			targetinfo.Targets[entity] = os.clock() + 1
		end

		return bullet
	end

	local function installHook()
		if Bullet.create == hookBullet then return end

		local previous = shared.__bloxstrikeBullet
		if previous and Bullet.create == previous.Hook then
			OriginalCreate = previous.Original
		else
			OriginalCreate = Bullet.create
		end

		Bullet.create = hookBullet
		shared.__bloxstrikeBullet = {
			Hook = hookBullet,
			Original = OriginalCreate
		}
	end

	local function removeHook()
		if not OriginalCreate then return end

		local previous = shared.__bloxstrikeBullet
		if Bullet.create == hookBullet or (previous and Bullet.create == previous.Hook) then
			Bullet.create = OriginalCreate
		end

		OriginalCreate = nil
		shared.__bloxstrikeBullet = nil
	end

	SilentAim = vape.Categories.Combat:CreateModule({
		Name = 'SilentAim',
		Function = function(callback)
			if callback then
				installHook()
			else
				removeHook()
			end
		end,
		Tooltip = 'Moves the shot direction onto the target, the crosshair itself never moves'
	})

	Targets = SilentAim:CreateTargets({
		Players = true,
		NPCs = true
	})
	Mode = SilentAim:CreateDropdown({
		Name = 'Mode',
		List = {'Mouse', 'Position'},
		Tooltip = 'Mouse - looks for targets near the crosshair\nPosition - looks for the closest target around you'
	})
	HitChance = SilentAim:CreateSlider({
		Name = 'Hit Chance',
		Min = 0,
		Max = 100,
		Default = 100,
		Suffix = '%',
		Tooltip = 'Chance that the shot is redirected onto the target'
	})
	HeadshotChance = SilentAim:CreateSlider({
		Name = 'Headshot Chance',
		Min = 0,
		Max = 100,
		Default = 65,
		Suffix = '%',
		Tooltip = 'Chance that the shot is aimed at the head instead of the body'
	})
	Range = SilentAim:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 1000,
		Default = 300,
		Suffix = function(val)
			if Mode.Value == 'Mouse' then
				return val == 1 and 'pixel' or 'pixels'
			end

			return val == 1 and 'stud' or 'studs'
		end
	})
	ShowTarget = SilentAim:CreateToggle({
		Name = 'Show target info'
	})
	AutoFire = SilentAim:CreateToggle({
		Name = 'Auto Fire',
		Tooltip = 'Fires while a target is in range; the weapon keeps its own ammo and fire rate',
		Function = function(callback)
			if not callback then return end

			weapon = weapon or findWeapon()
			task.spawn(autoFireLoop)
		end
	})
end)
