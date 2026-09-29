local ChatCommand

local options = {}
local viewConnection
local followModule, followOldMove
local followPlayer
local followConnection
local teamsService = cloneref(game:GetService('Teams'))
local teleportService = cloneref(game:GetService('TeleportService'))
local teamAliases = {
	g = 'Guards',
	guards = 'Guards',
	i = 'Inmates',
	inmates = 'Inmates'
}

local function trim(text)
	return text and text:match('^%s*(.-)%s*$') or nil
end

local function setListValue(list, value, enabled)
	if list and enabled ~= (table.find(list.ListEnabled, value) ~= nil) then
		list:ChangeValue(value)
	end
end

local function clearListValues(list)
	if not list then return 0 end

	local count = #list.List
	if count == 0 and #list.ListEnabled == 0 then return 0 end

	table.clear(list.List)
	table.clear(list.ListEnabled)
	list:ChangeValue()
	return count
end

local function disconnect(connection)
	if connection then
		connection:Disconnect()
	end

	return nil
end

-- Camera

local function getLocalHumanoid()
	local character = lplr.Character
	return character and character:FindFirstChildOfClass('Humanoid')
		or (entitylib.character and entitylib.character.Humanoid)
end

local function clearViewConnection()
	viewConnection = disconnect(viewConnection)
end

local function restoreCamera()
	clearViewConnection()

	local humanoid = getLocalHumanoid()
	if humanoid then
		gameCamera.CameraSubject = humanoid
		gameCamera.CameraType = Enum.CameraType.Custom
	end
end

-- Player lookup

local function findEntity(prefix, includeDead)
	prefix = trim(prefix)
	if not prefix or prefix == '' then return end

	local lowered = prefix:lower()
	local length = #lowered
	for _, entity in entitylib.List do
		if entity and entity.Humanoid and (includeDead or entity.Humanoid.Health > 0) then
			local player = entity.Player
			local name = player and player.Name
			local displayName = player and player.DisplayName
			if (name and name:lower():sub(1, length) == lowered) or (displayName and displayName:lower():sub(1, length) == lowered) then
				return entity
			end
		end
	end
end

local function findPlayer(prefix, allowLeft)
	prefix = trim(prefix)
	if not prefix or prefix == '' then return end

	local entity = findEntity(prefix, true)
	if entity then
		return entity.Player
	end

	if allowLeft then
		return playersService:FindFirstChild(prefix)
	end
end

-- KickExploit bridge

local function kickModule()
	return vape.Modules.KickExploit
end

local function setKickTarget(name, enabled)
	local module = kickModule()
	if module then
		setListValue(module.Options['Targets'], name, enabled)
	end
end

local function clearAllTargets()
	local count = clearListValues(vape.Categories.Targets)
	notif('Blacklist', count > 0 and 'Cleared '..count..' target'..plural(count) or 'No targets to clear.', 5)
end

local function setKickEnabled(module, enabled)
	if module.Enabled ~= enabled then
		module:Toggle()
	end
end

local function startKick(mode, text)
	local module = kickModule()
	if not module then return end

	module.Options['Mode']:SetValue(mode)
	setKickEnabled(module, true)
	notif('KickExploit', text, 5)
end

local function stopKick()
	local module = kickModule()
	if module then
		setKickEnabled(module, false)
	end

	notif('KickExploit', 'Kick disabled.', 5)
end

-- Follow

local function getFollowEntity()
	if not followPlayer then return end

	local entity = entitylib.getEntity(followPlayer)
	return entity and entity.Health > 0 and entity or nil
end

local function stopFollow()
	followConnection = disconnect(followConnection)

	if followModule and followOldMove then
		followModule.moveFunction = followOldMove
	end

	followModule, followOldMove = nil, nil
	followPlayer = nil
end

local function startFollow(player)
	stopFollow()

	local module
	if not pcall(function()
		module = require(lplr.PlayerScripts.PlayerModule).controls
	end) or not module or not module.moveFunction then
		notif('ChatCommand', 'Follow is not supported in this game.', 5, 'warning')
		return
	end

	followPlayer = player
	followModule = module
	followOldMove = module.moveFunction

	module.moveFunction = function(self, vec, face)
		local humanoid = getLocalHumanoid()
		if not humanoid or humanoid.Health <= 0 then
			return followOldMove(self, vec, face)
		end

		local targetEntity = getFollowEntity()
		local targetRoot = targetEntity and targetEntity.RootPart
		local root = entitylib.character and entitylib.character.RootPart
		if targetRoot and root then
			local direction = (targetRoot.Position - root.Position) * Vector3.new(1, 0, 1)
			if direction.Magnitude > 1 then
				vec = direction.Unit
			end
		end

		return followOldMove(self, vec, face)
	end

	followConnection = runService.PreSimulation:Connect(function()
		local humanoid = getLocalHumanoid()
		if not humanoid or humanoid.Health <= 0 then
			stopFollow()
			return
		end

		if humanoid.Sit then
			humanoid.Sit = false
		end

		if not getFollowEntity() then
			stopFollow()
		end
	end)
