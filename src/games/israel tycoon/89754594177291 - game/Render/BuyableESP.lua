local BuyableESP
local ShowPrice
local OnlyAffordable
local Color
local AffordableColor
local Scale
local getfontbounds = vape.Libraries.getfontbounds
local uipallet = vape.Libraries.uipallet
local parented = {}
local nextRefresh = 0
local Folder = Instance.new('Folder')
Folder.Name = 'BuyableESP'
Folder.Parent = vape.holder

-- Button_<Id> is the only link back to Config, which is where the price and label live
local function itemFor(button)
	local config = israel.Config
	if not config or not config.Items then return end

	local id = button.Name:match('^Button_(.+)$')
	if not id then return end

	for _, item in config.Items do
		if item.Id == id then
			return item
		end
	end
end

local function affordable(item)
	return israel.cash() >= (item.Price or 0)
end

local function colorFor(item)
	if affordable(item) then
		return Color3.fromHSV(AffordableColor.Hue, AffordableColor.Sat, AffordableColor.Value)
	end

	return Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
end

local function Removed(button)
	local data = parented[button]
	if not data then return end

	if data.connection then
		data.connection:Disconnect()
	end

	if data.billboard then
		data.billboard:Destroy()
	end

	parented[button] = nil
end

local function Added(button)
	if parented[button] then return end

	local item = itemFor(button)
	if not item then return end
	if OnlyAffordable.Enabled and not affordable(item) then return end

	local target = button:FindFirstChildWhichIsA('BasePart', true)
	if not target then return end

	local label = ShowPrice.Enabled and (item.Name..' - '..(item.Price or 0)) or item.Name
	local size = getfontbounds(label, 14 * Scale.Value, uipallet.Font, Vector2.new(100000, 100000))

	local billboard = Instance.new('BillboardGui')
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
	billboard.Adornee = target
	billboard.Parent = Folder

	local text = Instance.new('TextLabel')
	text.BackgroundTransparency = 1
	text.BorderSizePixel = 0
	text.FontFace = uipallet.Font
	text.Size = billboard.Size
	text.Text = label
	text.TextColor3 = colorFor(item)
	text.TextSize = 14 * Scale.Value
	text.TextStrokeTransparency = 1
	text.TextStrokeColor3 = Color3.new()
	text.Parent = billboard

	parented[button] = {
		billboard = billboard,
		text = text,
		item = item,
		connection = button.Destroying:Connect(function()
			Removed(button)
		end)
	}
end

local function Rescan()
	for button in parented do
		Removed(button)
	end

	local plot = israel.plot(lplr)
	local buttons = plot and plot:FindFirstChild('Buttons')
	if not buttons then return end

	for _, button in buttons:GetChildren() do
		Added(button)
	end
end

BuyableESP = vape.Categories.Render:CreateModule({
	Name = 'BuyableESP',
	Function = function(callback)
		if callback then
			BuyableESP:Clean(runService.Heartbeat:Connect(function()
				local now = os.clock()
				if now < nextRefresh then return end

				nextRefresh = now + 0.5
				for button, data in parented do
					data.text.TextColor3 = colorFor(data.item)
				end
			end))

			Rescan()
		else
			for button in parented do
				Removed(button)
			end
		end
	end,
	Tooltip = 'Labels every buyable on your plot with its name and price'
})
ShowPrice = BuyableESP:CreateToggle({
	Name = 'Show Price',
	Function = function()
		if BuyableESP.Enabled then
			BuyableESP:Toggle()
			BuyableESP:Toggle()
		end
	end,
	Default = true
})
OnlyAffordable = BuyableESP:CreateToggle({
	Name = 'Only Affordable',
	Function = function()
		if BuyableESP.Enabled then
			BuyableESP:Toggle()
			BuyableESP:Toggle()
		end
	end
})
Color = BuyableESP:CreateColorSlider({
	Name = 'Too Expensive Color',
	DefaultValue = 0,
	DefaultSat = 1,
	Function = function()
		if BuyableESP.Enabled then
			BuyableESP:Toggle()
			BuyableESP:Toggle()
		end
	end
})
AffordableColor = BuyableESP:CreateColorSlider({
	Name = 'Affordable Color',
	DefaultValue = 0.33,
	Function = function()
		if BuyableESP.Enabled then
			BuyableESP:Toggle()
			BuyableESP:Toggle()
		end
	end
})
Scale = BuyableESP:CreateSlider({
	Name = 'Text Scale',
	Min = 0.1,
	Max = 1.5,
	Default = 0.8,
	Function = function()
		if BuyableESP.Enabled then
			BuyableESP:Toggle()
			BuyableESP:Toggle()
		end
	end,
	Decimal = 10
})
