local DiedTP
local lastDeath
local lastAlive
local deathConnection
local aliveConnection
local teleportConnection
local generation = 0
local enabled = false
local aliveClock = 0
local holdFrames = 30
local settleFrames = 120
local captureDistance = 25
local killPlaneOffset = 10
local verifyDistance = 3

local function getRoot(char)
	if not char then return end
	return char:FindFirstChild('HumanoidRootPart') or char:FindFirstChild('RootPart')
end

local function getHumanoid(char)
	return char and char:FindFirstChildOfClass('Humanoid')
end

local function clearState()
	if deathConnection then
		deathConnection:Disconnect()
		deathConnection = nil
	end
	if aliveConnection then
		aliveConnection:Disconnect()
		aliveConnection = nil
	end
	if teleportConnection then
		teleportConnection:Disconnect()
		teleportConnection = nil
	end
	lastDeath = nil
	lastAlive = nil
	aliveClock = 0
end

local function validPosition(cframe)
	return cframe and cframe.Position.Y > workspace.FallenPartsDestroyHeight + killPlaneOffset
end

local function rememberAlive(char)
	local root = getRoot(char)
	local humanoid = getHumanoid(char)
	if not root or not humanoid or humanoid.Health <= 0 then return end

	local suc, cframe = pcall(function()
		return root.CFrame
	end)
	if suc and validPosition(cframe) then
		lastAlive = cframe
	end
end

local function captureDeath(char)
	local humanoid = getHumanoid(char)
	if humanoid and humanoid.Health > 0 then return end

	local root = getRoot(char)
	local target

	if root then
		local suc, cframe = pcall(function()
			return root.CFrame
		end)
		if suc and validPosition(cframe) and (not lastAlive or (cframe.Position - lastAlive.Position).Magnitude <= captureDistance) then
			target = cframe
		end
	end
	lastDeath = target or lastAlive
end

local function watchDeath(char, currentGeneration)
	if deathConnection then
		deathConnection:Disconnect()
		deathConnection = nil
	end

	local humanoid = getHumanoid(char)
	if not humanoid then return end

	deathConnection = humanoid.Died:Connect(function()
		if enabled and currentGeneration == generation then
			captureDeath(char)
		end
	end)
	DiedTP:Clean(deathConnection)
end

local function returnToDeath(char, currentGeneration)
	if not enabled or currentGeneration ~= generation then return end

	local humanoid = getHumanoid(char)
	local root = getRoot(char)
	local target = lastDeath
	if not humanoid or not root or not target then return end
	if (root.CFrame.Position - target.Position).Magnitude <= verifyDistance then
		lastDeath = nil
		return
	end

	local previousPlatformStand = humanoid.PlatformStand
	humanoid.Sit = false
	humanoid.PlatformStand = true

	local frames, settled = 0, 0
	local function finish()
		if teleportConnection then
			teleportConnection:Disconnect()
			teleportConnection = nil
		end
		if humanoid.Parent then
			humanoid.PlatformStand = previousPlatformStand
		end
		lastDeath = nil
	end

	teleportConnection = runService.PreSimulation:Connect(function()
		if not enabled or currentGeneration ~= generation or lplr.Character ~= char or not root.Parent or not humanoid.Parent or humanoid.Health <= 0 then
			finish()
			return
		end

		if (root.CFrame.Position - target.Position).Magnitude > 0.1 then
			root.CFrame = target
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
			settled = 0
		else
			settled = settled + 1
		end

		frames = frames + 1

		if settled >= holdFrames or frames >= settleFrames then
			finish()
		end
	end)
	DiedTP:Clean(teleportConnection)
end

DiedTP = vape.Categories.Blatant:CreateModule({
	Name = 'DiedTP',
	Function = function(callback)
		clearState()
		enabled = callback
		generation = generation + 1
		local currentGeneration = generation
		if not callback then return end

		DiedTP:Clean(entitylib.Events.LocalAdded:Connect(function(entity)
			if not enabled or currentGeneration ~= generation then return end
			local char = entity and entity.Character
			if not char then return end
			watchDeath(char, currentGeneration)
			if lastDeath then
				returnToDeath(char, currentGeneration)
			end
		end))

		DiedTP:Clean(entitylib.Events.LocalRemoved:Connect(function(entity)
			if not enabled or currentGeneration ~= generation or lastDeath then return end
			captureDeath(entity and entity.Character)
		end))

		aliveConnection = runService.PreSimulation:Connect(function()
			local clock = os.clock()
			if clock - aliveClock < 0.15 then return end
			aliveClock = clock
			rememberAlive(lplr.Character)
		end)
		DiedTP:Clean(aliveConnection)

		if entitylib.isAlive and entitylib.character then
			watchDeath(entitylib.character.Character, currentGeneration)
			rememberAlive(entitylib.character.Character)
		end
	end,
	Tooltip = 'Returns you to your last death position when you respawn.'
})
