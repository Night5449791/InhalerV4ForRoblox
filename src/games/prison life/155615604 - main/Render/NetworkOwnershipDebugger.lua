local NetworkOwnershipDebugger
local Target
local Position
local Speed
local TargetName
local Movement
local NoCollide
local looping = false
local pushed = {}
local pushedCollide = {}
local spawners = {}
local didClick = {}
local partCache
local partMembers
local partCacheAt = 0
local dir = 0
local CYAN = BrickColor.new('Cyan')
local driveVelocity = Vector3.new(24, 0, 0)

local function interact(spawner)
	replicatedStorage.Remotes.InteractWithItem:InvokeServer(spawner)
end

local function executorShim(name)
	local env = getgenv and getgenv()
	return (env and env[name]) or _G[name]
end

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

local getTargetPlayer
local getTargetPart

local function getTargetPosition()
	if Target.Value == 'Player' then
		local root = getTargetPart()

		return root and root.Position
	end

	return parseVector3(Position.Value)
end

getTargetPlayer = function()
	local name = TargetName.Value:gsub('^%s+', ''):gsub('%s+$', ''):lower()

	if name == '' then
		return lplr
	end

	for _, plr in playersService:GetPlayers() do
		if plr.Name:lower() == name then
			return plr
		end
	end

	for _, plr in playersService:GetPlayers() do
		if plr.Name:lower():sub(1, #name) == name then
			return plr
		end
	end
end

local function getSpawners()
	local valid = true

	for _, spawner in spawners do
		if not spawner.Parent then
			valid = false
			break
		end
	end

	if #spawners > 0 and valid then
		return spawners
	end

	table.clear(spawners)

	for _, button in workspace.Prison_ITEMS.buttons:GetChildren() do
		if button.Name == 'Car Spawner' then
			local part = button['Car Spawner']

			if part then
				table.insert(spawners, part)
			end
		end
	end

	return spawners
end

local function fireSpawners()
	local now = os.clock()

	for _, spawner in getSpawners() do
		if (didClick[spawner] or 0) < now then
			didClick[spawner] = now + 0.2
			task.spawn(interact, spawner)
		end
	end
end

local function driveCar(dt)
	if not Movement.Enabled or not entitylib.isAlive then
		return
	end

	local root = entitylib.character.RootPart

	if not root then
		return
	end

	local now = os.clock()
	local rootPos = root.Position
	local didMove

	for _, spawner in getSpawners() do
		local offset = spawner.Position - rootPos
		local mag = offset.Magnitude

		if mag < 15 and (didClick[spawner] or 0) < now then
			didClick[spawner] = now + 0.2
			task.spawn(interact, spawner)
		end

		if mag < 50 and spawner.BrickColor == CYAN and not didMove then
			dir = math.clamp(dir + (math.clamp(offset.X, -1, 1) * dt * 24), -12, 14)
			didMove = true
		end
	end

	if not didMove then
		dir = math.clamp(dir + (math.clamp(-dir, -1, 1) * dt * 24), -12, 14)
	end

	root.CFrame = CFrame.new(610 + dir, 98, 2494)
	root.AssemblyLinearVelocity = driveVelocity
end

local function isNetworkOwned(part)
	local isnetowner = executorShim('isnetworkowner')

	if typeof(isnetowner) ~= 'function' then
		return true
	end

	local success, owned = pcall(isnetowner, part)
	return success and owned
end

local function setMaxSimRadius()
	local sethidden = executorShim('sethiddenproperty')
	local setsim = executorShim('setsimulationradius')
	local setflag = executorShim('setfflag')

	if typeof(sethidden) == 'function' then
		pcall(sethidden, lplr, 'SimulationRadius', 1e9)
		pcall(sethidden, lplr, 'MaximumSimulationRadius', 1e9)
	end

	if typeof(setsim) == 'function' then
		pcall(setsim, 1e9)
	end

	if typeof(setflag) == 'function' then
		pcall(setflag, 'MinClientSimulationRadius', '1e9')
		pcall(setflag, 'MaxClientSimulationRadius', '1e9')
		pcall(setflag, 'MinimalSimRadiusBuffer', '1e9')
	end
end

getTargetPart = function()
	local player = getTargetPlayer()
	local character = player and player.Character

	return character and character:FindFirstChild('HumanoidRootPart')
end

local function isPlayerPart(part)
	for _, player in playersService:GetPlayers() do
		local character = player.Character

		if character and part:IsDescendantOf(character) then
			return true
		end
	end

	return false
end

local function getParts()
	if partCache and (os.clock() - partCacheAt) < 1 then
		return partCache, partMembers
	end

	local parts, seen, members = {}, {}, {}

	for _, v in workspace:GetDescendants() do
		if v:IsA('BasePart') and not v.Anchored and not isPlayerPart(v) then
			local root = v.AssemblyRootPart

			if root then
				if not seen[root] then
					seen[root] = true
					members[root] = {}
					table.insert(parts, root)
				end

				table.insert(members[root], v)
			end
		end
	end

	partCache = parts
	partMembers = members
	partCacheAt = os.clock()

	return parts, members
end

local function pushTowards(part, position, speed)
	local offset = position - part.Position

	if offset.Magnitude < 1e-3 then
		offset = Vector3.new(0, 1, 0)
	end

	part.AssemblyLinearVelocity = offset.Unit * speed
end

local function saveVelocity(part)
	if pushed[part] == nil then
		pushed[part] = part.AssemblyLinearVelocity
	end
end

local function setCollision(members)
	for _, member in members do
		if pushedCollide[member] == nil then
			pushedCollide[member] = member.CanCollide
		end

		member.CanCollide = false
	end
end

local function restoreVelocities()
	for part, velocity in pushed do
		if part.Parent then
			part.AssemblyLinearVelocity = velocity
		end
	end

	for part, collide in pushedCollide do
		if part.Parent then
			part.CanCollide = collide
		end
	end

	table.clear(pushed)
	table.clear(pushedCollide)
	table.clear(didClick)
	partCache = nil
	partMembers = nil
end

local function runControl()
	local position = getTargetPosition()

	if not position then
		return false
	end

	local speed = Speed.Value
	local noCollide = NoCollide.Enabled
	local parts, members = getParts()
	local pushedCount = 0

	for _, part in parts do
		if not isNetworkOwned(part) then
			continue
		end

		saveVelocity(part)
		pushTowards(part, position, speed)

		if noCollide then
			setCollision(members[part])
		end

		pushedCount = pushedCount + 1
	end

	if pushedCount == 0 then
		return false
	end

	return true
end

NetworkOwnershipDebugger = vape.Categories.Render:CreateModule({
	Name = 'NetworkOwnershipDebugger',
	Function = function(callback)
		local physicsSettings = settings():GetService('PhysicsSettings')

		physicsSettings.AreOwnersShown = callback and true or false

		if not callback then
			looping = false
			restoreVelocities()
		end
	end,
	Tooltip = 'Shows the network owner of every part in the world.'
})
Target = NetworkOwnershipDebugger:CreateDropdown({
	Name = 'Target',
	List = {'Player', 'Vector3'},
	Function = function(val)
		Position.Object.Visible = val == 'Vector3'
		TargetName.Object.Visible = val == 'Player'
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
NetworkOwnershipDebugger:CreateButton({
	Name = 'Use my position',
	Function = function()
		local root = entitylib.isAlive and entitylib.character.RootPart

		if not root then
			notif('NetworkOwnershipDebugger', 'Character missing.', 5, 'warning')
			return
		end

		local position = root.Position
		Position:SetValue(math.round(position.X)..', '..math.round(position.Y)..', '..math.round(position.Z))
	end,
	Tooltip = 'Fills the Position field with your character position'
})
TargetName = NetworkOwnershipDebugger:CreateTextBox({
	Name = 'Player',
	Function = function()
		local name = TargetName.Value:gsub('^%s+', ''):gsub('%s+$', '')

		if name ~= '' and not getTargetPlayer() then
			notif('NetworkOwnershipDebugger', 'No player named '..name, 5, 'warning')
		end
	end,
	Default = '',
	Placeholder = 'Empty for yourself',
	Tooltip = 'Name or display name of the player whose character is used as the target'
})
Speed = NetworkOwnershipDebugger:CreateSlider({
	Name = 'Speed',
	Min = 1,
	Max = 1000,
	Default = 100,
	Decimal = 1
})
Movement = NetworkOwnershipDebugger:CreateToggle({
	Name = 'Movement',
	Default = true,
	Tooltip = 'Drives a car around the prison while flinging'
})
NoCollide = NetworkOwnershipDebugger:CreateToggle({
	Name = 'No collision',
	Default = true,
	Tooltip = 'Turns off collision on every thrown part, restores it when stopped'
})
NetworkOwnershipDebugger:CreateButton({
	Name = 'Control Parts',
	Function = function()
		if looping then
			looping = false
			dir = 0
			restoreVelocities()
			notif('NetworkOwnershipDebugger', 'Stopped controlling parts', 5)
			return
		end

		looping = true
		notif('NetworkOwnershipDebugger', 'Controlling parts, press again to stop', 5)

		task.spawn(function()
			local lastClock = os.clock()

			while looping do
				local now = os.clock()
				local dt = now - lastClock
				lastClock = now

				setMaxSimRadius()
				pcall(fireSpawners)
				pcall(driveCar, dt)
				pcall(runControl)
				task.wait()
			end
		end)
	end,
	Tooltip = 'Velocity throws every unanchored part at the target'
})
