local CuffedESP
local Color
local highlights = {}

local function clearHighlights()
	for character, highlight in highlights do
		highlight:Destroy()
		highlights[character] = nil
	end
end

local function updateColor()
	local color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)

	for _, highlight in highlights do
		highlight.FillColor = color
		highlight.OutlineColor = color
	end
end

CuffedESP = vape.Categories.Render:CreateModule({
	Name = 'CuffedESP',
	Function = function(callback)
		clearHighlights()

		if not callback then return end

		repeat
			for _, plr in playersService:GetPlayers() do
				local character = plr.Character
				if character and character ~= lplr.Character then
					local highlight = highlights[character]
					local cuffed = redwood.state(character, 'Handcuffed_')

					if cuffed and not highlight then
						highlight = Instance.new('Highlight')
						highlight.FillColor = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
						highlight.FillTransparency = 0.65
						highlight.OutlineColor = highlight.FillColor
						highlight.OutlineTransparency = 0
						highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
						highlight.Adornee = character
						highlight.Parent = character
						highlights[character] = highlight
					elseif not cuffed and highlight then
						highlight:Destroy()
						highlights[character] = nil
					end
				end
			end

			task.wait(0.5)
		until not CuffedESP.Enabled or vape.Loaded == nil

		clearHighlights()
	end,
	Tooltip = 'Highlights players that are already handcuffed'
})
Color = CuffedESP:CreateColorSlider({
	Name = 'Color',
	DefaultHue = 0.12,
	DefaultSat = 1,
	DefaultValue = 1,
	Function = function()
		updateColor()
	end
})
