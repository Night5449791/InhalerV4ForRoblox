local SilentAim
local Targets
local Mode
local HitChance
local HeadshotMode
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

	local dynamicCap = 75
	local jumpCap = 65
	local movingCap = 50
	local stillCap = 35

	-- dynamic mode rides the local player's own movement: standing still keeps headshots
	-- rare, running lifts them, and being airborne caps it, so the rate never reads as a
	-- constant and never climbs past the static ceiling. this game drives the character with
	-- an AnimationController, so there is no Humanoid:GetState - the vertical velocity is the
	-- only signal for "in the air"
	local function dynamicHeadshotChance()
		local entity = entitylib.character
		local humanoid = entity and entity.Humanoid
		local root = entity and entity.RootPart
		if not humanoid or not root then return stillCap end

		local velocity = root.AssemblyLinearVelocity
		local moving = humanoid.MoveDirection.Magnitude > 0.1
		local horizontal = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		local airborne = math.abs(velocity.Y) > 4

		local ceiling = stillCap
		if airborne then
			ceiling = jumpCap
		elseif moving or horizontal > 8 then
			ceiling = movingCap
		end

		if ceiling > dynamicCap then
			ceiling = dynamicCap
		end

		return rand:NextNumber(0, ceiling)
	end

	local function headshotChance()
		if HeadshotMode.Value == 'Dynamic' then
			return dynamicHeadshotChance()
		end

		return HeadshotChance.Value
	end

	local function getTarget(origin)
		if rand:NextNumber(0, 100) > HitChance.Value then return end

		local targetPart = rand:NextNumber(0, 100) < headshotChance() and 'Head' or 'RootPart'
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

	local weapon, hookBullet, installHook

	local function findWeapon()
		if typeof(getgc) ~= 'function' then return end

		-- a destroyed weapon keeps its IsEquipped flag until the game recycles it, so skip
		-- those or the loop fires at a dead table and every shot silently fails
		for _, v in getgc(true) do
			if type(v) == 'table' and rawget(v, 'IsEquipped') == true and rawget(v, 'IsDestroyed') ~= true and type(rawget(v, 'Identifier')) == 'string' then
				return v
			end
		end
	end

	local function currentWeapon()
		local active = weapon
		if active and rawget(active, 'IsEquipped') == true and rawget(active, 'IsDestroyed') ~= true then
			return active
		end

		-- keep the cache when a scan misses, otherwise one unlucky getgc pass drops the
		-- weapon and every later frame has to rescan
		local found = findWeapon()
		if found then
			weapon = found
		end

		return found
	end

	local gateIgnore = {}

	local function reachable()
		local localEntity = entitylib.character
		if not (entitylib.isAlive and localEntity) then return false end

		local root = localEntity.RootPart
		if not root then return false end

		local origin = root.Position
		local fromMouse = Mode.Value == 'Mouse'
		-- mirror getTarget: Mouse mode measures pixels from the crosshair, Position mode
		-- measures studs from the character, so the gate must use the same selector
		local entity = (fromMouse and entityMouse or entityPosition)({
			Part = 'RootPart',
			Range = Range.Value,
			MouseOrigin = fromMouse and gameCamera.ViewportSize / 2 or nil,
			Origin = fromMouse and nil or origin,
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

			if AutoFire.Enabled and SilentAim.Enabled then
				-- the game can swap the Bullet module out from under us, which leaves the hook
				-- detached and stops the loop for good, so reinstall it instead of bailing
				if Bullet.create ~= hookBullet then
					installHook()
				end

				local now = os.clock()
				if now >= gateUntil then
					gateOk = reachable()
					gateUntil = now + gateSeconds
				end

				local active = gateOk and currentWeapon()
				if active and (rawget(active, 'NextShotDue') or 0) <= now then
					pcall(active.shoot, active)
				end
			end
		until not AutoFire.Enabled
	end

	hookBullet = function(self, aimingOptions, isAiming)
		local selfWeapon = rawget(self, 'Weapon')
		if type(selfWeapon) == 'table' and rawget(selfWeapon, 'IsDestroyed') ~= true then
			weapon = selfWeapon
		end

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

	installHook = function()
		if Bullet.create == hookBullet then return end

		-- reuse the original only when it came from this same module; a swapped module has
		-- its own create and capturing the stale one would call a dead function
		local previous = shared.__bloxstrikeBullet
		if previous and previous.Module == Bullet then
			OriginalCreate = previous.Original
		else
			OriginalCreate = Bullet.create
		end

		Bullet.create = hookBullet
		shared.__bloxstrikeBullet = {
			Hook = hookBullet,
			Original = OriginalCreate,
			Module = Bullet
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
	HeadshotMode = SilentAim:CreateDropdown({
		Name = 'Headshot Chance',
		List = {'Static', 'Dynamic'},
		Function = function(val)
			HeadshotChance.Object.Visible = val == 'Static'
		end,
		Tooltip = 'Static - uses the headshot slider\nDynamic - randomizes it from your movement and jumps, capped at 75%'
	})
	HeadshotChance = SilentAim:CreateSlider({
		Name = 'Headshot Chance',
		Min = 0,
		Max = 100,
		Default = 65,
		Suffix = '%',
		Tooltip = 'Chance that the shot is aimed at the head instead of the body'
	})
	HeadshotChance.Object.Visible = HeadshotMode.Value == 'Static'
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
