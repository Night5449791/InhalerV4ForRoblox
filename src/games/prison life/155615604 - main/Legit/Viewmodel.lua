local Viewmodel
local Depth
local Horizontal
local Vertical
local Sway
local ForceField
local ColorSl
local handle
local old
local toolAddedConn, toolRemovedConn
local moveSpring = Spring.new()
local aimSpring = Spring.new({Speed = 15})

local function setTransparency(tool, transparency)
	if tool then
		for _, inst in tool:QueryDescendants('BasePart, Texture, Decal') do
			inst.LocalTransparencyModifier = transparency
		end
	end
end

local function destroyViewmodel()
	if vtool then
		vtool:Destroy()
		vtool = nil
	end

	handle = nil
end

local function ToolAdded(tool)
	if not tool or not tool:IsA('Tool') then
		return
	end

	setTransparency(old, 0)
	destroyViewmodel()

	old = tool
	vtool = tool:Clone()
	handle = vtool:FindFirstChild('Handle')
	vtool.Parent = gameCamera

	if ForceField.Enabled then
		local color = Color3.fromHSV(ColorSl.Hue, ColorSl.Sat, ColorSl.Value)

		for _, part in vtool:QueryDescendants('BasePart') do
			part.Material = Enum.Material.ForceField
			part.Color = color
		end
	end

	setTransparency(old, 1)
end

local function EntityAdded(entity)
	destroyViewmodel()

	if toolAddedConn then
		toolAddedConn:Disconnect()
		toolRemovedConn:Disconnect()
		toolAddedConn, toolRemovedConn = nil, nil
	end

	setTransparency(old, 0)
	old = nil

	local character = entity and entity.Character
	if not character then
		return
	end

	toolAddedConn = character.ChildAdded:Connect(ToolAdded)
	toolRemovedConn = character.ChildRemoved:Connect(function(tool)
		if tool ~= old then
			return
		end

		destroyViewmodel()
		setTransparency(old, 0)
		old = nil
	end)

	ToolAdded(character:FindFirstChildWhichIsA('Tool'))
end

local function renderViewmodel(dt)
	if not handle then
		return
	end

	local camCF = gameCamera.CFrame
	local clock = os.clock()
	local root = entitylib.isAlive and entitylib.character.RootPart
	local target = root and root.AssemblyLinearVelocity * 0.005 or Vector3.zero

	if Sway.Enabled then
		if target.Magnitude > 0.1 then
			target += (camCF * CFrame.new(math.sin(clock * 10) * 0.06, 0, 0)).Position - camCF.Position
		else
			target += (camCF * CFrame.new(0, math.sin(clock) * 0.04, 0)).Position - camCF.Position
		end
	end

	moveSpring.Target = target

	local cf = (camCF * CFrame.new(Horizontal.Value, Vertical.Value, -Depth.Value)) + moveSpring:Update(dt)
	local recoil = math.max(shootTimer - clock, 0)
	aimSpring.Target = aimTimer > clock and CFrame.lookAt(cf.Position, aimVec).LookVector or camCF.LookVector
	handle.CFrame = CFrame.lookAlong(cf.Position, aimSpring:Update(dt)) * (CFrame.Angles(math.rad(recoil * 10), 0, 0) * CFrame.new(0, 0, recoil))
	handle.AssemblyLinearVelocity = Vector3.zero
end

Viewmodel = vape.Legit:CreateModule({
	Name = 'Viewmodel',
	Function = function(callback)
		if callback then
			TracerHook:Add('Viewmodel', function()
				shootTimer = os.clock() + 0.3
			end, 0)

			Viewmodel:Clean(entitylib.Events.LocalAdded:Connect(EntityAdded))
			if entitylib.isAlive then
				task.spawn(EntityAdded, entitylib.character)
			end

			Viewmodel:Clean(runService.RenderStepped:Connect(renderViewmodel))
		else
			TracerHook:Remove('Viewmodel')

			if toolAddedConn then
				toolAddedConn:Disconnect()
				toolRemovedConn:Disconnect()
				toolAddedConn, toolRemovedConn = nil, nil
			end

			setTransparency(old, 0)
			old = nil
			destroyViewmodel()
		end
	end,
	Tooltip = 'Custom viewmodel for guns'
})
Depth = Viewmodel:CreateSlider({
	Name = 'Depth',
	Min = 0,
	Max = 3,
	Default = 3,
	Decimal = 10
})
Horizontal = Viewmodel:CreateSlider({
	Name = 'Horizontal',
	Min = 0,
	Max = 2,
	Default = 2,
	Decimal = 10
})
Vertical = Viewmodel:CreateSlider({
	Name = 'Vertical',
	Min = -1.5,
	Max = 2,
	Default = -1.5,
	Decimal = 10
})
Sway = Viewmodel:CreateToggle({
	Name = 'Sway Effect',
	Default = true
})
ForceField = Viewmodel:CreateToggle({
	Name = 'ForceField Effect',
	Function = function(callback)
		ColorSl.Object.Visible = callback
		if callback and Viewmodel.Enabled then
			Viewmodel:Toggle()
			Viewmodel:Toggle()
		end
	end
})
ColorSl = Viewmodel:CreateColorSlider({
	Name = 'Color',
	Function = function(hue, sat, val)
		if not ForceField.Enabled or not vtool then
			return
		end

		for _, part in vtool:QueryDescendants('BasePart') do
			part.Color = Color3.fromHSV(hue, sat, val)
		end
	end,
	Visible = false
})
