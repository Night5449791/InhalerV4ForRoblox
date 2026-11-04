local AgentChat
local Mode
local Endpoint
local ApiKey
local Model
local Prompt
local Trigger
local Cooldown
local ReplyPrefix

-- how many messages are kept as context, so a follow-up does not start from nothing
local HISTORY_LIMIT = 8
-- chats longer than this are not worth the tokens; the endpoints reject them anyway
local MAX_INPUT = 500
-- a chat loop is the fastest way to get rate limited, so every reply re-arms this
local DEFAULT_COOLDOWN = 3

local history = {}
local pending = false
local readyAt = 0

-- the language model client is loaded by the universal base. A build that shipped
-- without it must say so once instead of failing on every chat
local function getLLM()
	local llm = vape.Libraries and vape.Libraries.llm
	if not llm then
		notif('AgentChat', 'The llm library is missing from this build.', 5, 'warning')
	end

	return llm
end

local function buildMessages(text, plr)
	local messages = {}

	local system = Prompt and Prompt.Value or ''
	if typeof(system) ~= 'string' or system:match('^%s*$') then
		system = 'You are a player in a Roblox game chat. Reply with one short sentence, under 200 characters, no markdown.'
	end

	-- the speaker is named so a multi-player conversation does not blur together
	table.insert(messages, {role = 'system', content = system})
	table.insert(messages, {role = 'system', content = 'You are replying to '..plr.DisplayName..' ('..plr.Name..').'})

	for _, entry in history do
		table.insert(messages, entry)
	end

	table.insert(messages, {role = 'user', content = text})
	return messages
end

local function remember(role, content)
	table.insert(history, {role = role, content = content})

	while #history > HISTORY_LIMIT do
		table.remove(history, 1)
	end
end

local function say(text)
	-- a chat line has a hard limit and a newline would break the send outright
	local line = tostring(text or ''):gsub('[\r\n]+', ' '):gsub('^%s*(.-)%s*$', '%1')
	if line == '' then return end
	if #line > 200 then line = line:sub(1, 197)..'...' end

	local prefix = ReplyPrefix and ReplyPrefix.Value or ''
	if typeof(prefix) == 'string' and not prefix:match('^%s*$') then
		line = prefix:match('^%s*(.-)%s*$')..' '..line
	end

	if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		local channel = textChatService.ChatInputBarConfiguration.TargetTextChannel
		if channel then
			pcall(function()
				channel:SendAsync(line)
			end)
		end
	else
		local events = replicatedStorage:FindFirstChild('DefaultChatSystemChatEvents')
		if events and events:FindFirstChild('SayMessageRequest') then
			events.SayMessageRequest:FireServer(line, 'All')
		end
	end
end

-- everything the library needs, read once so a missing field is reported the same way
local function config()
	return {
		endpoint = Endpoint and Endpoint.Value or '',
		key = ApiKey and ApiKey.Value or '',
		model = Model and Model.Value or ''
	}
end

local function ask(text, plr)
	local llm = getLLM()
	if not llm then return end

	local settings = config()

	local reply, err = llm.chat({
		endpoint = settings.endpoint,
		key = settings.key,
		model = settings.model,
		messages = buildMessages(text, plr),
		maxTokens = 120,
		temperature = 0.8
	})

	if not reply then
		-- a rejected model is a configuration mistake, not a transient failure: the
		-- library stops before spending a completion, and the module says why
		notif('AgentChat', 'LLM error: '..tostring(err), 8, 'warning')
		return
	end

	remember('user', text)
	remember('assistant', reply)
	say(reply)
end

local function handleChat(text, plr)
	if plr == lplr then return end
	if pending or os.clock() < readyAt then return end
	if typeof(text) ~= 'string' or text == '' then return end
	if #text > MAX_INPUT then return end

	if Mode and Mode.Value == 'Interactive' then
		local word = Trigger and Trigger.Value or ''
		local lowered = text:lower()

		-- any of these counts: the configured word, the sender's name, or the local
		-- player's name being addressed
		local matched = false
		for _, candidate in { word, plr.DisplayName, plr.Name, lplr.DisplayName } do
			if typeof(candidate) == 'string' then
				local needle = candidate:match('^%s*(.-)%s*$'):lower()
				if needle ~= '' and lowered:find(needle, 1, true) then
					matched = true
					break
				end
			end
		end

		if not matched then return end
	end

	pending = true
	task.spawn(function()
		local ok, err = pcall(ask, text, plr)
		if not ok then
			notif('AgentChat', 'Failed: '..tostring(err), 5, 'warning')
		end

		readyAt = os.clock() + (Cooldown and Cooldown.Value or DEFAULT_COOLDOWN)
		pending = false
	end)
end

