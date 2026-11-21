local ToolGrip
local Mode
local GripVector
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

local function parseVector(text)
	local split = text:split(',')
	if #split ~= 3 then return end

	local x, y, z = tonumber(split[1]), tonumber(split[2]), tonumber(split[3])
	if not x or not y or not z then return end

	return Vector3.new(x, y, z)
end

local function getGrip(tool)
	if Mode.Value == 'Vector3' then
		return parseVector(GripVector.Value)
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

ToolGrip = vape.Categories.Render:CreateModule({
	Name = 'ToolGrip',
	Function = function(callback)
		if callback then
			GripVector.Object.Visible = Mode.Value == 'Vector3'
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
		GripVector.Object.Visible = Mode.Value == 'Vector3'
		if ToolGrip.Enabled then
			RestoreGrips()
			task.spawn(EntityAdded)
		end
	end
})
GripVector = ToolGrip:CreateTextBox({
	Name = 'Grip Pos',
	Default = '1, 2, 1.5',
	Visible = false,
	Darker = true,
	Function = function()
		if ToolGrip.Enabled and Mode.Value == 'Vector3' then
			RestoreGrips()
			task.spawn(EntityAdded)
		end
	end
})
