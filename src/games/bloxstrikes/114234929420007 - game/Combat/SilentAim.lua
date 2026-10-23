local SilentAim
local Targets
local Mode
local HitChance
local HeadshotChance
local Range
local Wallbang
local ShowTarget
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

	-- the shot packet is built on the client: Weapon picks the muzzle, asks Bullet:create for
	-- one {Origin, Direction, Distance, Hits} per bullet and ships Direction to the server
	-- through Inventory.ShootWeapon, which raycasts along it. Rewriting Direction where the
	-- bullet object is returned is therefore enough to move the real shot, without touching
	-- the packet layout or the sequence counters the server checks.
	local function getTarget(origin)
		-- a failed roll leaves the shot untouched, so the aim lands as often as the chance
		-- allows and the misses look like ordinary bad aim
		if rand:NextNumber(0, 100) > HitChance.Value then return end

		local targetPart = rand:NextNumber(0, 100) < HeadshotChance.Value and 'Head' or 'RootPart'
		local fromMouse = Mode.Value == 'Mouse'
		local entity = entitylib[fromMouse and 'EntityMouse' or 'EntityPosition']({
			Part = targetPart,
			Range = Range.Value,
			MouseOrigin = fromMouse and gameCamera.ViewportSize / 2 or nil,
			Origin = fromMouse and nil or origin,
			Players = Targets.Players.Enabled,
			NPCs = Targets.NPCs.Enabled
		})

		return entity, entity and entity[targetPart]
	end

	-- reused every shot so the wall check does not allocate a fresh ignore table
	local ignore = {}

	local function hookBullet(self, aimingOptions, isAiming)
		local bullet = OriginalCreate(self, aimingOptions, isAiming)
		if not SilentAim.Enabled or type(bullet) ~= 'table' then return bullet end

		local origin, direction = bullet.Origin, bullet.Direction
		if typeof(origin) ~= 'Vector3' or typeof(direction) ~= 'Vector3' then return bullet end

		local entity, part = getTarget(origin)
		if not part then return bullet end

		local position = part.Position
		ignore[1] = entity.Character

		-- Wallbang only lets the shot through wood (penetrable) surfaces; metal/stone still
		-- block, and with Wallbang off only a clear line of sight shoots
		local hit = entitylib.Wallcheck(origin, position, ignore)
		if hit and not (Wallbang.Enabled and (hit.Material == Enum.Material.Wood or hit.Material == Enum.Material.WoodPlanks)) then
			return bullet
		end

		bullet.Direction = (position - origin).Unit
		if ShowTarget.Enabled then
			targetinfo.Targets[entity] = os.clock() + 1
		end

		return bullet
	end

	-- a re-inject leaves the previous chunk alive, and a hook it left installed would otherwise be
	-- captured as the "original" and wrapped a second time, which ends with create calling a
	-- function that no longer exists. The original and the last hook are kept in shared, so a
	-- later copy of this file can still tell them apart.
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
			-- the same slider drives the entity lookup: pixels around the crosshair in
			-- Mouse mode, studs around the character in Position mode
			if Mode.Value == 'Mouse' then
				return val == 1 and 'pixel' or 'pixels'
			end

			return val == 1 and 'stud' or 'studs'
		end
	})
	Wallbang = SilentAim:CreateToggle({
		Name = 'Wallbang',
		Default = true,
		Tooltip = 'Redirects the shot through wood walls only'
	})
	ShowTarget = SilentAim:CreateToggle({
		Name = 'Show target info'
	})
end)
