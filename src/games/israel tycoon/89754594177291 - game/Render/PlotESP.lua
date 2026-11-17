local PlotESP
local ShowText
local Color
local OwnColor
local ShieldColor
local FillTransparency
local OutlineTransparency
local Scale
local referenced = {}
local nextRefresh = 0
local getfontbounds = vape.Libraries.getfontbounds
local uipallet = vape.Libraries.uipallet
local ownColorCache = {}
local shieldColorCache = {}
local baseColorCache = {}
local lastTextScale
local lastTextSize
local Folder = Instance.new('Folder')
Folder.Name = 'PlotESP'
Folder.Parent = vape.holder

local function cachedColor(option, cache)
	if cache.hue ~= option.Hue or cache.sat ~= option.Sat or cache.value ~= option.Value then
		cache.hue = option.Hue
		cache.sat = option.Sat
		cache.value = option.Value
		cache.color = Color3.fromHSV(option.Hue, option.Sat, option.Value)
	end

	return cache.color
end

local function getTextSize()
	local scale = Scale.Value

	if lastTextScale ~= scale then
		lastTextScale = scale
		lastTextSize = getfontbounds('Empty (shield)', 14 * scale, uipallet.Font, Vector2.new(100000, 100000))
	end

	return lastTextSize
end

local function plotLabel(plot, owner)
	local name = owner and owner.DisplayName or 'Empty'

	if plot:GetAttribute('NewbieShield') == true then
		name = name..' (shield)'
	end

	return name
end

local function plotColor(plot, owner)
	if owner == lplr then
		return cachedColor(OwnColor, ownColorCache)
	end

	if plot:GetAttribute('NewbieShield') == true then
		return cachedColor(ShieldColor, shieldColorCache)
	end

	return cachedColor(Color, baseColorCache)
end

local function refreshPlot(plot)
	local data = referenced[plot]
	if not data then return end

	local owner = israel.plotOwner(plot)
	local color = plotColor(plot, owner)

	if data.text then
		data.text.Text = plotLabel(plot, owner)
		data.text.TextColor3 = color
	end

	if data.highlight then
		data.highlight.OutlineColor = color
	end
end

local function refreshText()
	for plot in referenced do
		refreshPlot(plot)
	end
end

local function Removed(plot)
	local data = referenced[plot]
	if not data then return end

	if data.connection then
		data.connection:Disconnect()
	end

	if data.highlight then
		data.highlight:Destroy()
	end

	if data.billboard then
		data.billboard:Destroy()
	end

	referenced[plot] = nil
end

local function Added(plot)
	if referenced[plot] then return end

	local target = plot.PrimaryPart or plot:FindFirstChild('Base')
	if not target then return end

	local owner = israel.plotOwner(plot)
	local color = plotColor(plot, owner)
	local highlight = Instance.new('Highlight')
	highlight.Adornee = target
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.FillColor = color
	highlight.OutlineColor = color
	highlight.FillTransparency = FillTransparency.Value
	highlight.OutlineTransparency = OutlineTransparency.Value
	highlight.Parent = Folder

	local billboard
	local text
	if ShowText.Enabled then
		local size = getTextSize()
		billboard = Instance.new('BillboardGui')
		billboard.AlwaysOnTop = true
		billboard.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
		billboard.Adornee = target
		billboard.Parent = Folder

		text = Instance.new('TextLabel')
		text.BackgroundTransparency = 1
		text.BorderSizePixel = 0
		text.FontFace = uipallet.Font
		text.RichText = true
		text.Size = billboard.Size
		text.Text = plotLabel(plot, owner)
		text.TextColor3 = color
		text.TextSize = 14 * Scale.Value
		text.TextStrokeTransparency = 1
		text.TextStrokeColor3 = Color3.new()
		text.Parent = billboard
	end

	referenced[plot] = {
		highlight = highlight,
		billboard = billboard,
		text = text,
		titleConnection = plot:GetAttributeChangedSignal('OwnerUserId'):Connect(function()
			refreshPlot(plot)
		end),
		shieldConnection = plot:GetAttributeChangedSignal('NewbieShield'):Connect(function()
			refreshPlot(plot)
		end),
		connection = plot.Destroying:Connect(function()
			Removed(plot)
		end)
	}
end

local function Rescan()
	for plot in referenced do
		Removed(plot)
	end

	local folder = israel.tycoonsFolder()
	if not folder then return end

	for _, plot in folder:GetChildren() do
		Added(plot)
	end
end

PlotESP = vape.Categories.Render:CreateModule({
	Name = 'PlotESP',
	Function = function(callback)
		if callback then
			local folder = israel.tycoonsFolder()
			if folder then
				PlotESP:Clean(folder.ChildAdded:Connect(Added))
				PlotESP:Clean(folder.ChildRemoved:Connect(Removed))
			end

			PlotESP:Clean(playersService.PlayerAdded:Connect(function()
				refreshText()
			end))
			PlotESP:Clean(playersService.PlayerRemoving:Connect(function()
				refreshText()
			end))
			PlotESP:Clean(runService.Heartbeat:Connect(function()
				if not ShowText.Enabled then return end

				local now = os.clock()
				if now < nextRefresh then return end

				nextRefresh = now + 0.25
				refreshText()
			end))

			Rescan()
		else
			for plot in referenced do
				Removed(plot)
			end
		end
	end,
	Tooltip = 'Highlights every tycoon plot with its owner'
})
ShowText = PlotESP:CreateToggle({
	Name = 'Owner',
	Function = function()
		if PlotESP.Enabled then
			PlotESP:Toggle()
			PlotESP:Toggle()
		end
	end,
	Default = true
})
Color = PlotESP:CreateColorSlider({
	Name = 'Color',
	Function = function()
		refreshText()
	end
})
OwnColor = PlotESP:CreateColorSlider({
	Name = 'Own Plot Color',
	DefaultValue = 0.35,
	Function = function()
		refreshText()
	end
})
ShieldColor = PlotESP:CreateColorSlider({
	Name = 'Shielded Color',
	DefaultValue = 0.6,
	Function = function()
		refreshText()
	end
})
FillTransparency = PlotESP:CreateSlider({
	Name = 'Fill Transparency',
	Min = 0,
	Max = 1,
	Default = 0.8,
	Function = function(val)
		for plot, data in referenced do
			data.highlight.FillTransparency = val
		end
	end,
	Decimal = 10
})
OutlineTransparency = PlotESP:CreateSlider({
	Name = 'Outline Transparency',
	Min = 0,
	Max = 1,
	Default = 0,
	Function = function(val)
		for plot, data in referenced do
			data.highlight.OutlineTransparency = val
		end
	end,
	Decimal = 10
})
Scale = PlotESP:CreateSlider({
	Name = 'Text Scale',
	Min = 0.1,
	Max = 1.5,
	Default = 1,
	Function = function()
		if PlotESP.Enabled then
			PlotESP:Toggle()
			PlotESP:Toggle()
		end
	end,
	Decimal = 10
})
