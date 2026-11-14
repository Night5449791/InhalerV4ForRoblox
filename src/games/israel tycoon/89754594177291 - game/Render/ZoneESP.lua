local ZoneESP
local ShowText
local Color
local HeldColor
local FillTransparency
local OutlineTransparency
local referenced = {}
local nextRefresh = 0
local getfontbounds = vape.Libraries.getfontbounds
local uipallet = vape.Libraries.uipallet
local Folder = Instance.new('Folder')
Folder.Name = 'ZoneESP'
Folder.Parent = vape.holder

local function zoneColor(zone)
	-- HolderUserId is the only stable signal: State is a display word (Neutral/Held/...)
	local holderId = zone:GetAttribute('HolderUserId')
	if typeof(holderId) == 'number' and holderId ~= 0 then
		return Color3.fromHSV(HeldColor.Hue, HeldColor.Sat, HeldColor.Value)
	end

	return Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
end

local function zoneLabel(zone)
	local state = zone:GetAttribute('State') or 'Neutral'
	local holder = zone:GetAttribute('HolderName')
	local capturer = zone:GetAttribute('CapturerName')
	local progress = zone:GetAttribute('Progress')

	if typeof(capturer) == 'string' and capturer ~= '' then
		return 'Capturing: '..capturer..(typeof(progress) == 'number' and (' '..math.floor(progress)..'%') or '')
	end

	if typeof(holder) == 'string' and holder ~= '' then
		return holder..' ('..state..')'
	end

	return state
end

local function refreshText()
	for zone, data in referenced do
		if data.text then
			data.text.Text = zoneLabel(zone)
			data.text.TextColor3 = zoneColor(zone)
		end

		if data.highlight then
			data.highlight.OutlineColor = zoneColor(zone)
		end
	end
end

local function Removed(zone)
	local data = referenced[zone]
	if not data then return end

	if data.connections then
		for _, connection in data.connections do
			connection:Disconnect()
		end
	end

	if data.connection then
		data.connection:Disconnect()
	end

	if data.highlight then
		data.highlight:Destroy()
	end

	if data.billboard then
		data.billboard:Destroy()
	end

	referenced[zone] = nil
end

local function Added(zone)
	if referenced[zone] then return end

	local target = zone.PrimaryPart or zone:FindFirstChildWhichIsA('BasePart', true)
	if not target then return end

	local highlight = Instance.new('Highlight')
	highlight.Adornee = target
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.FillColor = zoneColor(zone)
	highlight.OutlineColor = zoneColor(zone)
	highlight.FillTransparency = FillTransparency.Value
	highlight.OutlineTransparency = OutlineTransparency.Value
	highlight.Parent = Folder

	local billboard
	local text
	if ShowText.Enabled then
		local size = getfontbounds('Neutral 100%', 14, uipallet.Font, Vector2.new(100000, 100000))
		billboard = Instance.new('BillboardGui')
		billboard.AlwaysOnTop = true
		billboard.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
		billboard.Adornee = target
		billboard.Parent = Folder

		text = Instance.new('TextLabel')
		text.BackgroundTransparency = 1
		text.BorderSizePixel = 0
		text.FontFace = uipallet.Font
		text.Size = billboard.Size
		text.Text = zoneLabel(zone)
		text.TextColor3 = zoneColor(zone)
		text.TextSize = 14
		text.TextStrokeTransparency = 1
		text.TextStrokeColor3 = Color3.new()
		text.Parent = billboard
	end

	local connections = {}
	for _, attribute in {'State', 'Progress', 'HolderName', 'HolderUserId', 'CapturerName'} do
		table.insert(connections, zone:GetAttributeChangedSignal(attribute):Connect(refreshText))
	end

	referenced[zone] = {
		highlight = highlight,
		billboard = billboard,
		text = text,
		connections = connections,
		connection = zone.Destroying:Connect(function()
			Removed(zone)
		end)
	}
end

ZoneESP = vape.Categories.Render:CreateModule({
	Name = 'ZoneESP',
	Function = function(callback)
		if callback then
			local map = workspace:FindFirstChild('Map')
			local zone = map and map:FindFirstChild('CaptureZone')
			if zone then
				Added(zone)
			end

			if map then
				ZoneESP:Clean(map.ChildAdded:Connect(function(child)
					if child.Name == 'CaptureZone' then
						Added(child)
					end
				end))
			end

			ZoneESP:Clean(runService.Heartbeat:Connect(function()
				if not ShowText.Enabled then return end

				local now = os.clock()
				if now < nextRefresh then return end

				nextRefresh = now + 0.25
				refreshText()
			end))
		else
			for zone in referenced do
				Removed(zone)
			end
		end
	end,
	Tooltip = 'Highlights the capture zone and shows who holds it'
})
ShowText = ZoneESP:CreateToggle({
	Name = 'Status',
	Function = function()
		if ZoneESP.Enabled then
			ZoneESP:Toggle()
			ZoneESP:Toggle()
		end
	end,
	Default = true
})
Color = ZoneESP:CreateColorSlider({
	Name = 'Color',
	Function = function()
		refreshText()
	end
})
HeldColor = ZoneESP:CreateColorSlider({
	Name = 'Held Color',
	DefaultValue = 0.55,
	Function = function()
		refreshText()
	end
})
FillTransparency = ZoneESP:CreateSlider({
	Name = 'Fill Transparency',
	Min = 0,
	Max = 1,
	Default = 0.85,
	Function = function(val)
		for zone, data in referenced do
			data.highlight.FillTransparency = val
		end
	end,
	Decimal = 10
})
OutlineTransparency = ZoneESP:CreateSlider({
	Name = 'Outline Transparency',
	Min = 0,
	Max = 1,
	Default = 0,
	Function = function(val)
		for zone, data in referenced do
			data.highlight.OutlineTransparency = val
		end
	end,
	Decimal = 10
})
