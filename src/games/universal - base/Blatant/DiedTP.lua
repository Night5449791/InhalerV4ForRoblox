local DiedTP
local lastDeath
local connections = {}
local characterConnection
local enabled = false
local generation = 0
-- how long after `CharacterAdded` the server keeps overwriting the root. The respawn
-- lands on the spawn location ~1s in, so a write before that is simply replaced
local SETTLE_TIMEOUT = 2.5
local SETTLE_STEP = 0.05

local function getRoot(char)
	if not char then return end
	return char:FindFirstChild('HumanoidRootPart') or char:FindFirstChild('RootPart')
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
	lastDeath = nil
end

-- the humanoid is in `Dead` while the server is still tearing the old body down, and
-- that is the only moment the death CFrame is still readable; a character that is
-- already gone keeps the last value `Died` stored
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

-- `CharacterAdded` fires before the server has placed the body, so a single write is
-- thrown away: in a measured respawn the root sat at the spawn location until ~1s and
-- every write before that was overwritten. The position is re-asserted for
-- `SETTLE_TIMEOUT` instead, and the loop stops as soon as it sticks. The velocity is
-- cleared with it or the body keeps falling from wherever it was spawned.
local function returnToLastDeath(char, currentGeneration)
	if not enabled or currentGeneration ~= generation or not char then return end

	local root = getRoot(char) or char:WaitForChild('HumanoidRootPart', 5) or char:FindFirstChild('RootPart')
	local humanoid = char:FindFirstChildOfClass('Humanoid')
	local target = lastDeath
	if not root or not humanoid or not target then return end

	local deadline = os.clock() + SETTLE_TIMEOUT
	local settled = 0

	repeat
		if not enabled or currentGeneration ~= generation or lplr.Character ~= char or not root.Parent then
			return
		end

		if not lastDeath then return end

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

		task.wait(SETTLE_STEP)
	until settled >= 3 or os.clock() > deadline

	if enabled and currentGeneration == generation and lplr.Character == char and settled >= 3 then
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
			task.spawn(returnToLastDeath, char, currentGeneration)
		end)
		table.insert(connections, respawnConnection)
		DiedTP:Clean(respawnConnection)

		-- the root is normally gone by the time `LocalRemoved` fires, so this is only
		-- the fallback for rigs where `Died` never ran; the check keeps it from
		-- overwriting the death spot with a spawn position
		local removedConnection = entitylib.Events.LocalRemoved:Connect(function(entity)
			if enabled and currentGeneration == generation and entity and entity.Character and not lastDeath then
				captureIfDead(entity.Character)
			end
		end)
		table.insert(connections, removedConnection)
		DiedTP:Clean(removedConnection)

		if entitylib.isAlive and entitylib.character then
			watchCharacter(entitylib.character.Character)
		end
	end,
	Tooltip = 'Returns you to your last death position when you respawn.'
})
