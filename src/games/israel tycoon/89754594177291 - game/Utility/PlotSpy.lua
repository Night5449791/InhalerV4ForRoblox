local PlotSpy
local FontOption
local TextSize
local HideMine
local holder
local label

local cashUnits = {{1e12, 'T'}, {1e9, 'B'}, {1e6, 'M'}, {1e3, 'K'}}

local function formatCash(value)
	local suffix = ''

	for _, unit in cashUnits do
		if value >= unit[1] then
			suffix = unit[2]
			value = value / unit[1]
			break
		end
	end

	return string.format(value >= 100 and '%.0f' or '%.1f', value)..suffix
end

local function buildLines()
	local folder = israel.tycoonsFolder()
	if not folder then return {} end

	local list = {}
	for _, plot in folder:GetChildren() do
		local owner = israel.plotOwner(plot)
		if owner ~= lplr or not HideMine.Enabled then
			local items = plot:FindFirstChild('Items')
			table.insert(list, {
				owner = owner and owner.DisplayName or 'Empty',
				cash = plot:GetAttribute('PendingCash') or 0,
				items = items and #items:GetChildren() or 0,
				shield = plot:GetAttribute('NewbieShield') == true,
				mine = owner == lplr
			})
		end
	end

	table.sort(list, function(a, b)
		return a.cash > b.cash
	end)

	local lines = {}
	for _, row in list do
		local text = row.owner..': '..formatCash(row.cash)..' / '..row.items..' items'
		if row.shield then
			text = text..' [shield]'
		end
		if row.mine then
			text = text..' [you]'
		end

		table.insert(lines, text)
	end

	return lines
end

local function render()
	if not label then return end

	local lines = buildLines()
	label.Text = #lines > 0 and table.concat(lines, '\n') or 'No plots found'
	label.FontFace = FontOption.Value
	label.TextSize = TextSize.Value

	local size = getfontbounds(label.Text, label.TextSize, label.FontFace, Vector2.new(100000, 100000))
	holder.Size = UDim2.fromOffset(size.X + 16, size.Y + 16)
end

PlotSpy = vape:CreateOverlay({
	Name = 'Plot Spy',
	Icon = getvapeasset('InhalerV4/assets/new/textgui.png'),
	Size = UDim2.fromOffset(16, 12),
	Position = UDim2.fromOffset(12, 14),
	Function = function(callback)
		if not callback then return end

		repeat
			render()
			task.wait(1)
		until not PlotSpy.Button or not PlotSpy.Button.Enabled
	end
})
FontOption = PlotSpy:CreateFont({
	Name = 'Font',
	Blacklist = 'Arial'
})
TextSize = PlotSpy:CreateSlider({
	Name = 'Text Size',
	Min = 10,
	Max = 24,
	Default = 14,
	Function = function()
		render()
	end
})
HideMine = PlotSpy:CreateToggle({
	Name = 'Hide Own Plot',
	Function = function()
		render()
	end
})
PlotSpy:CreateColorSlider({
	Name = 'Background Color',
	DefaultValue = 0,
	DefaultOpacity = 0.5,
	Function = function(hue, sat, val, opacity)
		holder.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
		holder.BackgroundTransparency = 1 - opacity
	end
})

holder = Instance.new('Frame')
holder.BackgroundColor3 = Color3.new()
holder.BackgroundTransparency = 0.5
holder.Parent = PlotSpy.Children
vape:Clean(PlotSpy.Children:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
	if vape.ThreadFix then
		setthreadidentity(8)
	end

	local right = PlotSpy.Children.AbsolutePosition.X > (vape.gui.AbsoluteSize.X / 2)
	holder.Position = UDim2.fromScale(right and 1 or 0, 0)
	holder.AnchorPoint = Vector2.new(right and 1 or 0, 0)
end))
local corner = Instance.new('UICorner')
corner.CornerRadius = UDim.new(0, 5)
corner.Parent = holder
label = Instance.new('TextLabel')
label.BackgroundTransparency = 1
label.Font = Enum.Font.Arial
label.Position = UDim2.fromOffset(8, 8)
label.Size = UDim2.new(1, -16, 1, -16)
label.Text = ''
label.TextColor3 = Color3.new(1, 1, 1)
label.TextSize = 14
label.TextStrokeColor3 = Color3.new()
label.TextStrokeTransparency = 0.8
label.TextXAlignment = Enum.TextXAlignment.Left
label.TextYAlignment = Enum.TextYAlignment.Top
label.Parent = holder