end

-- Team switching

local function clickTeamButton(teamName)
	local gui = lplr.PlayerGui:FindFirstChild('TeamsFrame', true)
	if not gui then return false end

	local lowered = teamName:lower()
	for _, holder in gui:GetChildren() do
		local button = holder:FindFirstChild('Button')
		if button and button.AutoButtonColor then
			local text = (holder.Name..' '..button.Text):lower()
			for _, label in holder:GetDescendants() do
				if label:IsA('TextLabel') or label:IsA('TextButton') then
					text = text..' '..label.Text:lower()
				end
			end

			if text:find(lowered, 1, true) then
				firesignal(button.MouseButton1Click)
				return true
			end
		end
	end

	return false
end

local function handleTeam(args)
	if not options.ChangeTeam.Enabled then return end

	local command = args and args:match('^%S+$')
	local teamName = command and teamAliases[command:lower()]
	if not teamName then return end

	ChatCommand:Clean(task.spawn(function()
		local remotes = replicatedStorage:FindFirstChild('Remotes')
		local requestTeamChange = remotes and remotes:FindFirstChild('RequestTeamChange')
		local neutral = teamsService:FindFirstChild('Neutral')
		local targetTeam = teamsService:FindFirstChild(teamName)
		if not targetTeam then return end

		if lplr.Team ~= neutral then
			if requestTeamChange and neutral then
				requestTeamChange:InvokeServer(neutral, 1)
			end
			task.wait(1.5)
		end

		if not clickTeamButton(teamName) and requestTeamChange then
			requestTeamChange:InvokeServer(targetTeam, 1)
		end
	end))
end

local function handleReload()
	if not options.ReloadVape.Enabled then return end

	if delfile then
		delfile('newvape/main.lua')
	end

	if delfolder then
		for _, folder in {'newvape/libraries', 'newvape/games', 'newvape/guis'} do
			if isfolder and isfolder(folder) then
				delfolder(folder)
			end
		end
	end

	loadstring(game:HttpGet('https://raw.githubusercontent.com/Night5449791/VapeV4ForRoblox/main/NewMainScript.lua', true))()
end

local function handleHop()
	if not options.ServerHop.Enabled then return end

	local serverHop = vape.Modules.ServerHop
	if serverHop and not serverHop.Enabled then
		serverHop:Toggle()
	end
end

local function handleRejoin()
	if not options.Rejoin.Enabled then return end

	if playersService.NumPlayers > 1 then
		teleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId)
	else
		teleportService:Teleport(game.PlaceId)
	end
end

local function handleWhitelist(args, remove)
	if not options.Whitelist.Enabled then return end

	local player = findPlayer(args, remove)
	if not player then
		notif('Whitelist', 'No player found.', 5, 'warning')
		return
	end

	setListValue(vape.Categories.Friends, player.Name, not remove)
	notif('Whitelist', player.DisplayName..' has been '..(remove and 'unwhitelisted.' or 'whitelisted.'), 5)
end

local function handleTargets(args, remove)
	if not options.Blacklist.Enabled then return end

	args = trim(args)
	if not args or args == '' then return end

	if args:lower() == 'all' then
		clearAllTargets()
		return
	end

	local player = findPlayer(args, remove)
	if not player then
		notif('Blacklist', 'No player found.', 5, 'warning')
		return
	end

	setListValue(vape.Categories.Targets, player.Name, not remove)
	notif('Blacklist', player.DisplayName..' has been '..(remove and 'unblacklisted.' or 'blacklisted.'), 5)
end

local function handleKick(args)
	if not options.Kick.Enabled then return end

	if not kickModule() then
		notif('ChatCommand', 'KickExploit is not available in this game.', 5, 'warning')
		return
	end

	local name = trim((args or ''):match('^target%s+(.+)$') or args)
	if not name or name == '' then return end

	local lowered = name:lower()
	if lowered == 'all' then
		startKick('All', 'Flinging all players.')
		return
	elseif lowered == 'none' then
		stopKick()
		return
	end

	local player = findPlayer(name, true)
	if not player then
		notif('KickExploit', 'No player found.', 5, 'warning')
		module.Options['Mode']:SetValue("All")
		return
	end

	setKickTarget(player.Name, true)
	setListValue(vape.Categories.Targets, player.Name, true)
	startKick('Individual', 'Flinging '..player.Name..'.')
