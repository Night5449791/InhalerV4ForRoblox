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
local Folder = Instance.new('Folder')
Folder.Name = 'PlotESP'
Folder.Parent = vape.holder

local function plotLabel(plot)
	local owner = israel.plotOwner(plot)
	local name = owner and owner.DisplayName or 'Empty'
	if plot:GetAttribute('NewbieShield') == true then
		name = name..' (shield)'
	end

	return name
end

local function plotColor(plot)
	if israel.plotOwner(plot) == lplr then
		return Color3.fromHSV(OwnColor.Hue, OwnColor.Sat, OwnColor.Value)
	end

	if plot:GetAttribute('NewbieShield') == true then
		return Color3.fromHSV(ShieldColor.Hue, ShieldColor.Sat, ShieldColor.Value)
	end

	return Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
end

local function refreshText()
	for plot, data in referenced do
		if data.text then
			data.text.Text = plotLabel(plot)
			data.text.TextColor3 = plotColor(plot)
		end
		if data.highlight then
			data.highlight.OutlineColor = plotColor(plot)
		end
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

	local highlight = Instance.new('Highlight')
	highlight.Adornee = target
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.FillColor = plotColor(plot)
	highlight.OutlineColor = plotColor(plot)
	highlight.FillTransparency = FillTransparency.Value
	highlight.OutlineTransparency = OutlineTransparency.Value
	highlight.Parent = Folder

	local billboard
	local text
	if ShowText.Enabled then
		local size = getfontbounds('Empty (shield)', 14 * Scale.Value, uipallet.Font, Vector2.new(100000, 100000))
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
		text.Text = plotLabel(plot)
		text.TextColor3 = plotColor(plot)
		text.TextSize = 14 * Scale.Value
		text.TextStrokeTransparency = 1
		text.TextStrokeColor3 = Color3.new()
		text.Parent = billboard
	end

	referenced[plot] = {
		highlight = highlight,
		billboard = billboard,
		text = text,
		titleConnection = plot:GetAttributeChangedSignal('OwnerUserId'):Connect(refreshText),
		shieldConnection = plot:GetAttributeChangedSignal('NewbieShield'):Connect(refreshText),
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
