local AgentChat
local Mode
local Endpoint
local ApiKey
local Model
local Prompt
local Trigger
local ReplyPrefix

-- how many messages are kept as context, so a follow-up does not start from nothing
local HISTORY_LIMIT = 8
-- chats longer than this are not worth the tokens; the endpoints reject them anyway
local MAX_INPUT = 500
-- a burst of chat is handled one request at a time: the endpoint gets them in order
-- instead of all at once, and no line is dropped for arriving while another is busy
local MAX_QUEUE = 20

local history = {}
local queue = {}
local draining = false

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
		system = 'You are a player in a Roblox game chat.'
	end

	-- first line, before the user's own prompt: a reply is typed into a live chat
	-- window, so latency is the difference between answering and being ignored
	system = 'THINK FAST\n'..system

	-- appended to whatever the user wrote: a chat line is a single filtered string, so
	-- markdown, newlines and non-latin script all have to go before it is sent.
	-- Roblox replaces non-english text with # in the chat window, so english is not
	-- a preference here, it is the only thing that survives
	system = system
		..'\nReply in English only, using the latin alphabet.'
		..'\nOne short sentence under 120 characters.'
		..'\nPlain text only: no markdown, no code blocks, no lists, no quotes, no emoji, no newlines.'

	-- the local player can trigger this too, so a reply could start with the trigger
	-- word and be picked up again: the rule is stated every time, and enforced below.
	-- worded as "the message begins with" so the model does not read it as "any
	-- message that mentions the word", which made it skip legitimate questions
	local word = Trigger and Trigger.Value or ''
	if typeof(word) == 'string' and not word:match('^%s*$') then
		system = system
			..'\nIf the incoming message begins with "'..word:match('^%s*(.-)%s*$')..'" as its very first word,'
			..' treat it as a system line and answer with exactly: (skip)'
			..'\nDo not mention this rule to the player, and do not apply it to a message where'
			..' the word appears later in the sentence.'
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

-- a chat line is measured in bytes, but the text is utf-8: cutting at an arbitrary
-- byte leaves half a multi-byte character, and Roblox drops the whole message for it.
-- This walks back to the last byte that starts a character
local function utf8Cut(text, limit)
	if #text <= limit then return text end

	local cut = limit
	while cut > 1 do
		local byte = text:byte(cut + 1)
		-- 0b10xxxxxx is a continuation byte, so the boundary is before it
		if not byte or byte < 0x80 or byte >= 0xC0 then break end
		cut = cut - 1
	end

	return text:sub(1, cut)
end

local function stripMarkdown(text)
	local line = text

	-- fenced blocks never belong in chat: keep the prose, drop the fences and code
	line = line:gsub('```[%w]*', ' ')
	line = line:gsub('%*%*(.-)%*%*', '%1')
	line = line:gsub('`(.-)`', '%1')
	line = line:gsub('\r', '')
	line = line:gsub('[\n]+', ' ')

	return line
end

