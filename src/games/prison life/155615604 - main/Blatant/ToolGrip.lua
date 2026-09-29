local ToolGrip
local DefaultGrip = Vector3.new(1, 2, 0)
local SpecialGrips = {
	['Remington 870'] = Vector3.new(1, 2, 1.5),
	['AK-47'] = Vector3.new(1, 2, 1.5)
}

local function ApplyGrip(tool)
	if tool:IsA('Tool') then
		local grip = SpecialGrips[tool.Name] or DefaultGrip
		if tool.GripPos ~= grip then
			tool.GripPos = grip
		end
	end
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
		end
	end,
	Tooltip = 'applies tool grip pos'
})