AgentChat = vape.Categories.World:CreateModule({
	Name = 'AgentChat',
	Function = function(callback)
		table.clear(history)
		pending = false
		readyAt = 0

		if not callback then return end

		if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
			-- TextChatService routes every incoming message through one callback; hooking
			-- it is the only way to see chats without owning the message list
			if getcallbackvalue and restorefunction and hookfunction then
				local old
				task.spawn(function()
					AgentChat:Clean(function()
						if old then
							restorefunction(old)
							old = nil
						end
					end)

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
								local plr = msg and msg.TextSource and playersService:GetPlayerByUserId(msg.TextSource.UserId)

								if plr and msg.Status == Enum.TextChatMessageStatus.Success then
									task.spawn(handleChat, msg.Text, plr)
								end

								return data
							end)

							old = current
						end

						task.wait(0.1)
					until vape.Loaded == nil
				end)
			end
		else
			-- the legacy path raises one of two events depending on the filter setting,
			-- so both are watched and whichever fires first wins
			local events = replicatedStorage:FindFirstChild('DefaultChatSystemChatEvents')
			if events then
				for _, name in { 'OnNewMessage', 'OnMessageDoneFiltering' } do
					local remote = events:FindFirstChild(name)
					if remote then
						AgentChat:Clean(remote.OnClientEvent:Connect(function(data)
							if typeof(data) ~= 'table' or typeof(data.Message) ~= 'string' then return end

							local plr = playersService:GetPlayerByUserId(tonumber(data.SpeakerUserId) or 0)
							if plr then
								task.spawn(handleChat, data.Message, plr)
							end
						end))
					end
				end
			end
		end
	end,
	Tooltip = 'Answers chat with a language model'
})

Mode = AgentChat:CreateDropdown({
	Name = 'Mode',
	List = {'Automatically', 'Interactive'},
	Tooltip = 'Automatically - every chat is sent to the model\nInteractive - only chats containing the trigger word or a player name',
	Function = function(val)
		-- the trigger only means anything in interactive mode
		if Trigger then
			Trigger.Object.Visible = val == 'Interactive'
		end
	end
})

Endpoint = AgentChat:CreateTextBox({
	Name = 'Endpoint',
	Placeholder = 'https://api.openai.com/v1',
	Tooltip = 'Base url of an openai-compatible api.\n/chat/completions and /models are appended when missing.',
	Function = function()
		if AgentChat.Enabled then
			AgentChat:Toggle()
			AgentChat:Toggle()
		end
	end
})

ApiKey = AgentChat:CreateTextBox({
	Name = 'API key',
	Placeholder = 'sk-...',
	Tooltip = 'Sent as an Authorization: Bearer header.\nStored in the profile in clear text.',
	Function = function()
		if AgentChat.Enabled then
			AgentChat:Toggle()
			AgentChat:Toggle()
		end
	end
})

Model = AgentChat:CreateTextBox({
	Name = 'Model',
	Placeholder = 'gpt-4o-mini',
	Tooltip = 'Model id offered by the endpoint.\nA name the endpoint does not list is rejected before any token is spent.',
	Function = function()
		-- a model that was just typed is checked right away, so a typo costs a /models
		-- lookup instead of a failed reply in the middle of a conversation
		local llm = vape.Libraries and vape.Libraries.llm
		local id = Model and Model.Value
		if not (llm and typeof(id) == 'string') then return end
		if id:match('^%s*$') then return end

		task.spawn(function()
			local known, err = llm.hasModel(config(), id)
			if known == false then
				notif('AgentChat', 'Model rejected: '..tostring(err), 8, 'warning')
			end
		end)
	end
})

Prompt = AgentChat:CreateTextBox({
	Name = 'Prompt',
	Placeholder = 'You are a player in a Roblox game chat...',
	Tooltip = 'System prompt sent with every request.\nLeave empty for the default.',
	Function = function()
		if AgentChat.Enabled then
			AgentChat:Toggle()
			AgentChat:Toggle()
		end
	end
})

Trigger = AgentChat:CreateTextBox({
	Name = 'Trigger',
	Placeholder = 'inhaler',
	Tooltip = 'Interactive mode only: a chat must contain this word, your name or the sender\'s name.',
	Visible = false,
	Function = function()
		if AgentChat.Enabled then
			AgentChat:Toggle()
			AgentChat:Toggle()
		end
	end
})

Cooldown = AgentChat:CreateSlider({
	Name = 'Cooldown',
	Min = 0,
	Max = 30,
	Default = DEFAULT_COOLDOWN,
	Suffix = function(val)
		return val == 1 and 'second' or 'seconds'
	end,
	Tooltip = 'Seconds to wait after a reply before another request is made.'
})

ReplyPrefix = AgentChat:CreateTextBox({
	Name = 'Reply prefix',
	Placeholder = 'optional',
	Tooltip = 'Placed in front of every sent reply, e.g. the model\'s name.',
	Function = function()
		if AgentChat.Enabled then
			AgentChat:Toggle()
			AgentChat:Toggle()
		end
	end
})
