local ToolGrip
local Mode
local GripX
local GripY
local GripZ
local DefaultGrip = Vector3.new(1, 2, 0)
local LongerGrip = Vector3.new(1, 2, 1.5)
local ToolGrips = {
	['Remington 870'] = LongerGrip,
	['AK-47'] = LongerGrip,
	M4A1 = LongerGrip,
	FAL = LongerGrip,
	['MP5'] = DefaultGrip,
	['M9'] = DefaultGrip,
	Taser = DefaultGrip
}
local originalGrips = setmetatable({}, {
	__mode = 'k'
})

local function getGrip(tool)
	if Mode.Value == 'Vector3' then
		return Vector3.new(GripX.Value, GripY.Value, GripZ.Value)
	end
	return ToolGrips[tool.Name]
end

local function ApplyGrip(tool)
	if not tool:IsA('Tool') then return end

	local grip = getGrip(tool)
	if not grip or tool.GripPos == grip then return end

	if originalGrips[tool] == nil then
		originalGrips[tool] = tool.GripPos
	end

	tool.GripPos = grip
end

local function RestoreGrips()
	for tool, grip in originalGrips do
		tool.GripPos = grip
	end

	table.clear(originalGrips)
end

local function EntityAdded()
	local backpack = lplr:FindFirstChildWhichIsA('Backpack')
	if not backpack then return end

	ToolGrip:Clean(backpack.ChildAdded:Connect(ApplyGrip))
	for _, tool in backpack:GetChildren() do
		ApplyGrip(tool)
	end
end

local function refreshGrips()
	if ToolGrip.Enabled and Mode.Value == 'Vector3' then
		RestoreGrips()
		task.spawn(EntityAdded)
	end
end

local function syncVectorVisible()
	local visible = Mode.Value == 'Vector3'
	GripX.Object.Visible = visible
	GripY.Object.Visible = visible
	GripZ.Object.Visible = visible
end

ToolGrip = vape.Categories.Render:CreateModule({
	Name = 'ToolGrip',
	Function = function(callback)
		if callback then
			syncVectorVisible()
			ToolGrip:Clean(entitylib.Events.LocalAdded:Connect(EntityAdded))
			if entitylib.isAlive then
				task.spawn(EntityAdded)
			end
		else
			RestoreGrips()
		end
	end,
	Tooltip = 'applies tool grip pos'
})
Mode = ToolGrip:CreateDropdown({
	Name = 'Mode',
	List = {'Preset', 'Vector3'},
	Function = function()
		syncVectorVisible()
		if ToolGrip.Enabled then
			RestoreGrips()
			task.spawn(EntityAdded)
		end
	end
})
GripX = ToolGrip:CreateSlider({
	Name = 'Grip X',
	Min = -10,
	Max = 10,
	Default = 1,
	Decimal = 10,
	Visible = false,
	Darker = true,
	Function = function()
		refreshGrips()
	end
})
GripY = ToolGrip:CreateSlider({
	Name = 'Grip Y',
	Min = -10,
	Max = 10,
	Default = 2,
	Decimal = 10,
	Visible = false,
	Darker = true,
	Function = function()
		refreshGrips()
	end
})
GripZ = ToolGrip:CreateSlider({
	Name = 'Grip Z',
	Min = -10,
	Max = 10,
	Default = 1.5,
	Decimal = 10,
	Visible = false,
	Darker = true,
	Function = function()
		refreshGrips()
	end
})
