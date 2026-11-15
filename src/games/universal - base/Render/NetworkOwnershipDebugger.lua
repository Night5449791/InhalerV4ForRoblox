local NetworkOwnershipDebugger
local ControlMode
local Target
local Position
local Speed
local TargetName
local LoopDelay
local OnlyOwned
local NoCollide
local looping = false
local pushed = {}
local pushedCollide = {}
local partCache
local partMembers
local partCacheAt = 0

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

local function getTargetPosition()
	if Target.Value == 'Player' then
		local player = getTargetPlayer()
		local character = player and player.Character

		if not character then
			return
		end

		local root = character:FindFirstChild('HumanoidRootPart')

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
	partCache = nil
	partMembers = nil
end

local function runControl()
	local position = getTargetPosition()

	if not position then
		return false
	end

	if ControlMode.Value == 'CFrame' then
		local player = getTargetPlayer()
		local character = player and player.Character
		local root = character and character:FindFirstChild('HumanoidRootPart')

		if not root then
			return false
		end

		root.CFrame = CFrame.lookAt(position, position - root.CFrame.LookVector)
		return true
	end

	local speed = Speed.Value
	local onlyOwned = OnlyOwned.Enabled
	local noCollide = NoCollide.Enabled
	local parts, members = getParts()
	local pushedCount = 0

	for _, part in parts do
		if onlyOwned and not isNetworkOwned(part) then
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
ControlMode = NetworkOwnershipDebugger:CreateDropdown({
	Name = 'Control mode',
	List = {'Velocity', 'CFrame'},
	Tooltip = 'Velocity - throws every unanchored part at the target\nCFrame - moves your character onto the target'
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
LoopDelay = NetworkOwnershipDebugger:CreateSlider({
	Name = 'Loop delay',
	Min = 0,
	Max = 1,
	Default = 0,
	Decimal = 100,
	Tooltip = 'Seconds between each control pass'
})
OnlyOwned = NetworkOwnershipDebugger:CreateToggle({
	Name = 'Only network owned',
	Default = false,
	Tooltip = 'Skip parts your client does not simulate, they ignore the velocity change anyway'
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
			restoreVelocities()
			notif('NetworkOwnershipDebugger', 'Stopped controlling parts', 5)
			return
		end

		looping = true
		notif('NetworkOwnershipDebugger', 'Controlling parts, press again to stop', 5)

		task.spawn(function()
			while looping do
				setMaxSimRadius()

				if not runControl() then
					looping = false
					restoreVelocities()
					notif('NetworkOwnershipDebugger', 'Control stopped.', 5, 'warning')
					break
				end

				task.wait(LoopDelay.Value)
			end
		end)
	end,
	Tooltip = 'Velocity throws every unanchored part at the target, CFrame teleports your character to it'
})
