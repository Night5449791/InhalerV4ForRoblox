local ChatCommand
local TARGET_COLOR = Color3.new(1, 0, 0)

local options = {}
local viewPlayer
local followModule, followOldMove, followPlayer, followConnection

-- where .tp lands the local character (the flat mask itself comes from base.lua)
local TP_OFFSET = Vector3.new(0, 2, 0)

-- nil when the text is missing or only whitespace
local function argument(text)
	text = text and text:match('^%s*(.-)%s*$') or nil
	return text ~= '' and text or nil
end

local function getLocalHumanoid()
	local character = lplr.Character
	local humanoid = character and character:FindFirstChildOfClass('Humanoid')
	return humanoid or (entitylib.character and entitylib.character.Humanoid)
end

-- lists: toggles one entry, the update event only fires on an actual change
local function setListValue(list, value, enabled)
	if list and list.ListEnabled and enabled ~= (table.find(list.ListEnabled, value) ~= nil) then
		list:ChangeValue(value)
	end
end

-- entries are either entities, which expose their player, or plain players; the
-- filter drops entries and exact matches win over wildcard and prefix matches
local function search(list, lowered, filter)
	local partial, wildcardMatch
	local pattern
	if lowered:find('*', 1, true) then
		pattern = '^'..lowered:gsub('([%^%$%(%)%%%.%[%]%+%-%?])', '%%%1'):gsub('%*', '.*')..'$'
	end

	for _, entry in list do
		if filter and not filter(entry) then continue end

		local plr = entry.Player or entry
		local name, display = plr.Name:lower(), plr.DisplayName:lower()
		if name == lowered or display == lowered then
			return entry
		end

		if pattern and not wildcardMatch and (name:match(pattern) or display:match(pattern)) then
			wildcardMatch = entry
		end

		if not partial and (name:sub(1, #lowered) == lowered or display:sub(1, #lowered) == lowered) then
			partial = entry
		end
	end

	return wildcardMatch or partial
end

-- npcs carry no player and dead characters only count when asked for
local function findEntity(prefix, includeDead)
	local text = argument(prefix)
	if not text then return end

	return search(entitylib.List, text:lower(), function(entity)
		return entity.Player and (includeDead or entity.Humanoid.Health > 0)
	end)
end

-- spawned players first, then everyone still in the server when allowLeft is set
local function findPlayer(prefix, allowLeft)
	local entity = findEntity(prefix, true)
	if entity then
		return entity.Player
	end

	local text = allowLeft and argument(prefix)
	if not text then return end

	return search(playersService:GetPlayers(), text:lower())
end

local function restoreCamera()
	viewPlayer = nil

	local humanoid = getLocalHumanoid()
	if humanoid then
		gameCamera.CameraSubject = humanoid
		gameCamera.CameraType = Enum.CameraType.Custom
	end
end

local function stopFollow()
	if followConnection then
		followConnection:Disconnect()
		followConnection = nil
	end

	if followModule and followOldMove then
		followModule.moveFunction = followOldMove
	end

	followModule, followOldMove, followPlayer = nil, nil, nil
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

		local target = followPlayer and entitylib.getEntity(followPlayer)
		local targetRoot = target and target.RootPart
		local root = entitylib.character and entitylib.character.RootPart
		if targetRoot and root then
			local direction = (targetRoot.Position - root.Position) * flatMask
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

-- hop, rj and fling only turn their module on, each gated by its own toggle
local function enableModule(option, name)
	if not options[option].Enabled then return end

	local module = vape.Modules and vape.Modules[name]
	if module and not module.Enabled then
		module:Toggle()
	end
end

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

	args = argument(args)
	if not args then return end

	local list = vape.Categories.Targets
	if args:lower() == 'all' then
		local count = #list.List + #list.ListEnabled
		table.clear(list.List)
		table.clear(list.ListEnabled)
		list:ChangeValue()
		notif('Blacklist', count > 0 and 'Cleared '..count..' target'..(count == 1 and '' or 's') or 'No targets to clear.', 5)
		return
	end

	local player = findPlayer(args, remove)
	if not player then
		notif('Blacklist', 'No player found.', 5, 'warning')
		return
	end

	-- the tag and the temporary target live exactly as long as the target entry
	local name = player.Name
	setListValue(list, name, not remove)
	whitelist.customtags[name] = not remove and {{text = 'Exploiter', color = TARGET_COLOR}} or nil
	tempTargets[name] = not remove or nil
	notif('Blacklist', player.DisplayName..' has been '..(remove and 'unblacklisted.' or 'blacklisted.'), 5)
end

local function handleCheater(args, remove)
	if not options.Cheater.Enabled then return end

	local module = vape.Modules and vape.Modules.CheaterDetector
	if not (module and module.AddCheater) then
		notif('ChatCommand', 'CheaterDetector is not available in this game.', 5, 'warning')
		return
	end

	if remove then
		module:RemoveCheater(args)
	else
		module:AddCheater(args)
	end
end

local function handleTP(args)
	if not options.PlayerTP.Enabled then return end

	local target = findEntity(args)
	local localRoot = entitylib.character and entitylib.character.RootPart
	if not target or not target.RootPart or not localRoot then
		notif('ChatCommand', 'No living player found.', 5, 'warning')
		return
	end

	localRoot.CFrame = target.RootPart.CFrame + TP_OFFSET
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

local function handleView(args)
	if not options.PlayerView.Enabled then return end

	local player = findPlayer(args)
	local entity = player and entitylib.getEntity(player)
	if not entity then
		notif('ChatCommand', 'No player found.', 5, 'warning')
		return
	end

	viewPlayer = player
	gameCamera.CameraSubject = entity.Humanoid
end

-- same invite and same rpc trick as the gui's discord button
local DISCORD_CODE = 'YSzD7f9neR'
local DISCORD_INVITE = 'https://discord.gg/'..DISCORD_CODE

-- the desktop client listens on 127.0.0.1 and falls back downwards through this
-- range; every port is asked, only the one that answers opens the invite
local function openDiscordInvite(code)
	if typeof(request) ~= 'function' then return false end

	local body = httpService:JSONEncode({
		nonce = httpService:GenerateGUID(false),
		args = {
			invite = {code = code},
			code = code
		},
		cmd = 'INVITE_BROWSER'
	})

	for port = 6453, 6467 do
		task.spawn(pcall, request, {
			Method = 'POST',
			Url = 'http://127.0.0.1:'..port..'/rpc?v=1',
			Headers = {
				['Content-Type'] = 'application/json',
				Origin = 'https://discord.com'
			},
			Body = body
		})
	end

	return true
end

local function handleCopyServer()
	if not options.CopyServer.Enabled then return end

	if not setclipboard then
		notif('ChatCommand', 'Your executor does not support clipboard.', 5, 'warning')
		return
	end

	setclipboard(DISCORD_INVITE)
	openDiscordInvite(DISCORD_CODE)
	notif('ChatCommand', 'Copied the discord invite.', 5)
end

-- one toggle per command family, then the dispatch table; the long names are
-- aliased onto the short ones right after
local toggles = {
	{Name = 'ShareCommand', Tooltip = 'Allows whitelisted users to directly access chat commands.\nPrivate members always have access.'},
	{Name = 'PlayerTP', Tooltip = '.tp <plr>'},
	{Name = 'PlayerFollow', Tooltip = '.follow <plr>\n.unfollow', Function = function(enabled)
		if not enabled then stopFollow() end
	end},
	{Name = 'PlayerView', Tooltip = '.view <plr>\n.unview', Function = function(enabled)
		if not enabled then restoreCamera() end
	end},
	{Name = 'Rejoin', Tooltip = '.rj\n.rejoin'},
	{Name = 'ServerHop', Tooltip = '.hop\n.serverhop'},
	{Name = 'Fling', Tooltip = '.fling'},
	{Name = 'ReloadVape', Tooltip = '.reload'},
	{Name = 'Whitelist', Tooltip = '.wl/.whitelist <plr>\n.unwl/.unwhitelist <plr>'},
	{Name = 'Blacklist', Tooltip = '.target/.blacklist <plr>\n.untarget/.unblacklist <plr>\n.untarget all/.target all clears every target'},
	{Name = 'Cheater', Tooltip = '.addskid <plr> <reason>\n.delskid <plr>'},
	{Name = 'CopyServer', Tooltip = '.copyserver\nCopies the discord invite and opens discord over rpc'}
}

local commands = {
	tp = handleTP,
	follow = handleFollow,
	unfollow = handleUnfollow,
	view = handleView,
	unview = restoreCamera,
	wl = function(args)
		handleWhitelist(args, false)
	end,
	unwl = function(args)
		handleWhitelist(args, true)
	end,
	target = function(args)
		handleTargets(args, false)
	end,
	untarget = function(args)
		handleTargets(args, true)
	end,
	addskid = function(args)
		handleCheater(args, false)
	end,
	delskid = function(args)
		handleCheater(args, true)
	end,
	hop = function()
		enableModule('ServerHop', 'ServerHop')
	end,
	rj = function()
		enableModule('Rejoin', 'Rejoin')
	end,
	fling = function()
		enableModule('Fling', 'FlingExploit')
	end,
	reload = handleReload,
	copyserver = handleCopyServer
}

-- long forms point at the same handler as the short ones
for alias, name in {
	whitelist = 'wl',
	unwhitelist = 'unwl',
	blacklist = 'target',
	unblacklist = 'untarget',
	serverhop = 'hop',
	rejoin = 'rj'
} do
	commands[alias] = commands[name]
end

-- the .wl command fills the Friends list, so that list is the whitelist for sharing;
-- a whitelist entry above level 0 is a private member and always keeps control
local function canShare(plr)
	if options.ShareCommand.Enabled and table.find(vape.Categories.Friends.ListEnabled, plr.Name) then
		return true
	end

	local success, level = pcall(function()
		return select(1, vape.Libraries.whitelist:get(plr))
	end)

	return success and level ~= 0
end

-- a message from someone else only runs when the sharing rules allow it
local function onChatted(message, plr)
	message = argument(message)
	if not message or message:sub(1, 1) ~= '.' then return end
	if plr and not canShare(plr) then return end

	local command, args = message:sub(2):match('^(%S+)%s*(.*)$')
	command = command and command:lower()
	if not command then return end

	local handler = commands[command]
	if handler then
		handler(args ~= '' and args or nil)
		return true
	end

	return false
end

-- one connection per player, dropped again on PlayerRemoving
local sharedConnections = {}

local function trackPlayer(plr)
	if plr == lplr or sharedConnections[plr] then return end

	sharedConnections[plr] = plr.Chatted:Connect(function(message)
		onChatted(message, plr)
	end)
end

local function untrackPlayer(plr)
	local connection = sharedConnections[plr]
	if not connection then return end

	connection:Disconnect()
	sharedConnections[plr] = nil
end

-- module registration: the toggles above are the options the handlers check
ChatCommand = vape.Categories.Utility:CreateModule({
	Name = 'ChatCommand',
	Function = function(callback)
		if not callback then return end

		ChatCommand:Clean(restoreCamera)
		ChatCommand:Clean(stopFollow)
		ChatCommand:Clean(playersService.PlayerRemoving:Connect(function(plr)
			untrackPlayer(plr)

			if plr == viewPlayer then
				restoreCamera()
			end

			if plr == followPlayer then
				stopFollow()
			end
		end))
		ChatCommand:Clean(entitylib.Events.EntityAdded:Connect(function(entity)
			if entity.Player and entity.Player == viewPlayer then
				gameCamera.CameraSubject = entity.Humanoid
			end
		end))
		-- chatted also hands over the whisper recipient, so the local path passes no player
		ChatCommand:Clean(lplr.Chatted:Connect(function(message)
			onChatted(message)
		end))

		for _, plr in playersService:GetPlayers() do
			trackPlayer(plr)
		end

		ChatCommand:Clean(playersService.PlayerAdded:Connect(trackPlayer))
		ChatCommand:Clean(function()
			for _, connection in sharedConnections do
				connection:Disconnect()
			end

			table.clear(sharedConnections)
		end)
	end,
	Tooltip = 'Chat commands, every command is a toggleable option'
})

local CommandBox
CommandBox = ChatCommand:CreateTextBox({
	Name = 'Command',
	Placeholder = 'Type a command (.tp player)',
	Tooltip = 'Runs a chat command without opening the chat. Press Enter to execute.\nThe leading dot is optional.',
	Function = function(enter)
		if not enter then return end

		-- the dot is optional, so ".tp player" and "tp player" run the same command
		local command = argument(CommandBox.Value)
		command = command and argument((command:gsub('^%.', '')))
		if not command then return end

		-- the command never reaches the chat, so the box is emptied to show it ran
		if onChatted('.'..command) then
			CommandBox:SetValue('')
		end
	end
})

for _, toggle in toggles do
	options[toggle.Name] = ChatCommand:CreateToggle({
		Name = toggle.Name,
		Tooltip = toggle.Tooltip,
		Default = true,
		Function = toggle.Function
	})
end
