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

-- Girls&Boys vs ZOMBIES (universe 338943399) is spread over several place ids, so the
-- product keeps one entry per place the way bedwars does:
--   796267492       main game (this base)
--   16868671031     introduction
--   16974742474     factions dedicated server
--   71856608275435  experimental build
--   85911464164622  legacy build
--   102818722798910 reserved
-- The game runs on real Team objects: Survivors, Military Volunteers, Zombies and
-- Choosing (the pre round state everyone sits in until they pick a side).
-- Its client side reporter (RobloxDialogue, fired over ReplicatedStorage['!GetAdmin'])
-- reports WalkSpeed above 50 (code 3) and faked Swimming states (code 1). It catches
-- hooks on the way out, so no hook is used: the reporter itself is a plain table in a
-- closure and its trip() returns early while webhookTripped is set, so that flag is kept
-- pinned. startForCharacter clears the flag on every respawn, hence the loop.
run(function()
	if typeof(getgc) ~= 'function' then return end

	local reporter
	for _, object in getgc(true) do
		if type(object) == 'table' and rawget(object, 'webhookTripped') ~= nil and rawget(object, 'whitelisted') ~= nil and rawget(object, 'running') ~= nil then
			reporter = object
			break
		end
	end

	if not reporter then return end

	task.spawn(function()
		while shared.vape and shared.vape.Loaded do
			reporter.webhookTripped = true
			task.wait(1)
		end
	end)
end)

-- the Adonis anti cheat core on top of that: a single gc table holding Detected, RLocked,
-- AddDetector, Detectors and Launch, which every check reports through. This is the same
-- handle Cobalt (gitlab.com/upio/cobalt) uses for its Adonis bypass: hang those functions
-- and no check can finish, so nothing gets kicked or reported from there either.
run(function()
	if typeof(getgc) ~= 'function' or typeof(hookfunction) ~= 'function' or typeof(isfunctionhooked) ~= 'function' then
		return
	end

	local core
	for _, object in getgc(true) do
		if type(object) ~= 'table' or typeof(rawget(object, 'Detected')) ~= 'function' then continue end
		if not rawget(object, 'RLocked') then continue end

		core = object
		break
	end

	if not core then return end

	for _, detection in core do
		if typeof(detection) ~= 'function' or isfunctionhooked(detection) then continue end

		hookfunction(detection, function()
			coroutine.yield()
			return task.wait(9e9)
		end)
	end
end)

-- the game measures movement from the character itself: its State Handler runs a loop that
-- reads the root part velocity (95 and 170 are treated as falls) and reports it, so flight,
-- long jumps and teleports all get read as one. Only that loop callback is disabled, not
-- the script, so its ragdoll and get up handling keep working.
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

-- the zombies are npc models in the workspace and the entity library only follows players,
-- so they are registered here: a humanoid model that belongs to nobody becomes an entity,
-- which is what Killaura, SilentAim and the esp read from. Without this every aura module
-- is blind to the actual enemy.
run(function()
	local function scan(container)
		for _, child in container:GetChildren() do
			if not child:IsA('Model') then continue end
			if playersService:GetPlayerFromCharacter(child) then continue end

			local humanoid = child:FindFirstChildWhichIsA('Humanoid')
			if humanoid and humanoid.Health > 0 and not entitylib.getEntity(child) then
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

