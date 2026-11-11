local AntiVoiceChatBan
local bypassThread
local getConnections = typeof(getconnections) == 'function' and getconnections or nil
local getHiddenGui = typeof(gethui) == 'function' and gethui or nil
local voiceChatService, voiceChatInternal
pcall(function()
	voiceChatService = cloneref(game:GetService('VoiceChatService'))
	voiceChatInternal = cloneref(game:GetService('VoiceChatInternal'))
end)
local mutedIcon = 'rbxasset://textures/ui/VoiceChat/MicLight/Muted.png'
local unmutedIcon = 'rbxasset://textures/ui/VoiceChat/MicLight/Talking0.png'
local micOffsetX, micOffsetY, micSize = 14, 13, 35
local disableStart = 7
local state = {
	muted = false,
	busy = false,
	executed = false
}
local controller, micIcon, micButton
local clickConnection, stateConnection
local micToggle, redVoiceDot
local hidden, disabledConnections = {}, {}
local originalRedDot, originalPaused

local function getGuiHost()
	if getHiddenGui then
		local ok, hiddenGui = pcall(getHiddenGui)
		if ok and typeof(hiddenGui) == 'Instance' then
			return hiddenGui
		end
	end

	if typeof(coreGui) == 'Instance' then
		return coreGui
	end

	local ok, playerGui = pcall(function()
		return lplr:WaitForChild('PlayerGui', 5)
	end)
	return ok and typeof(playerGui) == 'Instance' and playerGui or nil
end

local function publishMute(paused)
	if not voiceChatInternal then return end
	pcall(function()
		voiceChatInternal:PublishPause(paused)
	end)
end

local function isPublishPaused()
	if not voiceChatInternal then return false end
	local ok, paused = pcall(function()
		return voiceChatInternal:IsPublishPaused()
	end)
	return ok and paused == true
end

local function syncIcon()
	if micIcon then
		micIcon.Image = (state.muted and mutedIcon or unmutedIcon)
	end

	if redVoiceDot and redVoiceDot.Parent then
		if originalRedDot == nil then
			originalRedDot = redVoiceDot.Visible
		end

		redVoiceDot.Visible = not state.muted
	end
end

local function setMuted(paused)
	state.muted = paused and true or false
	publishMute(state.muted)
	syncIcon()
end

local function callVoice(methodName)
	if not voiceChatService then return end

	local ok, method = pcall(function()
		return voiceChatService[methodName]
	end)
	if not ok or typeof(method) ~= 'function' then return end

	pcall(function()
		method(voiceChatService)
	end)
end

local function scanMic()
	micToggle, redVoiceDot, micIcon = nil, nil, nil

	local objects = coreGui:QueryDescendants('GuiObject')
	for _, object in objects do
		if object.Name == 'toggle_mic_mute' then
			micToggle = object
		elseif object.Name == 'RedVoiceDot' then
			redVoiceDot = object
		end
	end

	if micToggle then
		local iconFrame = micToggle:FindFirstChild('IntegrationIconFrame', true)
		if iconFrame then
			micIcon = iconFrame:FindFirstChild('IntegrationIcon', true)
		end
	end
end

local function step(seconds)
	task.wait(seconds)
	return vape.Loaded and AntiVoiceChatBan.Enabled
end

local function micImage()
	local icon = micIcon and micIcon:FindFirstChild('1')

	return icon and icon.Image or nil
end

local function waitUnmuted()
	scanMic()
	if not micToggle then
		callVoice('joinVoice')
		if not step(1.5) then return end
		scanMic()
	end

	notif('AntiVoiceChatBan', 'Unmute to continue.', 5)
	while vape.Loaded do
		local image = micImage()
		if image and image ~= '' and image ~= mutedIcon then
			return true
		end

		task.wait(0.5)
	end
end

local function transparencyOf(object)
	if object:IsA('ImageLabel') or object:IsA('ImageButton') then
		return 'ImageTransparency'
	end

	return (object:IsA('TextLabel') or object:IsA('TextButton')) and 'TextTransparency' or nil
end

local function hideMicButton()
	if not micToggle then return end

	for _, object in micToggle:QueryDescendants('GuiObject') do
		local property = transparencyOf(object)
		if property then
			hidden[object] = {property = property, value = object[property]}
			object[property] = 1
		end
	end
end

local function disableStateConnections()
	if not getConnections or not voiceChatInternal then return end

	local connections = getConnections(voiceChatInternal.StateChanged)
	for index = disableStart, #connections do
		local connection = connections[index]
		if connection then
			pcall(function()
				connection:Disable()
			end)
			table.insert(disabledConnections, connection)
		end
	end
end

