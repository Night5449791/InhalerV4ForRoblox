local AimAssist
local AimAssistMethod
local FOV
local Speed
local CircleColor
local CircleTransparency
local CircleFilled
local CircleObject
local headChain = {'Root_M', 'Spine1_M', 'Spine2_M', 'Chest_M', 'Neck_M', 'Head_M'}
local rayCheck = RaycastParams.new()
rayCheck.RespectCanCollide = true

AimAssist = vape.Categories.Combat:CreateModule({
	Name = 'AimAssist',
	Function = function(callback)
		if CircleObject then
			CircleObject.Visible = callback
		end

		if not callback then return end

		local cameraMode = AimAssistMethod.Value == 'Camera'
		local touch = inputService.TouchEnabled

		local function step(dt)
			if CircleObject then
				CircleObject.Position = touch and gameCamera.ViewportSize / 2 or inputService:GetMouseLocation()
			end

			if not cameraMode and not inputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return end

			local main = frontlines and frontlines.Main
			local globals = main and main.globals
			if not globals then return end

			local instances = globals.fpv_sol_instances
			local bone = instances and instances.camera_bone
			local origin = bone and bone.WorldPosition or gameCamera.CFrame.Position

			local ent = entitylib.EntityMouse({
				Range = FOV.Value,
				Players = true,
				Wallcheck = true,
				Part = 'RootPart',
				Origin = origin
			})

			if not ent then return end

			local equipment = globals.fpv_sol_equipment
			local gun = equipment and equipment.curr_equipment
			if not gun or not gun.fire_params then return end

			local node = ent.RootPart
			for _, name in headChain do
				node = node and node[name]
			end

			local targetpos = node and node.WorldCFrame.Position
			if not targetpos then return end

			rayCheck.FilterDescendantsInstances = {gameCamera, ent.Character}
			rayCheck.CollisionGroup = ent.RootPart.CollisionGroup
			local calc = prediction.SolveTrajectory(origin, gun.fire_params.muzzle_velocity, workspace.Gravity, targetpos, Vector3.zero, workspace.Gravity, ent.HipHeight, nil, rayCheck)
			if not calc then return end

			targetinfo.Targets[ent] = os.clock() + 1

			if cameraMode then
				local camCF = gameCamera.CFrame
				local blended = camCF.LookVector:Lerp((calc - camCF.Position).Unit, math.min(Speed.Value * dt, 1))
				local magnitude = blended.Magnitude
				if magnitude < 0.01 then return end

				gameCamera.CFrame = CFrame.lookAt(camCF.Position, camCF.Position + blended / magnitude)
			else
				if not main.exe_set or not main.exe_set_t then return end

				local pos = gameCamera:WorldToViewportPoint(calc)
				local cursor = touch and gameCamera.ViewportSize / 2 or inputService:GetMouseLocation()
				local localmouse = (cursor - Vector2.new(pos.X, pos.Y)) * dt * (Speed.Value / 10000)

				main.exe_set(main.exe_set_t.CTRL_SOL_ATT_ROT, localmouse.Y, localmouse.X)
			end
		end

		if cameraMode then
			runService:BindToRenderStep('InhalerAimAssist', Enum.RenderPriority.Camera.Value + 1, step)
			AimAssist:Clean(function()
				runService:UnbindFromRenderStep('InhalerAimAssist')
			end)
		else
			repeat
				local dt = task.wait()
				if not AimAssist.Enabled then break end
				step(dt)
			until not AimAssist.Enabled
		end
	end,
	Tooltip = 'Uses game functions to move the camera towards players'
})
FOV = AimAssist:CreateSlider({
	Name = 'FOV',
	Min = 1,
	Max = 1000,
	Default = 300,
	Function = function(val)
		if CircleObject then
			CircleObject.Radius = val
		end
	end
})
AimAssistMethod = AimAssist:CreateDropdown({
	Name = 'Method',
	List = {'Mouse', 'Camera'},
	Function = function()
		if AimAssist.Enabled then
			AimAssist:Toggle()
			AimAssist:Toggle()
		end
	end,
	Tooltip = 'Mouse rotates through the game aim function.\nCamera only writes the camera CFrame, which works on mobile and sends no game aim state'
})
Speed = AimAssist:CreateSlider({
	Name = 'Speed',
	Min = 1,
	Max = 100,
	Default = 10
})
AimAssist:CreateToggle({
	Name = 'Range Circle',
	Function = function(callback)
		if callback then
			CircleObject = Drawing.new('Circle')
			CircleObject.Filled = CircleFilled.Enabled
			CircleObject.Color = Color3.fromHSV(CircleColor.Hue, CircleColor.Sat, CircleColor.Value)
			CircleObject.Position = vape.gui.AbsoluteSize / 2
			CircleObject.Radius = FOV.Value
			CircleObject.NumSides = 100
			CircleObject.Transparency = 1 - CircleTransparency.Value
			CircleObject.Visible = AimAssist.Enabled
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
CircleColor = AimAssist:CreateColorSlider({
	Name = 'Circle Color', 
	Function = function(hue, sat, val)
		if CircleObject then
			CircleObject.Color = Color3.fromHSV(hue, sat, val)
		end
	end, 
	Darker = true, 
	Visible = false
})
CircleTransparency = AimAssist:CreateSlider({
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
CircleFilled = AimAssist:CreateToggle({
	Name = 'Circle Filled', 
	Function = function(callback)
		if CircleObject then
			CircleObject.Filled = callback
		end
	end, 
	Darker = true, 
	Visible = false
})
