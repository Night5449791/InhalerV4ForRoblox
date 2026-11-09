local AutoToxic
local KXUser
local KXSkip
local FakeKXUser
local FakeText
local Presets = {}
local cloned = {}
local random = Random.new()
local fakeMessages = {
	['Inhaler V4'] = 'I use the script Inhaler V4',
	['KX ADMIN'] = 'I use the script KX-ADMIN'
}

-- One place that sends a bare chat line. `sendMessage` below cannot use it: it also
-- appends a preset, which is a different call and only exists on the new chat.
local function say(message)
	if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		textChatService.ChatInputBarConfiguration.TargetTextChannel:SendAsync(message)
	else
		replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(message, 'All')
	end
end

-- `.kxusers` prints who else in the server is running a whitelisted injector, which is
-- the only way to learn that without asking. It is a query, not a greeting, so once per
-- module start is enough.
--
-- Five seconds after the module comes on: the game is still loading the chat at that
-- point, and a command sent before the channel exists never reaches it, which looks the
-- same as one nobody answered.
local function sayKXUsers()
	task.wait(5)

	if not KXUser.Enabled then return end

	-- one pass over the server answers "is anyone here" for every listed id at once,
	-- instead of a lookup per id
	if #KXSkip.ListEnabled > 0 then
		for _, player in playersService:GetPlayers() do
			if table.find(KXSkip.ListEnabled, tostring(player.UserId)) then return end
		end
	end

	pcall(say, '.kxusers')
end

-- Anyone else asking `.kxusers` gets told a KX user is here, in the wording picked in
-- Text. Our own line comes back through the same path and answering it would talk to
-- itself, so it is skipped by name.
local function fakeKXUser(name, message)
	if name == lplr.DisplayName or name == lplr.Name then return end
	if not message:find('.kxusers', 1, true) then return end

	local text = fakeMessages[FakeText.Value]
	if not text then return end

	pcall(say, text)
end

local function sendMessage(obj)
	local name = (obj or ''):match('^%s*(.-)%s*$')
	if name == '' or name == lplr.DisplayName or name == lplr.Name then return end

	if not next(cloned) then
		cloned = table.clone(lines)
	end

	local message = table.remove(cloned, random:NextInteger(1, #cloned)):gsub('<obj>', name)

	if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		local channel = textChatService.ChatInputBarConfiguration.TargetTextChannel

		if textChatService:CanUserChatAsync(lplr.UserId) then
			channel:SendAsync(message)
			channel:SendPresetAsync(Presets['So close'])
		else
			channel:SendPresetAsync(Presets['So close'])
		end
	else
		replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(message, 'All')
	end
end

local lines = {
	'prison life moment | kicked <obj>',
	'do you also want an antifling? | kicked <obj>',
	'i wonder why you got kicked | kicked <obj>',
}

-- Every chat line the client sees, sender included. `MessageReceived` is a plain signal,
-- so nothing is hooked for it; the old chat has no such signal and uses its own event.
local function connectFake()
	if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		FakeKXUser:Clean(textChatService.MessageReceived:Connect(function(chatMessage)
			-- an invalid-permissions status means the line never went out
			if chatMessage.Status == Enum.TextChatMessageStatus.InvalidTextChannelPermissions then return end

			local source = chatMessage.TextSource
			if not source then return end

			local player = playersService:GetPlayerByUserId(source.UserId)
			if not player then return end

			-- the filter can rewrite a line, and the rewrite is what everyone else reads
			local message = chatMessage.Text

			pcall(function()
				if chatMessage.WasRewritten == true then
					message = '(rephrased) '..chatMessage.RewrittenText
				end
			end)

			fakeKXUser(player.Name, message)
		end))

		return
	end

	local events = replicatedStorage:FindFirstChild('DefaultChatSystemChatEvents')
	if not events then return end

	FakeKXUser:Clean(events.OnMessageDoneFiltering.OnClientEvent:Connect(function(data)
		if data and data.Message then
			fakeKXUser(data.FromSpeaker, data.Message)
		end
	end))
end

AutoToxic = vape.Categories.Utility:CreateModule({
	Name = 'AutoToxic',
	Function = function(callback)
		if callback then
			-- one line as the module comes on, so the answer is in chat before it matters
			task.spawn(sayKXUsers)

			AutoToxic:Clean(vapeEvents.CheaterKicked.Event:Connect(sendMessage))
		end
	end,
	Tooltip = 'Says a message after a cheater gets kicked with CheatDetector enabled.'
})

KXUser = AutoToxic:CreateToggle({
	Name = 'KXUser',
	Default = false,
	Function = function(callback)
		if KXSkip then
			KXSkip.Object.Visible = callback
		end
	end,
	Tooltip = 'auto check kx users'
})

KXSkip = AutoToxic:CreateTextList({
	Name = 'Skip userid',
	Darker = true,
	Visible = false,
	Tooltip = 'Stays quiet while any of these user ids is in the server'
})

KXSkip.Object.Visible = KXUser.Enabled

FakeKXUser = AutoToxic:CreateToggle({
	Name = 'Fake KXUser',
	Default = true,
	Function = function(callback)
		if callback then
			pcall(connectFake)
		end
	end,
	Tooltip = 'Answers .kxusers with the text picked below'
})

-- a toggle is a leaf, it cannot host a dropdown, so this sits under the module next to
-- Fake KXUser
FakeText = AutoToxic:CreateDropdown({
	Name = 'Fake Text',
	Darker = true,
	List = {'Inhaler V4', 'KX ADMIN'},
	Tooltip = 'What the answer to .kxusers claims to be running'
})

pcall(function()
	for _, group in textChatService:GetPresetsAsync().categoryGroups do
		for _, category in group.categories do
			for _, message in category.messages do
				Presets[message.value] = message.presetId
			end
		end
	end
end)