end

local function handleTP(args)
	if not options.PlayerTP.Enabled then return end

	local target = findEntity(args)
	local localRoot = entitylib.character and entitylib.character.RootPart
	if not target or not target.RootPart or not localRoot then
		notif('ChatCommand', 'No living player found.', 5, 'warning')
		return
	end

	localRoot.CFrame = target.RootPart.CFrame + Vector3.new(0, 2, 0)
end

local function handleFollow(args)
	if not options.PlayerFollow.Enabled then return end

	local target = findEntity(args)
	if not target or not target.Player then
		notif('ChatCommand', 'No living player found.', 5, 'warning')
		return
	end

	startFollow(target.Player)
	notif('ChatCommand', 'Following '..target.Player.DisplayName..'.', 5)
end

local function handleUnfollow()
	stopFollow()
	notif('ChatCommand', 'Stopped following.', 5)
end

local function handleView(args)
	if not options.PlayerView.Enabled then return end

	local target = findEntity(args)
	if not target or not target.Humanoid then
		notif('ChatCommand', 'No living player found.', 5, 'warning')
		return
	end

	clearViewConnection()
	gameCamera.CameraSubject = target.Humanoid
	viewConnection = target.Humanoid.Died:Connect(restoreCamera)
end

local function onChatted(message)
	message = trim(message)
	if message:sub(1, 1) ~= '.' then return end

	local command, args = message:sub(2):match('^(%S+)%s*(.*)$')
	command = command and command:lower()
	args = args ~= '' and args or nil
	if not command then return end

	if command == 'team' then
		handleTeam(args)
	elseif command == 'reload' then
		handleReload()
	elseif command == 'hop' or command == 'serverhop' then
		handleHop()
	elseif command == 'rj' or command == 'rejoin' then
		handleRejoin()
	elseif command == 'wl' or command == 'whitelist' then
		handleWhitelist(args, false)
	elseif command == 'unwl' or command == 'unwhitelist' then
		handleWhitelist(args, true)
	elseif command == 'target' or command == 'blacklist' then
		handleTargets(args, false)
	elseif command == 'untarget' or command == 'unblacklist' then
		handleTargets(args, true)
	elseif command == 'kick' then
		handleKick(args)
	elseif command == 'unview' then
		restoreCamera()
	elseif command == 'follow' then
		handleFollow(args)
	elseif command == 'unfollow' then
		handleUnfollow()
	elseif command == 'tp' then
		handleTP(args)
	elseif command == 'view' then
		handleView(args)
	end
end

ChatCommand = vape.Categories.Utility:CreateModule({
	Name = 'ChatCommand',
	Function = function(callback)
		if not callback then return end

		ChatCommand:Clean(restoreCamera)
		ChatCommand:Clean(stopFollow)
		ChatCommand:Clean(lplr.Chatted:Connect(onChatted))
	end
})

local toggles = {
	{Name = 'PlayerTP', Tooltip = '.tp <plr>'},
	{Name = 'PlayerFollow', Tooltip = '.follow <plr>\n.unfollow', Function = function(enabled)
		if not enabled then
			stopFollow()
		end
	end},
	{Name = 'PlayerView', Tooltip = '.view <plr>\n.unview', Function = function(enabled)
		if not enabled then
			restoreCamera()
		end
	end},
	{Name = 'Rejoin', Tooltip = '.rj\n.rejoin'},
	{Name = 'ServerHop', Tooltip = '.hop\n.serverhop'},
	{Name = 'ReloadVape', Tooltip = '.reload'},
	{Name = 'ChangeTeam', Tooltip = '.team <g/i>'},
	{Name = 'Whitelist', Tooltip = '.wl/.whitelist <plr>\n.unwl/.unwhitelist <plr>'},
	{Name = 'Blacklist', Tooltip = '.target/.blacklist <plr>\n.untarget/.unblacklist <plr>\n.untarget all/.target all clears every target'},
	{Name = 'Kick', Tooltip = '.kick <plr>\n.kick all\n.kick none'}
}

for _, toggle in toggles do
	options[toggle.Name] = ChatCommand:CreateToggle({
		Name = toggle.Name,
		Tooltip = toggle.Tooltip,
		Default = true,
		Function = toggle.Function
	})
end
