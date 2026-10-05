local ChatCommand
local addTarget
local kickTargetList
local TARGET_COLOR = Color3.new(1, 0, 0)

local options = {}
local teamAliases = {
	g = 'Guards',
	guard = 'Guards',
	guards = 'Guards',
	i = 'Inmates',
	inmate = 'Inmates',
	inmates = 'Inmates',
	c = 'Criminals',
	criminal = 'Criminals',
	criminals = 'Criminals'
}
local teamsService = cloneref(game:GetService('Teams'))
local viewPlayer
local followModule, followOldMove, followPlayer, followConnection

local function trim(text)
	return text and text:match('^%s*(.-)%s*$') or nil
end

local function disconnect(connection)
	if connection then
		connection:Disconnect()
	end

	return nil
end

local function getLocalHumanoid()
	local character = lplr.Character
	local humanoid = character and character:FindFirstChildOfClass('Humanoid')
	return humanoid or (entitylib.character and entitylib.character.Humanoid)
end

-- Lists

local function setListValue(list, value, enabled)
	if list and list.ListEnabled and enabled ~= (table.find(list.ListEnabled, value) ~= nil) then
		list:ChangeValue(value)
	end
end

local function clearListValues(list)
	if not list or not list.List then return 0 end

	local count = #list.List
	if count == 0 and #list.ListEnabled == 0 then return 0 end

	table.clear(list.List)
	table.clear(list.ListEnabled)
	list:ChangeValue()
	return count
end

-- Camera

local function clearViewConnection()
	viewPlayer = nil
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
	local partial

	for _, entity in entitylib.List do
		local humanoid = entity.Humanoid
		if not humanoid or (not includeDead and humanoid.Health <= 0) then continue end

		local player = entity.Player
		if not player then continue end

		local name = player.Name:lower()
		local display = player.DisplayName:lower()
		if name == lowered or display == lowered then
			return entity
		end

		if not partial and (name:sub(1, length) == lowered or display:sub(1, length) == lowered) then
			partial = entity
		end
	end

	return partial
end

local function findPlayer(prefix, allowLeft)
	local entity = findEntity(prefix, true)
	if entity then
		return entity.Player
	end

	if not allowLeft then return end

	prefix = trim(prefix)
	if not prefix or prefix == '' then return end

	local lowered = prefix:lower()
	local length = #lowered
	local partial

	for _, plr in playersService:GetPlayers() do
		local name = plr.Name:lower()
		local display = plr.DisplayName:lower()
		if name == lowered or display == lowered then
			return plr
		end

		if not partial and (name:sub(1, length) == lowered or display:sub(1, length) == lowered) then
			partial = plr
		end
	end

	return partial
end

-- Follow

local function getFollowEntity()
	if not followPlayer then return end

	return entitylib.getEntity(followPlayer)
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

		if not followPlayer or not followPlayer.Parent then
			stopFollow()
		end
	end)
end

-- Team switching

