local ChatCommand

local options = {}
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

local function addTarget(name, enabled)
	setListValue(vape.Categories.Targets, name, enabled)
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

-- Reload / servers

local function handleReload()
	if not options.ReloadVape.Enabled then return end

	local success, err = pcall(function()
		vape:Save()
		shared.vapereload = true
		if shared.VapeDeveloper then
			loadstring(readfile('newvape/loader.lua'), 'loader')()
		else
			loadstring(game:HttpGet('https://raw.githubusercontent.com/Night5449791/VapeCompiled/'..readfile('newvape/profiles/commit.txt')..'/loader.lua', true))()
		end
	end)

	if not success then
		notif('ChatCommand', 'Failed to reload : '..tostring(err), 5, 'warning')
	end
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
	local count = clearListValues(vape.Categories.Targets)
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

local danceTrack

local function stopDance()
	if danceTrack then
		pcall(function()
			danceTrack:Stop()
			danceTrack:Destroy()
		end)
		danceTrack = nil
	end
end

local function handleDance()
	if not options.Dance.Enabled then return end

	stopDance()

	local humanoid = getLocalHumanoid()
	if not humanoid or not humanoid.Parent then
		notif('ChatCommand', 'No character found.', 5, 'warning')
		return
	end

	local r15 = humanoid.RigType == Enum.HumanoidRigType.R15
	local dances = r15
		and {'3333432454', '4555808220', '4049037604', '4555782893', '10214311282', '10714010337', '10713981723', '10714372526', '10714076981', '10714392151', '11444443576'}
		or {'27789359', '30196114', '248263260', '45834924', '33796059', '28488254', '52155728'}

	local animation = Instance.new('Animation')
	animation.AnimationId = 'rbxassetid://'..dances[math.random(1, #dances)]
	danceTrack = humanoid:LoadAnimation(animation)
	danceTrack.Looped = true
	danceTrack:Play()
	notif('ChatCommand', 'Dancing.', 5)
end

local function handleStopDance()
	if not options.Dance.Enabled then return end

	stopDance()
	notif('ChatCommand', 'Stopped dancing.', 5)
end

local function getTargetStrafe()
	local module = vape.Modules and vape.Modules.TargetStrafe
	if module then return module end

	local blatant = vape.Categories and vape.Categories.Blatant
	return blatant and blatant.Modules and blatant.Modules.TargetStrafe
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
	{Name = 'Whitelist', Tooltip = '.wl/.whitelist <plr>\n.unwl/.unwhitelist <plr>'},
	{Name = 'Blacklist', Tooltip = '.target/.blacklist <plr>\n.untarget/.unblacklist <plr>\n.untarget all/.target all clears every target'},
	{Name = 'Dance', Tooltip = '.dance\n.dundance', Function = function(enabled)
		if not enabled then
			stopDance()
		end
	end},
	{Name = 'TargetStrafe', Tooltip = '.tstrafe <username>\n.tstrafe off / .untstrafe'}
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

local function handleDebugNetworkOwner()
	local ShowNetworkOwner = vape.Modules.ShowNetworkOwner
	if ShowNetworkOwner and ShowNetworkOwner.Enabled then
		ShowNetworkOwner.Enabled = false
	else
		ShowNetworkOwner.Enabled = true
	end
end

local commands = {
	help = handleHelp,
	tp = handleTP,
	follow = handleFollow,
	unfollow = handleUnfollow,
	dance = handleDance,
	dundance = handleStopDance,
	nodance = handleStopDance,
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
	hop = handleHop,
	serverhop = handleHop,
	rj = handleRejoin,
	rejoin = handleRejoin,
	reload = handleReload,
	debugnet = handleDebugNetworkOwner,
	debugnetworkowner = handleDebugNetworkOwner,
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
		ChatCommand:Clean(stopDance)
		ChatCommand:Clean(playersService.PlayerRemoving:Connect(function(plr)
			if plr == viewPlayer then
				restoreCamera()
			end

			if plr == followPlayer then
				stopFollow()
			end
		end))
		ChatCommand:Clean(entitylib.Events.EntityAdded:Connect(function(entity)
			if entity.Player == viewPlayer then
				gameCamera.CameraSubject = entity.Humanoid
			end
		end))
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
