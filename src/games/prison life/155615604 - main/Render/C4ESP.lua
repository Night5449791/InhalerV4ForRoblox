local C4ESP
local FillColor
local OutlineColor
local FillTransparency
local OutlineTransparency
local Reference = {}
local lastFill, lastOutline
local Folder = Instance.new('Folder')
Folder.Parent = vape.holder

local function Removed(c4)
	local cham = Reference[c4]
	if not cham then
		return
	end

	if vape.ThreadFix then
		setthreadidentity(8)
	end

	cham:Destroy()
	Reference[c4] = nil
end

local function Added(c4)
	if Reference[c4] then
		return
	end

	local cham = Instance.new('Highlight')
	cham.Adornee = c4
	cham.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	cham.FillColor = Color3.fromHSV(FillColor.Hue, FillColor.Sat, FillColor.Value)
	cham.OutlineColor = Color3.fromHSV(OutlineColor.Hue, OutlineColor.Sat, OutlineColor.Value)
	cham.FillTransparency = FillTransparency.Value
	cham.OutlineTransparency = OutlineTransparency.Value
	cham.Parent = Folder

	Reference[c4] = cham

	c4.Destroying:Connect(function()
		Removed(c4)
	end)
end

C4ESP = vape.Categories.Render:CreateModule({
	Name = 'C4ESP',
	Function = function(callback)
		if callback then
			C4ESP:Clean(collectionService:GetInstanceAddedSignal('C4'):Connect(Added))
			C4ESP:Clean(collectionService:GetInstanceRemovedSignal('C4'):Connect(Removed))

			for _, c4 in collectionService:GetTagged('C4') do
				Added(c4)
			end
		else
			for _, cham in Reference do
				cham:Destroy()
			end

			table.clear(Reference)
		end
	end,
	Tooltip = 'Display all C4\'s placed'
})
FillColor = C4ESP:CreateColorSlider({
	Name = 'Color',
	Function = function(hue, sat, val)
		local color = Color3.fromHSV(hue, sat, val)
		if color == lastFill then
			return
		end

		lastFill = color

		for _, cham in Reference do
			cham.FillColor = color
		end
	end
})
OutlineColor = C4ESP:CreateColorSlider({
	Name = 'Outline Color',
	DefaultSat = 0,
	Function = function(hue, sat, val)
		local color = Color3.fromHSV(hue, sat, val)
		if color == lastOutline then
			return
		end

		lastOutline = color

		for _, cham in Reference do
			cham.OutlineColor = color
		end
	end
})
FillTransparency = C4ESP:CreateSlider({
	Name = 'Transparency',
	Min = 0,
	Max = 1,
	Default = 0.5,
	Function = function(val)
		for _, cham in Reference do
			cham.FillTransparency = val
		end
	end,
	Decimal = 10
})
OutlineTransparency = C4ESP:CreateSlider({
	Name = 'Outline Transparency',
	Min = 0,
	Max = 1,
	Default = 0.5,
	Function = function(val)
		for _, cham in Reference do
			cham.OutlineTransparency = val
		end
	end,
	Decimal = 10
})
