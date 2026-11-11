local AutoToxic
local KXUser
local KXSkip
local FakeKXUser
local FakeText
local Presets = {}
local cloned = {}
local random = Random.new()
local lines = {
	'prison life moment | kicked <obj>',
	'do you also want an antifling? | kicked <obj>',
	'i wonder why you got kicked | kicked <obj>'
}
local fakeMessages = {
	['Inhaler V4'] = 'I use the script Inhaler V4',
	['KX ADMIN'] = 'I use the script KX-ADMIN'
}

local function say(message)
	if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		textChatService.ChatInputBarConfiguration.TargetTextChannel:SendAsync(message)
	else
		replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(message, 'All')
	end
end

local function sayKXUsers()
	task.wait(5)

	if not KXUser.Enabled then return end

	if #KXSkip.ListEnabled > 0 then
		for _, player in playersService:GetPlayers() do
			if table.find(KXSkip.ListEnabled, tostring(player.UserId)) then return end
		end
	end

	pcall(say, '.kxusers')
end

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

local function connectFake()
	if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		FakeKXUser:Clean(textChatService.MessageReceived:Connect(function(chatMessage)
			if chatMessage.Status == Enum.TextChatMessageStatus.InvalidTextChannelPermissions then return end

			local source = chatMessage.TextSource
			if not source then return end

			local player = playersService:GetPlayerByUserId(source.UserId)
			if not player then return end

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

FakeText = AutoToxic:CreateDropdown({
	Name = 'Fake Text',
	Darker = true,
	List = {'Inhaler V4', 'KX ADMIN'},
	Tooltip = '.kxusers spoofing'
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
