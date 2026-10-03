run(function()
	local SilentAim
	local Target
	local Mode
	local Range
	local HitChance
	local HeadshotChance
	local AutoFire = {Enabled = false}
	local AutoFireRate
	local AutoFireTaser
	local AutoFireSwitch
	local Wallbang
	local CircleColor
	local CircleTransparency
	local CircleFilled
	local CircleObject
	local rand = Random.new()
	local old
	local hooked

	local function getMousePosition()
		if inputService.TouchEnabled then
			return gameCamera.ViewportSize / 2
		end

		return inputService.GetMouseLocation(inputService)
	end

	local backpack
	-- cached, both scanners below can run every AutoFire tick
	local function getBackpack()
		if not backpack or backpack.Parent ~= lplr then
			backpack = lplr:FindFirstChildWhichIsA('Backpack')
		end

		return backpack
	end

	-- 0 while the tool is reloading or carries no range attribute
	local function getToolRange(tool)
		if (tool:GetAttribute('Local_ReloadSession') or 0) > 0 then
			return 0
		end

		return tool:GetAttribute('Range') or 0
	end

	local function getShootTool(range)
		local tool = lplr.Character and lplr.Character:FindFirstChildWhichIsA('Tool')
		if tool and tool:GetAttribute('FireRate') and (not tool:GetAttribute('Local_IsShooting')) and (tool:GetAttribute('Local_CurrentAmmo') or 1) > 0 and getToolRange(tool) > range then
			return tool
		end

		local container = getBackpack()
		if container then
			for _, tool in container:GetChildren() do
				if tool:IsA('Tool') and tool:GetAttribute('FireRate') and (not tool:GetAttribute('Local_IsShooting')) and tool.Name ~= 'Taser' and getToolRange(tool) > range then
					return tool
				end
			end
		end
	end

	local function getMaxRange()
		local mag = 0
		local tool = lplr.Character and lplr.Character:FindFirstChildWhichIsA('Tool')
		if tool then
			mag = getToolRange(tool)
		end

		local container = getBackpack()
		if container then
			for _, tool in container:GetChildren() do
				if tool:IsA('Tool') and tool.Name ~= 'Taser' then
					local dist = getToolRange(tool)
					if dist > mag then
						mag = dist
					end
				end
			end
		end

		return mag
	end

	local entityMode
	local entityFunc
	-- caches the lookup so the 'Entity'..Mode.Value concat isnt rebuilt per shot
	local function getEntity(settings)
		if entityMode ~= Mode.Value then
			entityMode = Mode.Value
			entityFunc = entitylib['Entity'..entityMode]
		end

		return entityFunc(settings)
	end

	local function getTarget(origin, limit, attackcheck)
		if rand.NextNumber(rand, 0, 100) > (AutoFire.Enabled and 100 or HitChance.Value) then
			return
		end

		local targetPart = (rand.NextNumber(rand, 0, 100) < (AutoFire.Enabled and 100 or HeadshotChance.Value)) and 'Head' or 'RootPart'
		local entity = getEntity({
			Range = Mode.Value == 'Position' and math.min(Range.Value, limit) or Range.Value,
			RangePosition = limit,
			AttackCheck = attackcheck,
			Wallcheck = Target.Walls.Enabled and true or nil,
			Wallbang = Wallbang.Enabled and entitylib.character.RootPart.Position or nil,
			Part = targetPart,
			Origin = origin,
			Players = Target.Players.Enabled,
			NPCs = Target.NPCs.Enabled
		})

		if entity then
			targetinfo.Targets[entity] = tick() + 1
		end

		return entity, entity and entity[targetPart]
	end

	local function Hook(origin, direction, ...)
		local gundata = debug.getupvalue(oldshoot or pl.Shoot, 10)
		local entity, targetPart = getTarget(origin, gundata and gundata.Range or 1000, not gundata or gundata.Behavior ~= 'Taser')

		if not entity then
			return old(origin, direction, ...)
		end

		local aimPosition = targetPart.Position
		aimTimer = os.clock() + 0.3
		aimVec = aimPosition

		if Wallbang.Enabled then
			local ray
			if not OriginScanner.Cache[targetPart] then
				ray = workspace:Raycast(aimPosition, (origin - aimPosition), OriginScanner.Ray)
			end

			if OriginScanner.Cache[targetPart] or ray or workspace:Raycast(origin, (aimPosition - origin), OriginScanner.Ray) then
				local newOrigin, hit = OriginScanner:Scan(
					entitylib.character.RootPart.Position,
					aimPosition,
					ray and ray.Position + ray.Normal * 0.01 or nil,
					targetPart,
					entity
				)

				if newOrigin then
					for index, value in debug.getstack(3) do
						if value == origin then
							debug.setstack(3, index, newOrigin)
						end
					end

					origin = newOrigin
					if hit then
						return targetPart, hit
					end
				end
			end
		end

		return old(origin, aimPosition, ...)
	end

	SilentAim = vape.Categories.Combat:CreateModule({
		Name = 'SilentAim',
		Function = function(callback)
			if CircleObject then
				CircleObject.Visible = callback and Mode.Value == 'Mouse'
			end

			if callback then
				hooked = pl.Bullet
				old = hookfunction(hooked, function(...)
					return Hook(...)
				end)

				local fireDelay = os.clock()
				repeat
					if CircleObject and CircleObject.Visible then
						CircleObject.Position = getMousePosition()
					end

					if AutoFire.Enabled and entitylib.isAlive and fireDelay < os.clock() then
						fireDelay = os.clock() + (1 / AutoFireRate.Value)

						local tool = lplr.Character:FindFirstChildWhichIsA('Tool')
						local gundata = debug.getupvalue(oldshoot or pl.Shoot, 10)
						if tool and gundata then
							local limit = AutoFireSwitch.Enabled and getMaxRange() or gundata.Range or 1000
							local taser = gundata.Behavior == 'Taser'
							local headPosition = entitylib.character.Head.Position
							local entity = getEntity({
								Range = Mode.Value == 'Position' and math.min(Range.Value, limit) or Range.Value,
								RangePosition = limit,
								AttackCheck = not taser,
								Wallcheck = Target.Walls.Enabled and true or nil,
								Wallbang = Wallbang.Enabled and entitylib.character.RootPart.Position or nil,
								Part = 'Head',
								Origin = headPosition,
								Players = Target.Players.Enabled
							})

							if entity and entitylib.character.Humanoid.Health > 0 then
								local ammo = (tool:GetAttribute('Local_CurrentAmmo') or 0)
								local canFire = not tool:GetAttribute('Local_IsShooting') and ammo > 0
								if AutoFireSwitch.Enabled then
									local ideal = getShootTool((entity.Head.Position - headPosition).Magnitude)
									if ideal and tool ~= ideal then
										entitylib.character.Humanoid:EquipTool(ideal)
										canFire = false
									end
								end

								if canFire and not ((taser or AutoFireTaser.Enabled) and (entity.Character:GetAttribute('Tased') or entity.Character:GetAttribute('Arrested'))) then
									fireDelay = os.clock() + (AutoFireSwitch.Enabled and 0.05 or ammo > 1 and gundata.FireRate or 1 / AutoFireRate.Value)
									local obj = {UserInputState = Enum.UserInputState.Begin, UserInputType = Enum.UserInputType.MouseButton1, Position = Vector3.zero}
									task.spawn(pl.Shoot, obj)
									obj.UserInputState = Enum.UserInputState.End
								end
							end
						end
					end

					task.wait()
				until not SilentAim.Enabled
			else
				if old and hooked then
					-- pl gets cleared on uninject before this thread runs, so the function
					-- has to be restored through the reference captured while hooking
					if restorefunction then
						restorefunction(hooked)
					else
						hookfunction(hooked, old)
					end

					old, hooked = nil, nil
				end
			end
		end,
		ExtraText = function()
			return 'PrisonLife'
		end,
		Tooltip = 'Silently adjusts your aim towards the enemy'
	})
	Target = SilentAim:CreateTargets({
		Players = true,
		Walls = true
	})
	Mode = SilentAim:CreateDropdown({
		Name = 'Mode',
		List = {'Mouse', 'Position'},
		Function = function(val)
			if CircleObject then
				CircleObject.Visible = SilentAim.Enabled and val == 'Mouse'
			end
		end,
		Tooltip = 'Mouse - Checks for entities near the mouses position\nPosition - Checks for entities near the local character'
	})
	Range = SilentAim:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 1500,
		Default = 150,
		Function = function(val)
			if CircleObject then
				CircleObject.Radius = val
			end
		end,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	HitChance = SilentAim:CreateSlider({
		Name = 'Hit Chance',
		Min = 0,
		Max = 100,
		Default = 85,
		Suffix = '%'
	})
	HeadshotChance = SilentAim:CreateSlider({
		Name = 'Headshot Chance',
		Min = 0,
		Max = 100,
		Default = 65,
		Suffix = '%'
	})
	AutoFire = SilentAim:CreateToggle({
		Name = 'AutoFire',
		Function = function(callback)
			AutoFireRate.Object.Visible = callback
			AutoFireTaser.Object.Visible = callback
			AutoFireSwitch.Object.Visible = callback
		end,
		Tooltip = 'Automatically fires guns when the specified target conditions are met.'
	})
	AutoFireRate = SilentAim:CreateSlider({
		Name = 'Update rate',
		Min = 1,
		Max = 120,
		Default = 60,
		Visible = false,
		Darker = true,
		Suffix = 'hz'
	})
	AutoFireTaser = SilentAim:CreateToggle({
		Name = 'Ignore Tased',
		Visible = false,
		Darker = true
	})
	AutoFireSwitch = SilentAim:CreateToggle({
		Name = 'Auto Switch',
		Visible = false,
		Darker = true,
		Tooltip = 'Spam switch guns while shooting to get fast damage, only good with multiple tools.'
	})
	Wallbang = SilentAim:CreateToggle({
		Name = 'Wallbang',
		Tooltip = 'Allow you to shoot people through walls when specific conditions are met.\n(If the entity has a valid hitbox position exposed or if the shoot position can be moved past walls (eg hugging walls))'
	})
	SilentAim:CreateToggle({
		Name = 'Range Circle',
		Function = function(callback)
			if callback then
				CircleObject = Drawing.new('Circle')
				CircleObject.Filled = CircleFilled.Enabled
				CircleObject.Color = Color3.fromHSV(CircleColor.Hue, CircleColor.Sat, CircleColor.Value)
				CircleObject.Position = vape.gui.AbsoluteSize / 2
				CircleObject.Radius = Range.Value
				CircleObject.NumSides = 100
				CircleObject.Transparency = 1 - CircleTransparency.Value
				CircleObject.Visible = SilentAim.Enabled and Mode.Value == 'Mouse'
			else
				pcall(function()
					CircleObject.Visible = false
					CircleObject:Remove()
				end)
			end
			CircleColor.Object.Visible = callback
			CircleTransparency.Object.Visible = callback
			CircleFilled.Object.Visible = callback
		end
	})
	CircleColor = SilentAim:CreateColorSlider({
		Name = 'Circle Color',
		Function = function(hue, sat, val)
			if CircleObject then
				CircleObject.Color = Color3.fromHSV(hue, sat, val)
			end
		end,
		Darker = true,
		Visible = false
	})
	CircleTransparency = SilentAim:CreateSlider({
		Name = 'Transparency',
		Min = 0,
		Max = 1,
		Decimal = 10,
		Default = 0.5,
		Function = function(val)
			if CircleObject then
				CircleObject.Transparency = 1 - val
			end
		end,
		Darker = true,
		Visible = false
	})
	CircleFilled = SilentAim:CreateToggle({
		Name = 'Circle Filled',
		Function = function(callback)
			if CircleObject then
				CircleObject.Filled = callback
			end
		end,
		Darker = true,
		Visible = false
	})
end)