local ToolGrip
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

local function ApplyGrip(tool)
	if not tool:IsA('Tool') then return end

	local grip = ToolGrips[tool.Name]
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
	if not backpack then
		return
	end

	ToolGrip:Clean(backpack.ChildAdded:Connect(ApplyGrip))
	for _, tool in backpack:GetChildren() do
		ApplyGrip(tool)
	end
end

ToolGrip = vape.Categories.Blatant:CreateModule({
	Name = 'ToolGrip',
	Function = function(callback)
		if callback then
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
