local DownedESP
local DownedColor

-- keyed by player, not by character: a respawn swaps the body under the same player, and a
-- character-keyed table would keep the old entry (and its Highlight) alive forever
local highlights = setmetatable({}, {__mode = 'k'})

local function clearHighlights()
	for _, record in highlights do
		record.Highlight:Destroy()
	end

	table.clear(highlights)
end

local function updateHighlightColor()
	local color = Color3.fromHSV(DownedColor.Hue, DownedColor.Sat, DownedColor.Value)

	for _, record in highlights do
		record.Highlight.FillColor = color
		record.Highlight.OutlineColor = color
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
				local record = highlights[plr]
				local downed = character ~= nil and character ~= localCharacter and sentence.isDowned(plr)

				-- the body is gone, the player is no longer downed, or this is a respawn
				if record and (not downed or record.Character ~= character) then
					record.Highlight:Destroy()
					highlights[plr] = nil
					record = nil
				end

				if downed and not record then
					local color = Color3.fromHSV(DownedColor.Hue, DownedColor.Sat, DownedColor.Value)
					local highlight = Instance.new('Highlight')
					highlight.FillColor = color
					highlight.FillTransparency = 0.65
					highlight.OutlineColor = color
					highlight.OutlineTransparency = 0
					highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
					highlight.Adornee = character
					highlight.Parent = character
					highlights[plr] = {Character = character, Highlight = highlight}
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