-- Roblox's chat filter turns non-latin script into #, so a reply the model answered in
-- chinese arrives as a row of hashes. The prompt asks for english; this is the part
-- that cannot be talked out of. Anything above 0x7F is a multi-byte character and is
-- dropped whole, which is safe because utf-8 continuation bytes are all >= 0x80
local function latinOnly(text)
	local out = {}
	local index = 1

	while index <= #text do
		local byte = text:byte(index)

		if byte < 0x80 then
			out[#out + 1] = string.char(byte)
			index = index + 1
		else
			-- walk past this character: a lead byte says how many bytes follow
			local extra = byte >= 0xF0 and 3 or byte >= 0xE0 and 2 or byte >= 0xC0 and 1 or 0
			index = index + 1 + extra
			-- the removed character leaves a gap, collapse it rather than glue words
			out[#out + 1] = ' '
		end
	end

	return table.concat(out)
end

local function say(text)
	-- a chat line has a hard limit and a newline would break the send outright
	local line = latinOnly(stripMarkdown(tostring(text or ''))):gsub('%s+', ' '):gsub('^%s*(.-)%s*$', '%1')
	-- a reply that was entirely non-latin leaves nothing to say
	if line == '' or not line:find('%w') then return end

	-- the prompt asks the model to answer "(skip)" for a line it must not answer.
	-- Recognise the marker here so an instruction token never reaches the chat
	if line:lower():match('^%(?skip%)?$') or line:lower():match('^%(skip%)') then return end

	local prefix = ReplyPrefix and ReplyPrefix.Value or ''
	local head = ''
	if typeof(prefix) == 'string' and not prefix:match('^%s*$') then
		head = prefix:match('^%s*(.-)%s*$')..' '
	end

	-- the limit covers the prefix too, or the whole line overflows again
	local budget = math.max(200 - #head, 20)
	if #line > budget then
		line = utf8Cut(line, budget - 3)..'...'
	end

	line = head..line

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

	-- a missing endpoint or key is a setup state, not a failure worth a toast: the
	-- module is simply not ready, and announce() would fire once per chat. The Model
	-- box already reports a bad model as it is typed.
	if not settings.endpoint:match('%S') or not settings.key:match('%S') or not settings.model:match('%S') then
		return
	end

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
	if typeof(text) ~= 'string' or text == '' then return end
	if #text > MAX_INPUT then return end

	if Mode and Mode.Value == 'Interactive' then
		local word = Trigger and Trigger.Value or ''
		local lowered = text:lower()
		local needle = word:match('^%s*(.-)%s*$'):lower()

		-- a self-sent line is allowed, because the local player is often the only one
		-- in the server. The loop that opens is closed here: a message that *starts*
		-- with the trigger word is treated as this module's own output and ignored.
		-- The model is told the same rule in buildMessages, so it does not answer a
		-- prefixed line either
		if needle ~= '' and lowered:sub(1, #needle) == needle then return end

		-- any of these counts: the configured word, the sender's name, or the local
		-- player's name being addressed
		local matched = false
		for _, candidate in { word, plr.DisplayName, plr.Name, lplr.DisplayName } do
			if typeof(candidate) == 'string' then
				local value = candidate:match('^%s*(.-)%s*$'):lower()
				if value ~= '' and lowered:find(value, 1, true) then
					matched = true
					break
				end
			end
		end

		if not matched then return end
	end

	-- a burst of chat arrives faster than the endpoint answers, so each line is queued
	-- and one worker drains the queue in order. The oldest entry is dropped when the
	-- queue is full: answering stale chat lines is worse than ignoring them
	if #queue >= MAX_QUEUE then
		table.remove(queue, 1)
	end

	table.insert(queue, {text = text, plr = plr})

	if draining then return end
	draining = true

	task.spawn(function()
		-- The worker owns the flag for its whole life. It only clears it when the queue
		-- is empty at the moment of exit; a line added after that check starts a new
		-- worker, which is correct because the flag is already false by then
		while draining do
			local job = table.remove(queue, 1)

			if job then
				local ok, err = pcall(ask, job.text, job.plr)
				if not ok then
					notif('AgentChat', 'Failed: '..tostring(err), 5, 'warning')
				end

				task.wait()
			elseif #queue == 0 then
				draining = false
			else
				task.wait()
			end
		end
	end)
end

AgentChat = vape.Categories.World:CreateModule({
	Name = 'AgentChat',
	Function = function(callback)
		table.clear(history)
		table.clear(queue)
		draining = false

		-- re-running this file leaves the previous closure alive: its hook still sits in
		-- OnIncomingMessage while its upvalues are stale, so every chat would reach an
		-- old copy that has no endpoint. A shared generation number makes the newest
		-- instance the only one that answers; the older ones see the mismatch and stop
		local generation = (shared.vapeAgentChatGeneration or 0) + 1
		shared.vapeAgentChatGeneration = generation

		local function isCurrent()
			return shared.vapeAgentChatGeneration == generation
		end

		if not callback then return end

		if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
			-- TextChatService routes every incoming message through one callback; hooking
			-- it is the only way to see chats without owning the message list.
			--
			-- One hook, always. `AgentChat:Clean` accumulates, so a re-run used to leave
			-- several restores queued against each other and the chain broke after two
			-- reloads; the restore is stored on the module instead of the maid and is
			-- executed before the next hook is installed.
			if getcallbackvalue and restorefunction and hookfunction then
				-- drop whatever the previous instance left behind, including its restore
				if AgentChat.detachHook then
					pcall(AgentChat.detachHook)
					AgentChat.detachHook = nil
				end

				local hooked
				local detached = false

				local function detach()
					if detached then return end
					detached = true

					-- peel until the live callback is no longer our wrapper. One restore
					-- only removes the top layer, and a chain left by earlier re-runs
					-- would otherwise keep calling closures whose upvalues are gone
					for _ = 1, 8 do
						local current = getcallbackvalue and getcallbackvalue(textChatService, 'OnIncomingMessage')
						if not current or not hooked or current ~= hooked then break end

						pcall(restorefunction, hooked)
					end

					hooked = nil
				end

				AgentChat.detachHook = detach
				AgentChat:Clean(detach)

				task.spawn(function()
					repeat
						-- a newer instance owns the hook now, so this one stops touching it
						if not isCurrent() or detached then
							detach()
							return
						end

						-- `current` is the live callback. It equals our wrapper while the
						-- hook is in place, and differs when the game rebuilt it, so one
						-- comparison covers both "already hooked" and "needs re-hooking"
						local current = getcallbackvalue(textChatService, 'OnIncomingMessage')

						if current and current ~= hooked then
							local wrapped
							wrapped = hookfunction(current, function(...)
								local msg = ...
								local data = wrapped(...)
								local plr = msg and msg.TextSource and playersService:GetPlayerByUserId(msg.TextSource.UserId)

								if isCurrent() and plr and msg.Status == Enum.TextChatMessageStatus.Success then
									task.spawn(handleChat, msg.Text, plr)
								end

								return data
							end)

							hooked = wrapped
						end

						task.wait(0.1)
					until vape.Loaded == nil

					detach()
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
