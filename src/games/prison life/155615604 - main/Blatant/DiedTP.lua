local DiedTP
local lastDeath
local connections = {}
local characterConnection
local enabled = false
local generation = 0

local function isCriminalTeam()
	return lplr.Team == teams.Criminals
end

local function getRoot(char)
	if not char then return end
	return char:FindFirstChild('HumanoidRootPart') or char:FindFirstChild('RootPart')
end

local function captureDeathPosition(char)
	if isCriminalTeam() then
		lastDeath = nil
		return
	end

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
	lastDeath = nil
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
	if isCriminalTeam() then
		lastDeath = nil
		return
	end
	if not enabled or currentGeneration ~= generation or not char or not lastDeath then return end

	local root = getRoot(char) or char:WaitForChild('HumanoidRootPart', 5) or char:FindFirstChild('RootPart')
	if not root or not lastDeath or not enabled or currentGeneration ~= generation or isCriminalTeam() then return end

	if enabled and currentGeneration == generation and root.Parent and not isCriminalTeam() then
		root.CFrame = lastDeath
		lastDeath = nil
	end
end

DiedTP = vape.Categories.Blatant:CreateModule({
	Name = 'DiedTP',
	Function = function(callback)
		enabled = callback
		generation = generation + 1
		local currentGeneration = generation
		disconnectConnections()

		if not callback then return end

		local addedConnection = entitylib.Events.LocalAdded:Connect(function(entity)
			if not enabled or currentGeneration ~= generation then return end
			watchCharacter(entity and entity.Character)
		end)
		table.insert(connections, addedConnection)
		DiedTP:Clean(addedConnection)

		local respawnConnection = lplr.CharacterAdded:Connect(function(char)
			local autoPickup = vape.Modules.AutoPickup
			if autoPickup and autoPickup.Enabled and autoPickup.OnDiedTPRespawn then
				local destination = lastDeath
				if isCriminalTeam() then
					destination = nil
				end

				if autoPickup:OnDiedTPRespawn(char, destination) then
					lastDeath = nil
					return
				end
			end

			task.spawn(returnToLastDeath, char, currentGeneration)
		end)
		table.insert(connections, respawnConnection)
		DiedTP:Clean(respawnConnection)

		local removedConnection = entitylib.Events.LocalRemoved:Connect(function(entity)
			if enabled and currentGeneration == generation and entity and entity.Character and not lastDeath then
				captureDeathPosition(entity.Character)
			end
		end)
		table.insert(connections, removedConnection)
		DiedTP:Clean(removedConnection)

		local teamConnection = lplr:GetPropertyChangedSignal('Team'):Connect(function()
			if isCriminalTeam() then
				lastDeath = nil
			end
		end)
		table.insert(connections, teamConnection)
		DiedTP:Clean(teamConnection)

		if entitylib.isAlive and entitylib.character then
			watchCharacter(entitylib.character.Character)
		end
	end,
	Tooltip = 'Returns you to your last death position when you respawn.'
})
