local DownedESP
local DownedColor
local highlights = {}

local function clearHighlights()
	for character, highlight in highlights do
		highlight:Destroy()
		highlights[character] = nil
	end
end

local function updateHighlightColor()
	local color = Color3.fromHSV(DownedColor.Hue, DownedColor.Sat, DownedColor.Value)

	for _, highlight in highlights do
		highlight.FillColor = color
		highlight.OutlineColor = color
	end
end

DownedESP = vape.Categories.Render:CreateModule({
	Name = 'DownedESP',
	Function = function(callback)
		clearHighlights()

		if not callback then return end

		repeat
			local localCharacter = lplr.Character

			for _, plr in playersService:GetPlayers() do
				local character = plr.Character
				if character and character ~= localCharacter then
					local highlight = highlights[character]
					local downed = sentence.isDowned(plr)

					if downed and not highlight then
						highlight = Instance.new('Highlight')
						highlight.FillColor = Color3.fromHSV(DownedColor.Hue, DownedColor.Sat, DownedColor.Value)
						highlight.FillTransparency = 0.65
						highlight.OutlineColor = highlight.FillColor
						highlight.OutlineTransparency = 0
						highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
						highlight.Adornee = character
						highlight.Parent = character
						highlights[character] = highlight
					elseif not downed and highlight then
						highlight:Destroy()
						highlights[character] = nil
					end
				end
			end

			task.wait(0.5)
		until not DownedESP.Enabled or vape.Loaded == nil

		clearHighlights()
	end,
	Tooltip = 'Highlights players that are downed and can be arrested or stomped'
})
DownedColor = DownedESP:CreateColorSlider({
	Name = 'Color',
	DefaultHue = 0.02,
	DefaultSat = 1,
	DefaultValue = 1,
	Function = function()
		updateHighlightColor()
	end
})
