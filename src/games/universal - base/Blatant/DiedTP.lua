local DiedTP
local lastDeath
local connections = {}
local characterConnection
local rootConnection
local enabled = false
local generation = 0
local settleFrames = 90
local verifyTimeout = 0.35
local verifyDistance = 3

local function getRoot(char)
	if not char then return end
	return char:FindFirstChild('HumanoidRootPart') or char:FindFirstChild('RootPart')
end

local function isNear(char, target)
	local root = getRoot(char or lplr.Character)
	if not root or not target then return true end
	return (root.CFrame.Position - target.Position).Magnitude <= verifyDistance
end

local function captureDeathPosition(char)
	local root = getRoot(char)
	if root then
		lastDeath = root.CFrame
	end
end

local function disconnectConnections()
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	table.clear(connections)

	if characterConnection then
		characterConnection:Disconnect()
		characterConnection = nil
	end

	if rootConnection then
		rootConnection:Disconnect()
		rootConnection = nil
	end
	lastDeath = nil
end

local function captureIfDead(char)
	local humanoid = char and char:FindFirstChildOfClass('Humanoid')
	if humanoid and humanoid.Health > 0 then return end
	captureDeathPosition(char)
end

local function watchCharacter(char)
	local humanoid = char and char:FindFirstChildOfClass('Humanoid')
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
	if not enabled or currentGeneration ~= generation or not char then return end

	local root = getRoot(char) or char:WaitForChild('HumanoidRootPart', 5) or char:FindFirstChild('RootPart')
	local humanoid = char:FindFirstChildOfClass('Humanoid')
	local target = lastDeath
	if not root or not humanoid or not target then return end

	local frames, settled = 0, 0

	if rootConnection then
		rootConnection:Disconnect()
		rootConnection = nil
	end

	rootConnection = runService.PreSimulation:Connect(function()
		local connection = rootConnection
		if not enabled or currentGeneration ~= generation or lplr.Character ~= char or not root.Parent then return end
		if not lastDeath or humanoid.Health <= 0 then return end

		if humanoid.SeatPart then
			humanoid.Sit = false
		end

		if (root.CFrame.Position - target.Position).Magnitude > 0.1 then
			root.CFrame = target
			root.AssemblyLinearVelocity = Vector3.zero
			settled = 0
		else
			settled = settled + 1
		end

		frames = frames + 1

		if settled >= 2 or frames >= settleFrames then
			lastDeath = nil
			connection:Disconnect()
		end
	end)
	DiedTP:Clean(rootConnection)
end

DiedTP = vape.Categories.Blatant:CreateModule({
	Name = 'DiedTP',
	Function = function(callback)
		enabled = callback
		generation = generation + 1
		local currentGeneration = generation
		disconnectConnections()

		if not callback then return end

		local addedConnection = lplr.CharacterAdded:Connect(function(char)
			if not enabled or currentGeneration ~= generation then return end
			watchCharacter(char)
			task.spawn(returnToLastDeath, char, currentGeneration)
		end)
		table.insert(connections, addedConnection)
		DiedTP:Clean(addedConnection)

		local verifyConnection = lplr.CharacterAdded:Connect(function(char)
			local target = lastDeath
			if not target then return end

			task.delay(verifyTimeout, function()
				if not enabled or currentGeneration ~= generation or not isNear(char, target) then return end
				if lastDeath ~= target then return end
				lastDeath = nil
			end)
		end)
		DiedTP:Clean(verifyConnection)

		local removedConnection = entitylib.Events.LocalRemoved:Connect(function(entity)
			if enabled and currentGeneration == generation and entity and entity.Character and not lastDeath then
				captureIfDead(entity.Character)
			end
		end)
		table.insert(connections, removedConnection)
		DiedTP:Clean(removedConnection)

		if lplr.Character then
			watchCharacter(lplr.Character)
		end
	end,
	Tooltip = 'Returns you to your last death position when you respawn.'
})
