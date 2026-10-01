local ToolGrip
local DefaultGrip = Vector3.new(1, 2, 0)
local SpecialGrips = {
	['Remington 870'] = Vector3.new(1, 2, 1.5),
	['AK-47'] = Vector3.new(1, 2, 1.5)
}
local originalGrips = setmetatable({}, {
	__mode = 'k'
})

local function ApplyGrip(tool)
	if not tool:IsA('Tool') then return end

	local grip = SpecialGrips[tool.Name] or DefaultGrip
	if tool.GripPos == grip then return end

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
