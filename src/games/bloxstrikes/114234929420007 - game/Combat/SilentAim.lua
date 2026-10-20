local SilentAim
local Targets
local Mode
local Part
local FOV
local Range
local Wallbang
local ShowTarget
local OriginalCreate

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
		local fromMouse = Mode.Value == 'Mouse'
		local entity = entitylib[fromMouse and 'EntityMouse' or 'EntityPosition']({
			Part = Part.Value,
			Range = fromMouse and FOV.Value or Range.Value,
			MouseOrigin = fromMouse and gameCamera.ViewportSize / 2 or nil,
			Origin = fromMouse and nil or origin,
			Players = Targets.Players.Enabled,
			NPCs = Targets.NPCs.Enabled
		})

		return entity, entity and entity[Part.Value]
	end

	local function hookBullet(self, aimingOptions, isAiming)
		local bullet = OriginalCreate(self, aimingOptions, isAiming)
		if not SilentAim.Enabled or type(bullet) ~= 'table' then return bullet end

		local origin, direction = bullet.Origin, bullet.Direction
		if typeof(origin) ~= 'Vector3' or typeof(direction) ~= 'Vector3' then return bullet end

		local entity, part = getTarget(origin)
		if not part then return bullet end

		-- Wallbang only lets the shot through wood (penetrable) surfaces; metal/stone still
		-- block, and with Wallbang off only a clear line of sight shoots
		local hit = entitylib.Wallcheck(origin, part.Position, {entity.Character})
		if hit and not (Wallbang.Enabled and (hit.Material == Enum.Material.Wood or hit.Material == Enum.Material.WoodPlanks)) then
			return bullet
		end

		bullet.Direction = (part.Position - origin).Unit
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
		Function = function(val)
			FOV.Object.Visible = val == 'Mouse'
			Range.Object.Visible = val == 'Position'
		end,
		Tooltip = 'Mouse - looks for targets near the crosshair\nPosition - looks for the closest target around you'
	})
	Part = SilentAim:CreateDropdown({
		Name = 'Part',
		List = {'Head', 'RootPart'}
	})
	FOV = SilentAim:CreateSlider({
		Name = 'FOV',
		Min = 0,
		Max = 1000,
		Default = 200,
		Suffix = function(val)
			return val == 1 and 'pixel' or 'pixels'
		end
	})
	Range = SilentAim:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 1000,
		Default = 300,
		Visible = false,
		Suffix = function(val)
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