local function findTeam(name)
	name = trim(name)
	if not name or name == '' then return end

	local lowered = name:lower()
	local team = teamsService:FindFirstChild(teamAliases[lowered] or name)
	if team then
		return team
	end

	for _, child in teamsService:GetChildren() do
		if child.Name:lower():sub(1, #lowered) == lowered then
			return child
		end
	end

	return nil
end

local function handleTeam(args)
	if not options.ChangeTeam.Enabled then return end

	local targetTeam = findTeam(args and args:match('^%S+$'))
	if not targetTeam then return end

	local autoTeam = vape.Modules.AutoTeam
	if autoTeam and autoTeam.Join then
		autoTeam:Join(targetTeam.Name)
		return
	end

	notif('ChatCommand', 'AutoTeam is not available in this game.', 5, 'warning')
end

-- Reload / servers

local function handleReload()
	if not options.ReloadVape.Enabled then return end

	local success, err = pcall(function()
		vape:Save()
		shared.vapereload = true
		if shared.VapeDeveloper then
			loadstring(readfile('newvape/loader.lua'), 'loader')()
		else
			loadstring(game:HttpGet('https://raw.githubusercontent.com/Night5449791/InhalerCompiled/'..readfile('newvape/profiles/commit.txt')..'/loader.lua', true))()
		end
	end)

	if not success then
		notif('ChatCommand', 'Failed to reload : '..tostring(err), 5, 'warning')
	end
end

local function handleHop()
	if not options.ServerHop.Enabled then return end

	local serverHop = vape.Modules.ServerHop
	if serverHop then
		serverHop:Toggle()
	end
end

local function handleRejoin()
	if not options.Rejoin.Enabled then return end

	local rejoin = vape.Modules.Rejoin
	if rejoin and not rejoin.Enabled then
		rejoin:Toggle()
	end
end

-- Whitelist / target lists

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

local function clearAllTargets()
	local count = clearListValues(vape.Categories.Targets) + clearListValues(kickTargetList())
	notif('Blacklist', count > 0 and 'Cleared '..count..' target'..(count == 1 and '' or 's') or 'No targets to clear.', 5)
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

	addTarget(player.Name, not remove)
	notif('Blacklist', player.DisplayName..' has been '..(remove and 'unblacklisted.' or 'blacklisted.'), 5)
end

-- CheaterDetector bridge

local function cheaterModule()
	local module = vape.Modules and vape.Modules.CheaterDetector
	if module and module.AddCheater then
		return module
	end
end

local function handleCheater(args, remove)
	if not options.Cheater.Enabled then return end

	local module = cheaterModule()
	if not module then
		notif('ChatCommand', 'CheaterDetector is not available in this game.', 5, 'warning')
		return
	end

	if remove then
		module:RemoveCheater(args)
	else
		module:AddCheater(args)
	end
end

-- KickExploit bridge

local function kickModule()
	if vape and vape.Modules and vape.Modules.KickExploit then
		return vape.Modules.KickExploit
	end

	if vape and vape.Categories and vape.Categories.World then
		local worldModule = vape.Categories.World.Modules and vape.Categories.World.Modules.KickExploit
		if worldModule then
			return worldModule
		end
	end

	return nil
end

kickTargetList = function()
	local module = kickModule()
	if not module then return end

	return (module.Options and module.Options['Targets']) or module.List or module.Targets
end

local function setKickTarget(name, enabled)
	setListValue(kickTargetList(), name, enabled)
end

local function setKickMode(mode)
	local module = kickModule()
	if not module then return end

	local modeOption = (module.Options and module.Options['Mode']) or module.Mode
	if modeOption and modeOption.SetValue then
		modeOption:SetValue(mode)
	end
end

addTarget = function(name, enabled)
	setKickTarget(name, enabled)
	setListValue(vape.Categories.Targets, name, enabled)

	if enabled then
		whitelist.customtags[name] = {{text = 'Exploiter', color = TARGET_COLOR}}
		tempTargets[name] = true
	else
		whitelist.customtags[name] = nil
		tempTargets[name] = nil
	end
end

local kickTeams = {}
local kickTeamMembers = {}

local function addKickTeamMember(plr)
	if not plr or not next(kickTeams) or not plr.Team or not table.find(kickTeams, plr.Team) then return end
	if table.find(kickTeamMembers, plr.Name) then return end

	table.insert(kickTeamMembers, plr.Name)
	addTarget(plr.Name, true)
end

local function stopKickTeam()
	table.clear(kickTeams)

	for _, name in kickTeamMembers do
		addTarget(name, false)
	end

	table.clear(kickTeamMembers)
end

local function startKick(mode, text)
	local module = kickModule()
	if not module then return end

	setKickMode(mode)
	if not module.Enabled then
		module:Toggle()
	end

	if module.Enabled then
		notif('KickExploit', text, 5)
	else
		notif('KickExploit', 'KickExploit failed to enable.', 5, 'warning')
	end
end

local function stopKick()
	stopKickTeam()

	local module = kickModule()
	if module and module.Enabled then
		module:Toggle()
	end

	notif('KickExploit', 'Kick disabled.', 5)
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
		stopKickTeam()
		startKick('All', 'Flinging all players.')
		return
	elseif lowered == 'none' or lowered == 'off' or lowered == 'stop' then
		stopKick()
		return
	end

	local player = findPlayer(name, true)
	if not player then
		notif('KickExploit', 'No player found.', 5, 'warning')
		return
	end

	addTarget(player.Name, true)
	startKick('Individual', 'Flinging '..player.Name..'.')
end

local function handleKickTeam(args)
	if not options.Kick.Enabled then return end

	if not kickModule() then
		notif('ChatCommand', 'KickExploit is not available in this game.', 5, 'warning')
		return
	end

	local wanted = {}
	for token in (args or ''):gmatch('%S+') do
		local team = findTeam(token)
		if team and not table.find(wanted, team) then
			table.insert(wanted, team)
		end
	end

	if not next(wanted) then
		notif('KickExploit', 'No team found. (c/i/g, criminals/inmates/guards)', 5, 'warning')
		return
	end

	stopKickTeam()
	local names = {}
	for _, team in wanted do
		table.insert(kickTeams, team)
		table.insert(names, team.Name)

		for _, plr in team:GetPlayers() do
			addKickTeamMember(plr)
		end
	end

	startKick('Individual', 'Flinging '..table.concat(names, ', ')..'.')
end

local function handleKickMethod(args)
	if not options.Kick.Enabled then return end

	local module = kickModule()
	if not module then
		notif('ChatCommand', 'KickExploit is not available in this game.', 5, 'warning')
		return
	end

	local method = trim(args)
	if not method or method == '' then return end

	local option = module.Options and module.Options['Kick Mode']
	if not option or not option.SetValue then return end

	local lowered = method:lower()
	if lowered == 'normal' then
		option:SetValue('Normal')
		notif('KickExploit', 'Kick method: Normal', 5)
	elseif lowered == 'killfling' or lowered == 'kill' or lowered == 'headfling' or lowered == 'head' then
		option:SetValue('Killfling')
		notif('KickExploit', 'Kick method: Killfling', 5)
	else
		notif('KickExploit', 'Invalid method. (normal/killfling)', 5, 'warning')
	end
end

-- Movement / camera commands

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

	local player = findPlayer(args)
	if not player then
		notif('ChatCommand', 'No player found.', 5, 'warning')
		return
	end

	startFollow(player)
	if followPlayer then
		notif('ChatCommand', 'Following '..player.DisplayName..'.', 5)
	end
end

local function handleUnfollow()
	stopFollow()
	notif('ChatCommand', 'Stopped following.', 5)
end

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
	{Name = 'ChangeTeam', Tooltip = '.team <name>'},
	{Name = 'Whitelist', Tooltip = '.wl/.whitelist <plr>\n.unwl/.unwhitelist <plr>'},
	{Name = 'Blacklist', Tooltip = '.target/.blacklist <plr>\n.untarget/.unblacklist <plr>\n.untarget all/.target all clears every target'},
	{Name = 'Cheater', Tooltip = '.addskid <plr> <reason>\n.delskid <plr>'},
	{Name = 'Kick', Tooltip = '.kick <plr>\n.kick all\n.kick none\n.kickteam <c/i/g, criminals/inmates/guards>\n.kickmethod <normal/killfling>'}
}