local function createController()
	local host = getGuiHost()
	if not host then return end

	local existing = host:FindFirstChild('CustomVoiceController')
	if existing then
		existing:Destroy()
	end

	controller = Instance.new('ScreenGui')
	controller.Name = 'CustomVoiceController'
	controller.ResetOnSpawn = false
	controller.IgnoreGuiInset = true
	controller.DisplayOrder = 999999
	controller.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	controller.Parent = host
	AntiVoiceChatBan:Clean(controller)

	micButton = Instance.new('TextButton')
	micButton.Name = 'MicHitArea'
	micButton.BackgroundTransparency = 1
	micButton.Position = UDim2.new(0, 150 + micOffsetX, 0, 4 + micOffsetY)
	micButton.Size = UDim2.new(0, micSize, 0, micSize)
	micButton.Text = ''
	micButton.Active = true
	micButton.ZIndex = 10000
	micButton.Parent = controller

	micIcon = Instance.new('ImageLabel')
	micIcon.Name = 'MicIcon'
	micIcon.BackgroundTransparency = 1
	micIcon.Image = mutedIcon
	micIcon.ScaleType = Enum.ScaleType.Fit
	micIcon.Size = UDim2.new(1, 0, 1, 0)
	micIcon.ZIndex = 10001
	micIcon.Parent = micButton

	clickConnection = micButton.MouseButton1Click:Connect(function()
		setMuted(not state.muted)
	end)
	AntiVoiceChatBan:Clean(clickConnection)

	stateConnection = voiceChatInternal.StateChanged:Connect(function()
		state.muted = isPublishPaused()
		syncIcon()
	end)
	AntiVoiceChatBan:Clean(stateConnection)

	if not micToggle then
		local own = micIcon
		scanMic()
		micIcon = own
	end

	local iconPosition
	if micToggle and micToggle.AbsolutePosition.X > 50 then
		iconPosition = micToggle.AbsolutePosition
	end

	if iconPosition and iconPosition.X > 0 and iconPosition.Y >= 0 then
		micButton.Position = UDim2.new(0, iconPosition.X + micOffsetX, 0, iconPosition.Y + micOffsetY)
		micButton.Size = UDim2.new(0, micSize, 0, micSize)
	end

	setMuted(true)
	return true
end

local function restore()
	if typeof(bypassThread) == 'thread' and bypassThread ~= coroutine.running() and coroutine.status(bypassThread) ~= 'dead' then
		pcall(task.cancel, bypassThread)
	end
	bypassThread = nil
	state.busy, state.executed = false, false
	state.muted = false

	if clickConnection then
		pcall(function()
			clickConnection:Disconnect()
		end)
		clickConnection = nil
	end

	if stateConnection then
		pcall(function()
			stateConnection:Disconnect()
		end)
		stateConnection = nil
	end

	for object, entry in hidden do
		object[entry.property] = entry.value
	end
	table.clear(hidden)

	if redVoiceDot and originalRedDot ~= nil then
		redVoiceDot.Visible = originalRedDot
	end
	originalRedDot = nil

	if controller then
		controller:Destroy()
		controller = nil
	end

	for index = 1, #disabledConnections do
		pcall(function()
			disabledConnections[index]:Enable()
		end)
	end
	table.clear(disabledConnections)

	if originalPaused ~= nil then
		publishMute(originalPaused)
		originalPaused = nil
	end

	micIcon, micButton, micToggle, redVoiceDot = nil, nil, nil, nil
end
vape:Clean(restore)

local function bypass()
	if state.busy or state.executed then
		notif('AntiVoiceChatBan', (state.executed and 'Already bypassed' or 'Already running'), 3)
		return
	end

	if not voiceChatService or not voiceChatInternal or not getConnections then
		notif('AntiVoiceChatBan', 'Voice chat services or getconnections are unavailable.', 5, 'alert')
		if AntiVoiceChatBan.Enabled then
			AntiVoiceChatBan:Toggle()
		end
		return
	end

	originalPaused = isPublishPaused()
	state.busy = true
	bypassThread = coroutine.running()

	local ok, result = pcall(function()
		if not waitUnmuted() then return end
		if not step(1) then return end

		callVoice('leaveVoice')
		if not step(2) then return end

		disableStateConnections()
		if not step(2) then return end

		callVoice('joinVoice')
		if not step(1) then return end

		scanMic()
		hideMicButton()
		return createController()
	end)
	bypassThread = nil
	state.busy = false

	if not vape.Loaded or not AntiVoiceChatBan.Enabled then
		restore()
		return
	end

	if ok and result then
		state.executed = true
		notif('AntiVoiceChatBan', 'Bypass active. Use the mic button to mute and unmute.', 5)
	else
		restore()
		notif('AntiVoiceChatBan', 'Bypass failed'..(ok and '' or ': '..tostring(result)), 5, 'alert')
		if AntiVoiceChatBan.Enabled then
			AntiVoiceChatBan:Toggle()
		end
	end
end

AntiVoiceChatBan = vape.Categories.World:CreateModule({
	Name = 'AntiVoiceChatBan',
	Function = function(callback)
		if callback then
			bypass()
		else
			restore()
		end
	end,
	Tooltip = 'Bypasses voice chat bans\nUnmute your mic, talk into it for 5 seconds, then enable the module.'
})
