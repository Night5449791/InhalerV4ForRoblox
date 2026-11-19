local ForcePos
local Method
local X
local Y
local Z

local velocityFactor = 50

local function readAxis(option)
	return tonumber(option.Value)
end

ForcePos = vape.Categories.World:CreateModule({
	Name = 'ForcePos',
	Function = function(callback)
		if callback then
			ForcePos:Clean(runService.PreSimulation:Connect(function()
				if not entitylib.isAlive then return end

				local root = entitylib.character.RootPart
				local position = root.Position
				local x = readAxis(X)
				local y = readAxis(Y)
				local z = readAxis(Z)

				if not (x or y or z) then return end

				local target = Vector3.new(x or position.X, y or position.Y, z or position.Z)

				if Method.Value == 'CFrame' then
					local velocity = root.AssemblyLinearVelocity
					root.CFrame = CFrame.new(target) * root.CFrame.Rotation
					root.AssemblyLinearVelocity = Vector3.new(x and 0 or velocity.X, y and 0 or velocity.Y, z and 0 or velocity.Z)
				else
					local velocity = root.AssemblyLinearVelocity
					local delta = target - position
					root.AssemblyLinearVelocity = Vector3.new(x and delta.X * velocityFactor or velocity.X, y and delta.Y * velocityFactor or velocity.Y, z and delta.Z * velocityFactor or velocity.Z)
				end
			end))
		end
	end,
	Tooltip = 'Forces the local player to the given coordinates. An empty axis keeps the current position.'
})
Method = ForcePos:CreateDropdown({
	Name = 'Method',
	List = {'CFrame', 'Velocity'}
})
X = ForcePos:CreateTextBox({
	Name = 'X',
	Placeholder = 'optional'
})
Y = ForcePos:CreateTextBox({
	Name = 'Y',
	Placeholder = 'optional'
})
Z = ForcePos:CreateTextBox({
	Name = 'Z',
	Placeholder = 'optional'
})
