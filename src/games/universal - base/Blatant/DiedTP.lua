local DiedTP
local lastDeath
local connections = {}
local characterConnection
local enabled = false
local generation = 0

local function disconnectConnections()
	for _, conn in ipairs(connections) do
		if conn then
			conn:Disconnect()
		end
	end

	table.clear(connections)
	if characterConnection then
		characterConnection:Disconnect()
		characterConnection = nil
	end
end

local function getRoot(char)
	if not char then return end
	return char:FindFirstChild('HumanoidRootPart') or char:FindFirstChild('RootPart')
end

local function captureDeathPosition(char)
	if not char then return end

	local root = getRoot(char)
	if root then
		lastDeath = root.CFrame
	end
end

local function watchCharacter(char)
	if not char then return end

	local humanoid = char:FindFirstChildOfClass('Humanoid')
	if not humanoid then return end

	if characterConnection then
		characterConnection:Disconnect()
	end
	characterConnection = humanoid.Died:Connect(function()
		captureDeathPosition(char)
	end)
	DiedTP:Clean(characterConnection)
end

local function returnToLastDeath(char, currentGeneration)
	if not enabled or currentGeneration ~= generation or not char or not lastDeath then return end

	local root = getRoot(char)
	if not root then return end

	local humanoid = char:FindFirstChildOfClass('Humanoid')
	if humanoid and humanoid.SeatPart then
		humanoid.Sit = false
		task.wait(0.1)
	end

	if enabled and currentGeneration == generation and root.Parent then
		root.CFrame = lastDeath
	end
end

DiedTP = vape.Categories.Blatant:CreateModule({
	Name = 'DiedTP',
	Function = function(callback)
		enabled = callback
		generation = generation + 1
		local currentGeneration = generation

		if not callback then
			disconnectConnections()
			return
		end

		disconnectConnections()

		local addedConnection = entitylib.Events.LocalAdded:Connect(function(entity)
			if not enabled or currentGeneration ~= generation then return end
			local char = entity and entity.Character
			watchCharacter(char)
			task.defer(returnToLastDeath, char, currentGeneration)
		end)
		connections[#connections + 1] = addedConnection
		DiedTP:Clean(addedConnection)

		local removedConnection = entitylib.Events.LocalRemoved:Connect(function(entity)
			if not enabled or currentGeneration ~= generation then return end
			if entity and entity.Character and not lastDeath then
				captureDeathPosition(entity.Character)
			end
		end)
		connections[#connections + 1] = removedConnection
		DiedTP:Clean(removedConnection)

		if entitylib.isAlive and entitylib.character then
			watchCharacter(entitylib.character.Character)
		end
	end,
	Tooltip = 'Returns you to your last death position when you respawn.'
})
