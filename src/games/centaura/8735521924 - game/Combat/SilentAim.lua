run(function()
	local SilentAim
	local Mode
	local Range
	local HitChance
	local oldnamecall
	local rand = Random.new()

	local function getTarget(origin)
		if rand.NextNumber(rand, 0, 100) > HitChance.Value then return end

		local entity = entitylib['Entity'..Mode.Value]({
			Part = 'Head',
			Range = Range.Value,
			Origin = origin,
			Players = true,
			NPCs = true
		})

		if entity then
			targetinfo.Targets[entity] = os.clock() + 1
		end

		return entity, entity and entity.Head
	end

	local function namecallHook(...)
		if getnamecallmethod() ~= 'FindPartOnRayWithIgnoreList' or checkcaller() then
			return oldnamecall(...)
		end

		local self, ray, ignoreList = ...
		if typeof(ray) ~= 'Ray' or type(ignoreList) ~= 'table' then
			return oldnamecall(...)
		end

		local entity, part = getTarget(ray.Origin)
		if entity and part then
			local origin = ray.Origin
			ray = Ray.new(origin, CFrame.lookAt(origin, part.Position).LookVector * ray.Direction.Magnitude)
		end

		return oldnamecall(self, ray, ignoreList, select(4, ...))
	end

	SilentAim = vape.Categories.Combat:CreateModule({
		Name = 'SilentAim',
		Function = function(callback)
			if callback then
				local mt = getrawmetatable(game)
				if isreadonly(mt) then
					setreadonly(mt, false)
				end
				local hook = typeof(newcclosure) == 'function' and newcclosure(namecallHook) or namecallHook
				oldnamecall = hookmetamethod(game, '__namecall', hook)
			else
				if oldnamecall then
					pcall(restorefunction, getrawmetatable(game).__namecall)
					oldnamecall = nil
				end
			end
		end,
		Tooltip = 'Silently adjusts your aim towards the enemy'
	})
	vape:Clean(function()
		if oldnamecall then
			pcall(restorefunction, getrawmetatable(game).__namecall)
			oldnamecall = nil
		end
	end)
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
end)