local function handleView(args)
	if not options.PlayerView.Enabled then return end

	local player = findPlayer(args)
	local entity = player and entitylib.getEntity(player)
	if not entity then
		notif('ChatCommand', 'No player found.', 5, 'warning')
		return
	end

	clearViewConnection()
	viewPlayer = player
	gameCamera.CameraSubject = entity.Humanoid
end

local function handleHelp()
	local enabled = {}
	for _, toggle in toggles do
		if options[toggle.Name].Enabled then
			table.insert(enabled, toggle.Tooltip:gsub('\n', ' / '))
		end
	end

	table.sort(enabled)
	notif('ChatCommand', #enabled > 0 and table.concat(enabled, '\n') or 'No commands enabled.', 8)
end

local commands = {
	help = handleHelp,
	tp = handleTP,
	follow = handleFollow,
	unfollow = handleUnfollow,
	view = handleView,
	unview = restoreCamera,
	wl = function(args)
		handleWhitelist(args, false)
	end,
	whitelist = function(args)
		handleWhitelist(args, false)
	end,
	unwl = function(args)
		handleWhitelist(args, true)
	end,
	unwhitelist = function(args)
		handleWhitelist(args, true)
	end,
	target = function(args)
		handleTargets(args, false)
	end,
	blacklist = function(args)
		handleTargets(args, false)
	end,
	untarget = function(args)
		handleTargets(args, true)
	end,
	unblacklist = function(args)
		handleTargets(args, true)
	end,
	addskid = function(args)
		handleCheater(args, false)
	end,
	delskid = function(args)
		handleCheater(args, true)
	end,
	kick = handleKick,
	kickteam = handleKickTeam,
	kickmethod = handleKickMethod,
	team = handleTeam,
	hop = handleHop,
	serverhop = handleHop,
	rj = handleRejoin,
	rejoin = handleRejoin,
	reload = handleReload
}

local function onChatted(message)
	message = trim(message)
	if message:sub(1, 1) ~= '.' then return end

	local command, args = message:sub(2):match('^(%S+)%s*(.*)$')
	command = command and command:lower()
	if not command then return end

	local handler = commands[command]
	if handler then
		handler(args ~= '' and args or nil)
	end
end

ChatCommand = vape.Categories.Utility:CreateModule({
	Name = 'ChatCommand',
	Function = function(callback)
		if not callback then return end

		ChatCommand:Clean(restoreCamera)
		ChatCommand:Clean(stopFollow)
		ChatCommand:Clean(playersService.PlayerRemoving:Connect(function(plr)
			if plr == viewPlayer then
				restoreCamera()
			end

			if plr == followPlayer then
				stopFollow()
			end
		end))
		ChatCommand:Clean(entitylib.Events.EntityAdded:Connect(function(entity)
			if not entity.Player then return end

			if entity.Player == viewPlayer then
				gameCamera.CameraSubject = entity.Humanoid
			end

			addKickTeamMember(entity.Player)
		end))
		ChatCommand:Clean(stopKickTeam)
		ChatCommand:Clean(lplr.Chatted:Connect(onChatted))
	end,
	Tooltip = 'Chat commands, every command is a toggleable option\n.help lists the enabled commands'
})

for _, toggle in toggles do
	options[toggle.Name] = ChatCommand:CreateToggle({
		Name = toggle.Name,
		Tooltip = toggle.Tooltip,
		Default = true,
		Function = toggle.Function
	})
end
