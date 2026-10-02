local DiedTP
local deathCFrame
local connections = {}

local function disconnectConnections()
	for _, conn in ipairs(connections) do
		if conn then
			conn:Disconnect()
		end
	end

	table.clear(connections)
end

local function getRoot(char)
	if not char then return end
	return char:FindFirstChild('HumanoidRootPart') or char:FindFirstChild('RootPart')
end

local function captureDeathCFrame(char)
	if not char then return end

	local root = getRoot(char)
	if root then
		deathCFrame = root.CFrame
	end
end

local function applyDeathCFrame(char)
	if not char or not deathCFrame then return end

	local root = getRoot(char)
	if not root then return end

	root.CFrame = deathCFrame + Vector3.new(0, 2, 0)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	deathCFrame = nil
end

local function watchCharacter(char)
	if not char then return end

	local humanoid = char:FindFirstChildOfClass('Humanoid')
	if not humanoid then return end

	local diedConnection = humanoid.Died:Connect(function()
		captureDeathCFrame(char)
	end)
	connections[#connections + 1] = diedConnection

	if deathCFrame then
		task.defer(applyDeathCFrame, char)
	end
end

DiedTP = vape.Categories.Blatant:CreateModule({
	Name = 'DiedTP',
	Function = function(callback)
		if not callback then
			disconnectConnections()
			deathCFrame = nil
			return
		end

		disconnectConnections()

		local addedConnection = entitylib.Events.LocalAdded:Connect(function(char)
			watchCharacter(char)
		end)
		connections[#connections + 1] = addedConnection

		local removedConnection = entitylib.Events.LocalRemoved:Connect(function(entity)
			if not entity or not entity.Character then return end
			if deathCFrame then return end

			local root = getRoot(entity.Character)
			if root then
				deathCFrame = root.CFrame
			end
		end)
		connections[#connections + 1] = removedConnection

		if entitylib.isAlive and entitylib.character then
			watchCharacter(entitylib.character)
		end
	end,
	Tooltip = 'Teleports you back to your last death position when you respawn.'
})
