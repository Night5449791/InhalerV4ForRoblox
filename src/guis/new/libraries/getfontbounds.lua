local function getfontbounds(text, size, font)
	fontsize.Text = text
	fontsize.Size = size
	fontsize.Font = typeof(font) == 'Font' and font or uipallet.Font

	local success, bounds = pcall(function()
		return textService:GetTextBoundsAsync(fontsize)
	end)

	fontsize.Font = uipallet.Font
	return success and bounds or Vector2.zero
end
