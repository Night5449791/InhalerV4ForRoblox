local NetworkOwnershipDebugger
local ControlMode
local Target
local Position
local Speed
local TargetName
local LoopDelay
local looping = false

local function parseVector3(text)
	local split = text:split(',')

	if #split ~= 3 then
		return
	end

	local x, y, z = tonumber(split[1]), tonumber(split[2]), tonumber(split[3])

	if not x or not y or not z then
		return
	end

	return Vector3.new(x, y, z)
end

local function getTargetPosition()
	if Target.Value == 'LocalPlayer' then
		return entitylib.isAlive and (entitylib.character.RootPart.Position + Vector3.new(0, entitylib.character.HipHeight, 0)) or nil
	end

	return parseVector3(Position.Value)
end

local function getTargetPlayer()
	local name = TargetName.Value:gsub('^%s+', ''):gsub('%s+$', ''):lower()

	if name == '' then
		return lplr
	end

	for _, plr in playersService:GetPlayers() do
		if plr.Name:lower():sub(1, #name) == name then
			return plr
		end
	end
end

local function getParts()
	local parts = {}

	for _, v in workspace:GetDescendants() do
		if v:IsA('BasePart') and not v.Anchored then
			table.insert(parts, v)
		end
	end

	return parts
end

local function runControl()
	local position = getTargetPosition()

	if not position then
		return false
	end

	if ControlMode.Value == 'Velocity' then
		for _, part in getParts() do
			part.AssemblyLinearVelocity = (position - part.Position).Unit * Speed.Value
		end

		return true
	end

	local player = getTargetPlayer()
	local character = player and player.Character

	if character then
		local root = character:FindFirstChild('HumanoidRootPart')

		if root then
			root.CFrame = CFrame.lookAt(position, position - root.CFrame.LookVector)
			return true
		end
	end

	local first = true

	for _, part in getParts() do
		if player then
			part.CFrame = CFrame.lookAt(position, position - part.CFrame.LookVector)
		elseif first then
			first = false
			part.CFrame = CFrame.lookAt(position + part.CFrame.LookVector * 4, position)
		else
			part.CFrame = CFrame.lookAt(position + (part.Position - position).Unit * 4, position)
		end
	end

	return true
end

NetworkOwnershipDebugger = vape.Categories.Render:CreateModule({
	Name = 'NetworkOwnershipDebugger',
	Function = function(callback)
		local physicsSettings = settings():GetService('PhysicsSettings')

		physicsSettings.AreOwnersShown = callback and true or false
	end,
	Tooltip = 'Shows the network owner of every part in the world.'
})
ControlMode = NetworkOwnershipDebugger:CreateDropdown({
	Name = 'Control mode',
	List = {'Velocity', 'CFrame'},
	Tooltip = 'Velocity - throws unanchored parts at the target\nCFrame - moves the character or the parts onto the target'
})
Target = NetworkOwnershipDebugger:CreateDropdown({
	Name = 'Target',
	List = {'LocalPlayer', 'Vector3'},
	Function = function(val)
		Position.Object.Visible = val == 'Vector3'
		TargetName.Object.Visible = val == 'LocalPlayer'
	end
})
Position = NetworkOwnershipDebugger:CreateTextBox({
	Name = 'Position',
	Function = function()
		if parseVector3(Position.Value) == nil then
			notif('NetworkOwnershipDebugger', 'Invalid Vector3, use x, y, z', 5, 'warning')
		end
	end,
	Default = '0, 0, 0',
	Placeholder = 'x, y, z',
	Visible = false
})
TargetName = NetworkOwnershipDebugger:CreateTextBox({
	Name = 'Player',
	Function = function()
		if NetworkOwnershipDebugger.Enabled and Target.Value == 'LocalPlayer' and TargetName.Value ~= '' and not getTargetPlayer() then
			notif('NetworkOwnershipDebugger', 'No player named '..TargetName.Value, 5, 'warning')
		end
	end,
	Default = '',
	Placeholder = 'Empty for yourself',
	Tooltip = 'Name of the player whose character is moved when using CFrame'
})
Speed = NetworkOwnershipDebugger:CreateSlider({
	Name = 'Speed',
	Min = 1,
	Max = 1000,
	Default = 100,
	Decimal = 1
})
LoopDelay = NetworkOwnershipDebugger:CreateSlider({
	Name = 'Loop delay',
	Min = 0,
	Max = 1,
	Default = 0,
	Decimal = 100,
	Tooltip = 'Seconds between each control pass'
})
NetworkOwnershipDebugger:CreateButton({
	Name = 'Control Parts',
	Function = function()
		if looping then
			looping = false
			notif('NetworkOwnershipDebugger', 'Stopped controlling parts', 5)
			return
		end

		looping = true
		notif('NetworkOwnershipDebugger', 'Controlling parts, press again to stop', 5)

		task.spawn(function()
			while looping do
				if not runControl() then
					looping = false
					notif('NetworkOwnershipDebugger', 'No target position found.', 5, 'warning')
					break
				end

				task.wait(LoopDelay.Value)
			end
		end)
	end,
	Tooltip = 'Velocity throws every unanchored part at the target, CFrame teleports the character or the parts to it'
})
