local AutoToxic
local KXUser
local KXSkip
local Presets = {}
local cloned = {}
local random = Random.new()

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

local lines = {
	'prison life moment | kicked <obj>',
	'do you also want an antifling? | kicked <obj>',
	'i wonder why you got kicked | kicked <obj>',
}

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

pcall(function()
	for _, group in textChatService:GetPresetsAsync().categoryGroups do
		for _, category in group.categories do
			for _, message in category.messages do
				Presets[message.value] = message.presetId
			end
		end
	end
end)
