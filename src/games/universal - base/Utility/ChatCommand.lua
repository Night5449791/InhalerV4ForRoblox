local ChatCommand

local options = {}
local sharedConnections = {}

local viewPlayer
local followModule, followOldMove, followPlayer, followConnection
local danceTrack

local flatMask = Vector3.new(1, 0, 1)
local tpOffset = Vector3.new(0, 2, 0)
local danceIds = {
	R6 = {'27789359', '30196114', '248263260', '45834924', '33796059', '28488254', '52155728'},
	R15 = {'3333432454', '4555808220', '4049037604', '4555782893', '10214311282', '10714010337', '10713981723', '10714372526', '10714076981', '10714392151', '11444443576'}
}

local function argument(text)
	text = text and text:match('^%s*(.-)%s*$') or nil
	return text ~= '' and text or nil
end

local function getLocalHumanoid()
	local character = lplr.Character
	local humanoid = character and character:FindFirstChildOfClass('Humanoid')
	return humanoid or (entitylib.character and entitylib.character.Humanoid)
end

local function setListValue(list, value, enabled)
	if list and list.ListEnabled and enabled ~= (table.find(list.ListEnabled, value) ~= nil) then
		list:ChangeValue(value)
	end
end

local function clearListValues(list)
	if not list or not list.List then return 0 end

	local count = #list.List + #list.ListEnabled
	if count == 0 then return 0 end

	table.clear(list.List)
	table.clear(list.ListEnabled)
	list:ChangeValue()
	return count
end

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

	return search(entitylib.List, text:lower(), function(entity)
		return entity.Player and (includeDead or entity.Humanoid.Health > 0)
	end)
end

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

local function stopDance()
	if danceTrack then
		danceTrack:Stop()
		danceTrack:Destroy()
		danceTrack = nil
	end
end

local function enableModule(name)
	if not options[name].Enabled then return end

	local module = vape.Modules and vape.Modules[name]
	if module and not module.Enabled then
		module:Toggle()
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

	localRoot.CFrame = target.RootPart.CFrame + tpOffset
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

local function changeWhitelist(args, remove)
	if not options.Whitelist.Enabled then return end

	local player = findPlayer(args, remove)
	if not player then
		notif('Whitelist', 'No player found.', 5, 'warning')
		return
	end

	setListValue(vape.Categories.Friends, player.Name, not remove)
	notif('Whitelist', player.DisplayName..' has been '..(remove and 'unwhitelisted.' or 'whitelisted.'), 5)
end

local function whitelistAdd(args)
	return changeWhitelist(args, false)
end

local function whitelistRemove(args)
	return changeWhitelist(args, true)
end

local function changeTargets(args, remove)
	if not options.Blacklist.Enabled then return end

	args = argument(args)
	if not args then return end

	local list = vape.Categories.Targets
	if args:lower() == 'all' then
		local count = clearListValues(list)
		notif('Blacklist', count > 0 and 'Cleared '..count..' target'..(count == 1 and '' or 's') or 'No targets to clear.', 5)
		return
	end

	local player = findPlayer(args, remove)
	if not player then
		notif('Blacklist', 'No player found.', 5, 'warning')
		return
	end

	setListValue(list, player.Name, not remove)
	notif('Blacklist', player.DisplayName..' has been '..(remove and 'unblacklisted.' or 'blacklisted.'), 5)
end

local function targetAdd(args)
	return changeTargets(args, false)
end

local function targetRemove(args)
	return changeTargets(args, true)
end

local function hopServer()
	enableModule('ServerHop')
end

local function rejoinServer()
	enableModule('Rejoin')
end

local function reloadVape()
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

local function startDance()
	if not options.Dance.Enabled then return end

	local humanoid = getLocalHumanoid()
	if not humanoid then
		notif('ChatCommand', 'You have no character.', 5, 'warning')
		return
	end

	stopDance()

	local dances = humanoid.RigType == Enum.HumanoidRigType.R15 and danceIds.R15 or danceIds.R6
	local animation = Instance.new('Animation')
	animation.AnimationId = 'rbxassetid://'..dances[math.random(1, #dances)]
	danceTrack = humanoid:LoadAnimation(animation)
	danceTrack.Looped = true
	danceTrack:Play()
end

local commands = {
	tp = handleTP,
	follow = handleFollow,
	unfollow = handleUnfollow,
	view = handleView,
	unview = restoreCamera,

	wl = whitelistAdd,
	whitelist = whitelistAdd,
	unwl = whitelistRemove,
	unwhitelist = whitelistRemove,

	target = targetAdd,
	blacklist = targetAdd,
	untarget = targetRemove,
	unblacklist = targetRemove,

	hop = hopServer,
	serverhop = hopServer,
	rj = rejoinServer,
	rejoin = rejoinServer,

	reload = reloadVape,
	dance = startDance,
	undance = stopDance
}

local toggles = {
	{Name = 'ShareCommands', Default = false, Tooltip = 'Allows whitelisted users to directly access chat commands.'},
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
	{Name = 'Dance', Tooltip = '.dance\n.dundance'}
}

local function canShare(plr)
	local success, level = pcall(whitelist.get, whitelist, plr)
	if success and type(level) == 'number' and level > 0 then
		return false
	end

	return options.ShareCommands.Enabled and table.find(vape.Categories.Friends.ListEnabled, plr.Name) ~= nil
end

local onChatted

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

onChatted = function(message, plr)
	message = argument(message)
	if not message then return end

	if message:sub(1, 1) ~= '.' then return false end
	if plr and not canShare(plr) then return false end

	local command, args = message:sub(2):match('^(%S+)%s*(.*)$')
	command = command and command:lower()
	if not command then return end

	local handler = commands[command]
	if not handler then return false end

	handler(args ~= '' and args or nil)
	return true
end

ChatCommand = vape.Categories.Utility:CreateModule({
	Name = 'ChatCommand',
	Function = function(callback)
		if not callback then return end

		ChatCommand:Clean(restoreCamera)
		ChatCommand:Clean(stopFollow)
		ChatCommand:Clean(stopDance)
		ChatCommand:Clean(lplr.CharacterAdded:Connect(stopDance))
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
		ChatCommand:Clean(lplr.Chatted:Connect(onChatted))
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

		local command = argument(CommandBox.Value)
		command = command and argument((command:gsub('^[%.;]', '')))
		if not command then return end

		if onChatted('.'..command) then
			CommandBox:SetValue('')
		end
	end
})

for _, toggle in toggles do
	options[toggle.Name] = ChatCommand:CreateToggle({
		Name = toggle.Name,
		Tooltip = toggle.Tooltip,
		Default = toggle.Default ~= false,
		Function = toggle.Function
	})
end
