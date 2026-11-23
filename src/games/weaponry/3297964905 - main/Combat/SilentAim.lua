local SilentAim
local Targets
local Mode
local Range
local HitChance
local HeadshotChance
local AutoFire
local AutoFireRate
local oldFire
local oldHit
local hookedFire
local hookedHit
local lastOrigin
local lastTarget
local lastPart
local aimUntil = 0
local rand = Random.new()
local vim = game:GetService('VirtualInputManager')

local function pressMouse(down)
	if down and typeof(mouse1press) == 'function' then
		mouse1press()
		return
	end
	if not down and typeof(mouse1release) == 'function' then
		mouse1release()
		return
	end
	vim:SendMouseButtonEvent(0, 0, 0, down, game, 0)
end

local function getTarget(origin, limit)
	if rand:NextNumber(0, 100) > HitChance.Value then return end

	local part = rand:NextNumber(0, 100) < HeadshotChance.Value and 'Head' or 'RootPart'
	local entity = entitylib['Entity'..Mode.Value]({
		Range = math.min(Range.Value, limit or Range.Value),
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

local function aim(origin)
	local entity, part = getTarget(origin, Range.Value)
	if not entity or not part then return end

	lastOrigin = origin
	lastTarget = entity
	lastPart = part
	aimUntil = os.clock() + 1
	return part.Position, entity
end

local function hookFire(self, action, a, b, ...)
	if self ~= Remotes.WeaponHandler then
		return oldFire(self, action, a, b, ...)
	end

	if action == 1 and type(b) == 'table' and b.InitialPos then
		local position = aim(b.InitialPos)
		if position then
			b.MouseDir = (position - b.InitialPos).Unit
			b.MouseHitToOriginMag = (position - b.InitialPos).Magnitude
		end
	elseif action == 2 and type(b) == 'table' and b.RayDir and os.clock() < aimUntil and lastOrigin and lastPart then
		b.RayDir = (lastPart.Position - lastOrigin).Unit
	end

	return oldFire(self, action, a, b, ...)
end

local function hookHit(self, hitTable, ...)
	if self ~= Remotes.HitHandler or type(hitTable) ~= 'table' or os.clock() > aimUntil or not lastPart then
		return oldHit(self, hitTable, ...)
	end

	hitTable.HitObj = lastPart
	hitTable.HitPos = lastPart.Position
	hitTable.HitChar = lastTarget.Character
	hitTable.HitPlr = lastTarget.Player
	hitTable.isHitbox = true
	hitTable.isChar = true
	hitTable.Distance = (lastPart.Position - (lastOrigin or lastPart.Position)).Magnitude
	aimUntil = 0

	return oldHit(self, hitTable, ...)
end

SilentAim = vape.Categories.Combat:CreateModule({
	Name = 'SilentAim',
	Function = function(callback)
		if callback then
			AutoFireRate.Object.Visible = AutoFire.Enabled

			if hookedFire then return end

			local fireFn = Remotes.WeaponHandler and Remotes.WeaponHandler.FireServer
			local hitFn = Remotes.HitHandler and Remotes.HitHandler.InvokeServer

			local sucFire, resultFire = pcall(function()
				return hookfunction(fireFn, hookFire)
			end)
			local sucHit, resultHit = pcall(function()
				return hookfunction(hitFn, hookHit)
			end)

			if sucFire and resultFire then
				oldFire = resultFire
				hookedFire = fireFn
			else
				vape:CreateNotification('SilentAim', 'Failed to hook WeaponHandler', 5, 'alert')
				return
			end

			if sucHit and resultHit then
				oldHit = resultHit
				hookedHit = hitFn
			end

			local fireDelay = 0
			repeat
				if AutoFire.Enabled and entitylib.isAlive then
					local now = os.clock()
					if now >= fireDelay then
						fireDelay = now + 1 / AutoFireRate.Value
						pcall(function()
							pressMouse(true)
							task.wait(0.02)
							pressMouse(false)
						end)
					end
				end
				task.wait()
			until not SilentAim.Enabled
		else
			if hookedFire then
				pcall(function()
					if restorefunction then
						restorefunction(hookedFire)
					elseif oldFire then
						hookfunction(hookedFire, oldFire)
					end
				end)
				hookedFire = nil
				oldFire = nil
			end

			if hookedHit then
				pcall(function()
					if restorefunction then
						restorefunction(hookedHit)
					elseif oldHit then
						hookfunction(hookedHit, oldHit)
					end
				end)
				hookedHit = nil
				oldHit = nil
			end
			aimUntil = 0
		end
	end,
	Tooltip = 'Aims by replacing the reported shot direction and hit'
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
	Max = 1500,
	Default = 800,
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
	end,
	Tooltip = 'Simulates mouse clicks at a fixed rate'
})
AutoFireRate = SilentAim:CreateSlider({
	Name = 'Fire Rate',
	Min = 1,
	Max = 20,
	Default = 8,
	Visible = false,
	Suffix = '/s'
})
