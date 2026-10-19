local AimAssist
local Targets
local Part
local AimAssistMethod
local FOV
local Speed
local CircleColor
local CircleTransparency
local CircleFilled
local CircleObject
local RightClick
local KeyToggle
local Key
local ShowTarget
local moveConst = Vector2.new(1, 0.77) * math.rad(0.5)

local function wrapAngle(num)
	num = num % math.pi
	num -= num >= (math.pi / 2) and math.pi or 0
	num += num < -(math.pi / 2) and math.pi or 0
	return num
end

AimAssist = vape.Categories.Combat:CreateModule({
	Name = 'AimAssist',
	Function = function(callback)
		if CircleObject then
			CircleObject.Visible = callback
		end

		if not callback then return end

		local entity
		local rightClicked = inputService:IsMouseButtonPressed(1)
		local pressed = false
		local cameraMode = AimAssistMethod.Value == 'Camera'
		local touch = inputService.TouchEnabled
		local clickgui = vape.gui.ScaledGui.ClickGui
		local mouseScale
		if not cameraMode then
			-- hoisted so the per-frame path never touches UserSettings or allocates a new scale vector
			mouseScale = moveConst * UserSettings():GetService('UserGameSettings').MouseSensitivity
		end

		local function step(dt)
			if CircleObject then
				CircleObject.Position = touch and gameCamera.ViewportSize / 2 or inputService:GetMouseLocation()
			end

			if clickgui.Visible then return end
			if not cameraMode and inputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then return end
			if not cameraMode and RightClick.Enabled and not rightClicked then return end
			if KeyToggle.Enabled and not pressed then return end

			local camCF = gameCamera.CFrame
			local origin, partName = camCF.Position, Part.Value

			entity = entitylib.EntityMouse({
				Range = FOV.Value,
				Part = partName,
				Players = Targets.Players.Enabled,
				NPCs = Targets.NPCs.Enabled,
				Wallcheck = Targets.Walls.Enabled,
				Origin = origin
			})

			if not entity then return end

			local part = entity[partName]
			if not part then return end

			local target = (part.Position - origin).Unit
			target = target == target and target or Vector3.zero

			if ShowTarget.Enabled then
				targetinfo.Targets[entity] = os.clock() + 1
			end

			if target == Vector3.zero then return end

			local alpha = math.min(Speed.Value * dt, 1)

			if cameraMode then
				-- mobile method - only the local camera CFrame is written, no mouse input at all
				local blended = camCF.LookVector:Lerp(target, alpha)
				local magnitude = blended.Magnitude
				if magnitude < 0.01 then return end

				gameCamera.CFrame = CFrame.lookAt(origin, origin + blended / magnitude)
			else
				local facing = camCF.LookVector
				local diffYaw = wrapAngle(math.atan2(facing.X, facing.Z) - math.atan2(target.X, target.Z))
				local diffPitch = math.asin(facing.Y) - math.asin(target.Y)
				local angle = Vector2.new(diffYaw, diffPitch) // mouseScale

				angle *= alpha

				if typeof(mousemoverel) == 'function' then
					mousemoverel(angle.X, angle.Y)
				end
			end
		end

		if cameraMode then
			-- the default camera scripts write at RenderPriority.Camera, so step right after them
			runService:BindToRenderStep('InhalerAimAssist', Enum.RenderPriority.Camera.Value + 1, step)
			AimAssist:Clean(function()
				runService:UnbindFromRenderStep('InhalerAimAssist')
			end)
		else
			AimAssist:Clean(runService.RenderStepped:Connect(step))
		end

		AimAssist:Clean(Key.Triggered:Connect(function(isDown)
			pressed = KeyToggle.Enabled and isDown
		end))

		AimAssist:Clean(inputService.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton2 then
				rightClicked = true
			end
		end))

		AimAssist:Clean(inputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton2 then
				rightClicked = false
			end
		end))
	end,
	Tooltip = 'Smoothly aims to closest valid target'
})
Targets = AimAssist:CreateTargets({Players = true})
AimAssistMethod = AimAssist:CreateDropdown({
	Name = 'Method',
	List = {'Mouse', 'Camera'},
	Function = function()
		if RightClick then
			RightClick.Object.Visible = AimAssistMethod.Value ~= 'Camera'
		end

		if AimAssist.Enabled then
			AimAssist:Toggle()
			AimAssist:Toggle()
		end
	end,
	Tooltip = 'Mouse moves the cursor with mousemoverel.\nCamera only writes the camera CFrame, which works on mobile and sends no mouse input'
})
Part = AimAssist:CreateDropdown({
	Name = 'Part',
	List = {'RootPart', 'Head'}
})
FOV = AimAssist:CreateSlider({
	Name = 'FOV',
	Min = 0,
	Max = 1000,
	Default = 100,
	Function = function(val)
		if CircleObject then
			CircleObject.Radius = val
		end
	end
})
Speed = AimAssist:CreateSlider({
	Name = 'Speed',
	Min = 0,
	Max = 30,
	Default = 15
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
RightClick = AimAssist:CreateToggle({
	Name = 'Require right click',
	Tooltip = 'Only activate when holding down right click',
	Visible = AimAssistMethod.Value ~= 'Camera'
})
KeyToggle = AimAssist:CreateToggle({
	Name = 'Require key',
	Function = function(callback)
		Key.Object.Visible = callback
	end,
	Tooltip = 'Only activate when holding down a certain key'
})
Key = AimAssist:CreateBind({
	Name = 'Hold Key',
	Default = {'G'},
	Hold = true,
	Darker = true,
	Visible = false
})
ShowTarget = AimAssist:CreateToggle({
	Name = 'Show target info'
})
