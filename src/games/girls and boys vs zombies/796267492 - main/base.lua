local run = function(func)
	func()
end
local cloneref = cloneref or function(obj)
	return obj
end
local vapeEvents = setmetatable({}, {
	__index = function(self, index)
		self[index] = Instance.new('BindableEvent')
		return self[index]
	end
})

local playersService = cloneref(game:GetService('Players'))
local inputService = cloneref(game:GetService('UserInputService'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local collectionService = cloneref(game:GetService('CollectionService'))
local runService = cloneref(game:GetService('RunService'))
local coreGui = cloneref(game:GetService('CoreGui'))

local gameCamera = workspace.CurrentCamera
local lplr = playersService.LocalPlayer
local vape = shared.vape
local entitylib = vape.Libraries.entity
local whitelist = vape.Libraries.whitelist
local targetinfo = vape.Libraries.targetinfo
local sessioninfo = vape.Libraries.sessioninfo

local function isFriend(plr, recolor)
	if vape.Categories.Friends.Options['Use friends'].Enabled then
		local friend = table.find(vape.Categories.Friends.ListEnabled, plr.Name) and true
		if recolor then
			friend = friend and vape.Categories.Friends.Options['Recolor visuals'].Enabled
		end
		return friend
	end
	return nil
end

local function isTarget(plr)
	return table.find(vape.Categories.Targets.ListEnabled, plr.Name) and true
end

local function notif(...)
	return vape:CreateNotification(...)
end

-- the reporter's webhookTripped flag is pinned so trip() returns early; startForCharacter
-- clears it on every respawn, hence the loop
local function gcTables(keys)
	if typeof(filtergc) == 'function' then
		return filtergc('table', {Keys = keys}, false)
	end

	local found = {}
	if typeof(getgc) ~= 'function' then return found end

	for _, object in getgc(true) do
		if type(object) ~= 'table' then continue end

		local matches = true
		for _, key in keys do
			if rawget(object, key) == nil then
				matches = false
				break
			end
		end

		if matches then
			table.insert(found, object)
		end
	end

	return found
end

run(function()
	task.delay(3, function()
		local reporter
		for _, object in gcTables({'webhookTripped', 'whitelisted', 'running'}) do
			reporter = object
			break
		end

		if not reporter then return end

		task.spawn(function()
			while shared.vape and shared.vape.Loaded do
				reporter.webhookTripped = true
				task.wait(1)
			end
		end)
	end)
end)

-- only the State Handler loop is disabled, not the script, so ragdoll and get up keep working
run(function()
	if typeof(getconnections) ~= 'function' then return end

	local signals = {
		runService.Heartbeat,
		runService.Stepped,
		runService.PreSimulation,
		runService.PostSimulation,
		runService.RenderStepped
	}

	local function silence()
		for _, signal in signals do
			for _, connection in getconnections(signal) do
				if typeof(connection.Function) ~= 'function' then continue end

				local ok, source = pcall(debug.info, connection.Function, 's')
				if ok and source and source:find('State Handler', 1, true) then
					connection:Disable()
				end
			end
		end
	end

	task.spawn(function()
		task.wait(5) -- let the character and its scripts exist before touching connections

		while shared.vape and shared.vape.Loaded do
			silence()
			task.wait(2)
		end
	end)
end)
run(function()
	entitylib.targetCheck = function(entity)
		if entity.TeamCheck then
			return entity:TeamCheck()
		end
		if entity.NPC then return true end
		if isFriend(entity.Player) then return false end
		if not select(2, whitelist:get(entity.Player)) then return false end

		local team, targetTeam = lplr.Team, entity.Player.Team
		if not team or not targetTeam then return true end

		-- nobody picked a side yet, so Choosing is not a team to respect
		if targetTeam.Name == 'Choosing' then return true end
		if vape.Settings.Modules.Options['Teams by server'].Enabled then
			return team ~= targetTeam
		end

		return true
	end
end)

-- the zombies are npc models, so every aura module is blind to them without this
run(function()
	local function scan(container)
		for _, child in container:GetChildren() do
			if not child:IsA('Model') then continue end
			if playersService:GetPlayerFromCharacter(child) then continue end

			local humanoid = child:FindFirstChildWhichIsA('Humanoid')
			local root = child:FindFirstChild('HumanoidRootPart')
			if root and humanoid and humanoid.Health > 0 and humanoid.Health < 1e9 and not entitylib.getEntity(child) then
				entitylib.addEntity(child, nil)
			end
		end
	end

	task.spawn(function()
		while shared.vape and shared.vape.Loaded do
			scan(workspace)

			for _, child in workspace:GetChildren() do
				if child:IsA('Folder') then
					scan(child)
				end
			end

			task.wait(1)
		end
	end)
end)

-- the anti cheat strips RaycastParams.new once it notices the executor, which makes the
-- blaster's castRays throw on every shot and stops it from ever reaching the server. The
-- same raycast is done here without RaycastParams so the gun keeps working normally.
run(function()
	if typeof(hookfunction) ~= 'function' then return end

	local blaster = replicatedStorage:FindFirstChild('Blaster')
	local utility = blaster and blaster:FindFirstChild('Utility')
	local castRays = utility and utility:FindFirstChild('castRays')
	if not castRays then return end

	local constantsTable = {}
	local constantsModule = blaster and blaster:FindFirstChild('Constants')
	if constantsModule then
		local ok, value = pcall(require, constantsModule)
		if ok then constantsTable = value end
	end

	local canDamage
	local canDamageModule = utility and utility:FindFirstChild('canPlayerDamageHumanoid')
	if canDamageModule then
		local ok, fn = pcall(require, canDamageModule)
		canDamage = ok and fn or nil
	end

	local collectionService = game:GetService('CollectionService')

	local function cast(origin, radius, direction, player, nonStatic)
		local hit = workspace:Spherecast(origin, radius, direction)
		if not hit then return nil end

		local character = player and player.Character
		if character and hit.Instance:IsDescendantOf(character) then return nil end

		local excludeTag = constantsTable.rayExcludeTag
		if excludeTag and collectionService:HasTag(hit.Instance, excludeTag) then return nil end

		if nonStatic then
			local nonStaticTag = constantsTable.nonStaticTag
			if nonStaticTag and collectionService:HasTag(hit.Instance, nonStaticTag) then return nil end
		end

		return hit
	end

	hookfunction(require(castRays), function(player, origin, directions, radius, nonStatic)
		local results = {}
		for _, direction in directions do
			local entry = {
				position = origin + direction,
				normal = direction.Unit
			}

			local hit = cast(origin, radius, direction, player, nonStatic)
			if hit then
				entry.position = hit.Position
				entry.normal = hit.Normal
				entry.instance = hit.Instance

				local parent = hit.Instance.Parent
				local humanoid = parent and parent:FindFirstChildOfClass('Humanoid')
				if humanoid and (not canDamage or canDamage(player, humanoid)) then
					entry.taggedHumanoid = humanoid
				end
			end

			table.insert(results, entry)
		end

		return results
	end)
end)

