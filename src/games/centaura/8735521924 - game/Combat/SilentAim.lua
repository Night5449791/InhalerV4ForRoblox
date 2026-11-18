local SilentAim
local Targets
local Mode
local Range
local HitChance
local HeadshotChance
local Wallbang
local ShowTarget
local AutoFire
local ShootDelay
local oldnamecall
local rand = Random.new()
local clickDelay = os.clock()
local mouseClicked

local function getTarget(origin, ignoreList)
	if rand:NextNumber(0, 100) > HitChance.Value then return end

	local partName = rand:NextNumber(0, 100) < HeadshotChance.Value and 'Head' or 'RootPart'
	local fromMouse = Mode.Value == 'Mouse'
	local wallcheck
	if not Wallbang.Enabled then
		wallcheck = ignoreList
	end

	local entity = entitylib['Entity'..Mode.Value]({
		Part = partName,
		Range = Range.Value,
		MouseOrigin = fromMouse and gameCamera.ViewportSize / 2 or nil,
		Origin = origin,
		Players = Targets.Players.Enabled,
		NPCs = Targets.NPCs.Enabled,
		Wallcheck = wallcheck
	})

	if not entity then return end
	return entity, entity[partName]
end

local function isGunRay(ignoreList)
	if type(ignoreList) ~= 'table' or not entitylib.isAlive then return false end

	local hasIgnoreList, hasCharacter = false, false
	for _, v in ignoreList do
		if v == workspace.IgnoreList then
			hasIgnoreList = true
		end
		if v == entitylib.character.Character then
			hasCharacter = true
		end
	end

	return hasIgnoreList and hasCharacter
end

local function namecallHook(self, ...)
	if getnamecallmethod() ~= 'FindPartOnRayWithIgnoreList' or not SilentAim.Enabled then
		return oldnamecall(self, ...)
	end

	local ray, ignoreList = ...
	if typeof(ray) ~= 'Ray' or not isGunRay(ignoreList) then
		return oldnamecall(self, ...)
	end

	local entity, part = getTarget(ray.Origin, ignoreList)
	if entity and part then
		if ShowTarget.Enabled then
			targetinfo.Targets[entity] = os.clock() + 1
		end

		if Wallbang.Enabled then
			return part, part.Position, part.GetClosestPointOnSurface(part, ray.Origin), part.Material
		end

		ray = Ray.new(ray.Origin, CFrame.lookAt(ray.Origin, part.Position).LookVector * ray.Direction.Magnitude)
	end

	return oldnamecall(self, ray, ignoreList, select(3, ...))
end

SilentAim = vape.Categories.Combat:CreateModule({
	Name = 'SilentAim',
	Function = function(callback)
		if callback then
			local mt = getrawmetatable(game)
			if isreadonly(mt) then
				setreadonly(mt, false)
			end
			oldnamecall = hookmetamethod(game, '__namecall', namecallHook)
		else
			if oldnamecall then
				local mt = getrawmetatable(game)
				if isreadonly(mt) then
					setreadonly(mt, false)
				end
				pcall(restorefunction, getrawmetatable(game).__namecall)
				oldnamecall = nil
			end

			if mouse1click and (isrbxactive or iswindowactive)() then
				if mouseClicked then
					mouse1release()
				end
			end
			mouseClicked = false
		end

		repeat
			if AutoFire.Enabled and mouse1click and (isrbxactive or iswindowactive)() then
				local origin = entitylib.isAlive and entitylib.character.RootPart.Position or gameCamera.CFrame.Position
				local entity = getTarget(origin, nil)
				if entity and clickDelay < os.clock() then
					if mouseClicked then
						mouse1release()
						clickDelay = os.clock() + ShootDelay.Value
					else
						mouse1press()
					end

					mouseClicked = not mouseClicked
				elseif not entity and mouseClicked then
					mouse1release()
					mouseClicked = false
				end
			end

			task.wait()
		until not SilentAim.Enabled
	end,
	Tooltip = 'Redirects your bullets onto the target without moving your camera'
})
Targets = SilentAim:CreateTargets({
	Players = true,
	NPCs = true
})
Mode = SilentAim:CreateDropdown({
	Name = 'Mode',
	List = {'Mouse', 'Position'},
	Tooltip = 'Mouse - targets near your crosshair\nPosition - targets closest to your gun'
})
Range = SilentAim:CreateSlider({
	Name = 'Range',
	Min = 1,
	Max = 1000,
	Default = 150,
	Suffix = function(val)
		if Mode.Value == 'Mouse' then
			return val == 1 and 'pixel' or 'pixels'
		end

		return val == 1 and 'stud' or 'studs'
	end
})
HitChance = SilentAim:CreateSlider({
	Name = 'Hit Chance',
	Min = 0,
	Max = 100,
	Default = 100,
	Suffix = '%'
})
HeadshotChance = SilentAim:CreateSlider({
	Name = 'Headshot Chance',
	Min = 0,
	Max = 100,
	Default = 65,
	Suffix = '%'
})
Wallbang = SilentAim:CreateToggle({
	Name = 'Wallbang'
})
ShowTarget = SilentAim:CreateToggle({
	Name = 'Show target info'
})
AutoFire = SilentAim:CreateToggle({
	Name = 'AutoFire',
	Function = function(callback)
		ShootDelay.Object.Visible = callback
	end
})
ShootDelay = SilentAim:CreateSlider({
	Name = 'Next Shot Delay',
	Min = 0,
	Max = 1,
	Decimal = 100,
	Default = 0.1,
	Visible = false,
	Darker = true,
	Suffix = function(val)
		return val == 1 and 'second' or 'seconds'
	end
})
