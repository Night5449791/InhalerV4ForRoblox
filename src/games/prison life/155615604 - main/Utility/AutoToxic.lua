local AutoToxic
local Presets = {}
local cloned = {}
local random = Random.new()

local lines = {
	'prison life moment | kicked <obj>',
	'do you also want an antifling? | kicked <obj>',
	'i wonder why you got kicked | kicked <obj>',
}

local function sendMessage(obj)
	if not next(cloned) then
		cloned = table.clone(lines)
	end

	local message = table.remove(cloned, random:NextInteger(1, #cloned)):gsub('<obj>', obj or '')

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
			AutoToxic:Clean(vapeEvents.CheaterKicked.Event:Connect(sendMessage))
		end
	end,
	Tooltip = 'Says a message after a cheater gets kicked with CheatDetector enabled.'
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
