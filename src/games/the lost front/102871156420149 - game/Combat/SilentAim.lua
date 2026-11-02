local SilentAim
local Targets
local Mode
local HitChance
local HeadshotChance
local Range
local ShowTarget
local AutoFire

local rand = Random.new()

run(function()
	local shotRemote = thelostfront.Shot
	if not shotRemote then return end

	local entityMouse = entitylib.EntityMouse
	local entityPosition = entitylib.EntityPosition

	-- the game ships its own packet serialiser, so the aim is written into the buffer the weapon
	-- already built instead of a packet of our own: origin, spread and the bullet uuid stay
	-- untouched, only the direction at offset 24 is replaced
	local ignore = {}

	local function getTarget(origin)
		if rand:NextNumber(0, 100) > HitChance.Value then return end

		local targetPart = rand:NextNumber(0, 100) < HeadshotChance.Value and 'Head' or 'Torso'
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

	-- the aim only moves the packet, so the crosshair never leaves the player and the shot lands
	-- even while the camera is pointing somewhere else entirely. RemoteEvent.FireServer is a locked
	-- member, so the hook goes on the shared namecall instead and only the shot remote is touched
	local hooked = false
	local originalNamecall

	local function redirect(self, packet, ...)
		if not SilentAim.Enabled or typeof(packet) ~= 'buffer' then
			return originalNamecall(self, packet, ...)
		end

		local origin = thelostfront.originOf(packet)
		if not origin then return originalNamecall(self, packet, ...) end

		local entity, part = getTarget(origin)
		if not part then return originalNamecall(self, packet, ...) end

		local position = part.Position
		ignore[1] = entity.Character

		-- a clear line only: anything the ray hits keeps the shot where the player pointed it
		if entitylib.Wallcheck(origin, position, ignore) then
			return originalNamecall(self, packet, ...)
		end

		thelostfront.aim(packet, position)

		if ShowTarget.Enabled then
			targetinfo.Targets[entity] = os.clock() + 1
		end

		return originalNamecall(self, packet, ...)
	end

	local function hookShot(self, ...)
		if self ~= shotRemote or getnamecallmethod() ~= 'FireServer' then
			return originalNamecall(self, ...)
		end

		return redirect(self, ...)
	end

	-- the wrapper is kept in shared so a re-inject unwraps its own version instead of stacking a
	-- second one on top of a chain that would then redirect every shot twice
	local function installHook()
		if hooked then return end

		local previous = shared.__tlfsilentaim
		if previous and typeof(previous.Hook) == 'function' and typeof(restorefunction) == 'function' then
			pcall(restorefunction, getrawmetatable(game).__namecall)
		end

		originalNamecall = getrawmetatable(game).__namecall
		setreadonly(getrawmetatable(game), false)
		getrawmetatable(game).__namecall = newcclosure(hookShot)
		setreadonly(getrawmetatable(game), true)

		shared.__tlfsilentaim = {
			Hook = hookShot,
			Original = originalNamecall
		}

		hooked = true
	end

	local function removeHook()
		if not hooked then return end

		local previous = shared.__tlfsilentaim
		if previous and typeof(restorefunction) == 'function' then
			pcall(restorefunction, getrawmetatable(game).__namecall)
		else
			setreadonly(getrawmetatable(game), false)
			getrawmetatable(game).__namecall = originalNamecall
			setreadonly(getrawmetatable(game), true)
		end

		shared.__tlfsilentaim = nil
		hooked = false
	end

	-- the packet cannot be replayed: the server keys each shot on the uuid it carries, so a copy of
	-- an earlier one is dropped. Autofire therefore presses the game's own trigger, and the weapon
	-- builds a fresh packet that the hook above then redirects like any other shot
	local function fireButton()
		local playerGui = lplr:FindFirstChild('PlayerGui')
		local mobile = playerGui and playerGui:FindFirstChild('mobile')
		local weapon = mobile and mobile:FindFirstChild('weapon')

		return weapon and weapon:FindFirstChild('fire')
	end

	-- the touch buttons only exist while the game is in its mobile layout; the desktop path presses
	-- the mouse and needs no button at all. Both helpers come from the base, which is where the
	-- executor hands them out on this client
	local function trigger()
		local button = fireButton()
		if button and button.Visible and mousemoveabs and mouse1press then
			local position = button.AbsolutePosition + button.AbsoluteSize / 2

			mousemoveabs(position.X, position.Y)
			mouse1press()
			task.wait(0.05)
			if mouse1release then
				mouse1release()
			end

			return true
		end

		if mouse1press and mouse1release then
			mouse1press()
			task.wait(0.05)
			mouse1release()

			return true
		end

		return false
	end

	-- the expensive half is the entity sweep, so it runs on its own clock while the trigger itself
	-- is pulled every tick and the weapon decides the fire rate
	local GATE_SECONDS = 0.15

	local function reachable()
		local localEntity = entitylib.character
		if not (entitylib.isAlive and localEntity) then return false end

		local root = localEntity.RootPart
		if not root then return false end

		local entity = entityPosition({
			Part = 'Torso',
			Range = Range.Value,
			Origin = root.Position,
			Players = Targets.Players.Enabled,
			NPCs = Targets.NPCs.Enabled
		})

		if not entity or not entity.Torso then return false end

		ignore[1] = localEntity.Character
		ignore[2] = entity.Character

		return entitylib.Wallcheck(root.Position, entity.Torso.Position, ignore) == nil
	end

	local function autoFireLoop()
		local gateUntil, gateOk = 0, false

		repeat
			task.wait()

			if AutoFire.Enabled and SilentAim.Enabled and hooked then
				local now = os.clock()
				if now >= gateUntil then
					gateOk = reachable()
					gateUntil = now + GATE_SECONDS
				end

				if gateOk then
					trigger()
				end
			end
		until not AutoFire.Enabled
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
		Tooltip = 'Moves the shot direction onto the target inside the packet, the crosshair itself never moves'
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
		Tooltip = 'Fires while a target is in range',
		Function = function(callback)
			if not callback then return end

			task.spawn(autoFireLoop)
		end
	})
end)
