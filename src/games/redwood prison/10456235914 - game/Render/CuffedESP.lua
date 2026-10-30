local CuffedESP
local Color
local ColorTeam
local highlights = {}

local function removeHighlight(character)
	local highlight = highlights[character]
	if highlight then
		highlight:Destroy()
		highlights[character] = nil
	end
end

local function clearHighlights()
	for character in highlights do
		removeHighlight(character)
	end
	table.clear(highlights)
end

local function highlightColor(character)
	if ColorTeam.Enabled then
		local plr = playersService:GetPlayerFromCharacter(character)
		local team = plr and plr.Team
		if team then return team.TeamColor.Color end
	end

	return Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
end

local function updateColor()
	for character, highlight in highlights do
		local color = highlightColor(character)
		highlight.FillColor = color
		highlight.OutlineColor = color
	end
end

CuffedESP = vape.Categories.Render:CreateModule({
	Name = 'CuffedESP',
	Function = function(callback)
		clearHighlights()

		if not callback then return end

		-- characters that die or respawn leave the world without notifying us, so the
		-- per character highlight is dropped as soon as its adornee is gone
		local removed = workspace.ChildRemoved:Connect(function(child)
			removeHighlight(child)
		end)

		repeat
			for _, plr in playersService:GetPlayers() do
				local character = plr.Character
				if character and character ~= lplr.Character then
					local humanoid = redwood.humanoid(character)
					local alive = humanoid and humanoid.Health > 0
					local cuffed = alive and redwood.hasState(character, 'Handcuffed_')
					local highlight = highlights[character]

					if cuffed and not highlight then
						highlight = Instance.new('Highlight')
						local color = highlightColor(character)
						highlight.FillColor = color
						highlight.FillTransparency = 0.65
						highlight.OutlineColor = color
						highlight.OutlineTransparency = 0
						highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
						highlight.Adornee = character
						highlight.Parent = character
						highlights[character] = highlight
					elseif not cuffed and highlight then
						removeHighlight(character)
					elseif highlight then
						local color = highlightColor(character)
						highlight.FillColor = color
						highlight.OutlineColor = color
					end
				end
			end

			for character in highlights do
				local plr = playersService:GetPlayerFromCharacter(character)
				if not plr or plr.Character ~= character then
					removeHighlight(character)
				end
			end

			task.wait(0.5)
		until not CuffedESP.Enabled or vape.Loaded == nil

		removed:Disconnect()
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
ColorTeam = CuffedESP:CreateToggle({
	Name = 'Use team color',
	Tooltip = 'Tints the highlight with the cuffed player team colour'
})
