local ChatCommand

local options = {}
local viewPlayer
local followModule, followOldMove, followPlayer, followConnection
local danceTrack

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

-- Lists

local function setListValue(list, value, enabled)
	if list and list.ListEnabled and enabled ~= (table.find(list.ListEnabled, value) ~= nil) then
		list:ChangeValue(value)
	end
end

-- returns how many entries were dropped
local function clearListValues(list)
	if not list or not list.List then return 0 end

	local count = #list.List + #list.ListEnabled
	if count == 0 then return 0 end

	table.clear(list.List)
	table.clear(list.ListEnabled)
	list:ChangeValue()
	return count
end

-- Player lookup

-- entries are either entities, which expose their player, or plain players.
-- filter drops entries, an exact match wins over the first prefix match
local function search(list, lowered, filter)
	local partial

	for _, entry in list do
		if filter and not filter(entry) then continue end

		local plr = entry.Player or entry
		local name, display = plr.Name:lower(), plr.DisplayName:lower()
		if name == lowered or display == lowered then
			return entry
		end

		if not partial and (name:sub(1, #lowered) == lowered or display:sub(1, #lowered) == lowered) then
			partial = entry
		end
	end

	return partial
end

local function findEntity(prefix, includeDead)
	local text = argument(prefix)
	if not text then return end

	-- npcs carry no player and dead characters only count when asked for
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

-- Camera

local function restoreCamera()
	viewPlayer = nil

	local humanoid = getLocalHumanoid()
	if humanoid then
		gameCamera.CameraSubject = humanoid
		gameCamera.CameraType = Enum.CameraType.Custom
	end
end

-- Follow

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

local function handleBroadcast()
	if not options.Broadcast.Enabled then return end

	local module = vape.Modules.UniversalBroadcast
	if not module then
		notif('ChatCommand', 'UniversalBroadcast is not available in this game.', 5, 'warning')
		return
	end

	module:Toggle()
	local message = 'Automatically broadcasting in console. Press F9 or chat /console to see result'
	task.delay(0.1, function()
		if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
			textChatService.ChatInputBarConfiguration.TargetTextChannel:SendAsync(message)
		else
			replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(message, 'All')
		end
	end)
end

local function handleUndance()
	if danceTrack then
		danceTrack:Stop()
		danceTrack:Destroy()
		danceTrack = nil
	end
end

local function handleDance()
	if not options.Dance.Enabled then return end

	local humanoid = getLocalHumanoid()
	if not humanoid then
		notif('ChatCommand', 'You have no character.', 5, 'warning')
		return
	end

	handleUndance()
	local dances = {'27789359', '30196114', '248263260', '45834924', '33796059', '28488254', '52155728'}
	if humanoid.RigType == Enum.HumanoidRigType.R15 then
		dances = {'3333432454', '4555808220', '4049037604', '4555782893', '10214311282', '10714010337', '10713981723', '10714372526', '10714076981', '10714392151', '11444443576'}
	end

	local animation = Instance.new('Animation')
	animation.AnimationId = 'rbxassetid://'..dances[math.random(1, #dances)]
	danceTrack = humanoid:LoadAnimation(animation)
	danceTrack.Looped = true
	danceTrack:Play()
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

	args = argument(args)
	if not args then return end

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

local toggles = {
	{Name = 'PlayerTP', Tooltip = '.tp <plr>'},
	{Name = 'PlayerFollow', Tooltip = '.follow <plr>\n.unfollow', Function = function(enabled)
		if not enabled then stopFollow() end
	end},
	{Name = 'PlayerView', Tooltip = '.view <plr>\n.unview', Function = function(enabled)
		if not enabled then restoreCamera() end
	end},
	{Name = 'Rejoin', Tooltip = '.rj\n.rejoin'},
	{Name = 'ServerHop', Tooltip = '.hop\n.serverhop'},
	{Name = 'ReloadVape', Tooltip = '.reload'},
	{Name = 'Whitelist', Tooltip = '.wl/.whitelist <plr>\n.unwl/.unwhitelist <plr>'},
	{Name = 'Blacklist', Tooltip = '.target/.blacklist <plr>\n.untarget/.unblacklist <plr>\n.untarget all/.target all clears every target'},
	{Name = 'Broadcast', Tooltip = '.broadcast'},
	{Name = 'Dance', Tooltip = '.dance\n.dundance'}
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
	hop = handleHop,
	rj = handleRejoin,
	reload = handleReload,
	broadcast = handleBroadcast,
	dance = handleDance,
	undance = handleUndance
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

local function onChatted(message)
	message = argument(message)
	if not message or message:sub(1, 1) ~= '.' then return end

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

ChatCommand = vape.Categories.Utility:CreateModule({
	Name = 'ChatCommand',
	Function = function(callback)
		if not callback then return end

		ChatCommand:Clean(restoreCamera)
		ChatCommand:Clean(stopFollow)
		ChatCommand:Clean(handleUndance)
		ChatCommand:Clean(lplr.CharacterAdded:Connect(handleUndance))
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
	Tooltip = 'Chat commands, every command is a toggleable option'
})

for _, toggle in toggles do
	options[toggle.Name] = ChatCommand:CreateToggle({
		Name = toggle.Name,
		Tooltip = toggle.Tooltip,
		Default = true,
		Function = toggle.Function
	})
end

local CommandBox
CommandBox = ChatCommand:CreateTextBox({
	Name = 'Command',
	Placeholder = 'Type a command (.tp player)',
	Tooltip = 'Runs a chat command without opening the chat. Press Enter to execute.',
	Function = function(enter)
		if enter and CommandBox and CommandBox.Value ~= '' then
			-- the command never reaches the chat, so the box is emptied to show it ran
			if onChatted(CommandBox.Value) then
				CommandBox:SetValue('')
			end
		end
	end
})
