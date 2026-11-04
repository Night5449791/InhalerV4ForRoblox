uipallet = {
	Main = Color3.fromRGB(26, 25, 26),
	Text = Color3.fromRGB(200, 200, 200),
	Font = Font.fromEnum(Enum.Font.Arial),
	FontSemiBold = Font.fromEnum(Enum.Font.Arial, Enum.FontWeight.SemiBold),
	Tween = TweenInfo.new(0.15, Enum.EasingStyle.Linear)
}

do
	local data = isfile('newvape/profiles/color.txt') and loadJson('newvape/profiles/color.txt')
	if data then
		uipallet.Main = data.Main and Color3.fromRGB(unpack(data.Main)) or uipallet.Main
		uipallet.Text = data.Text and Color3.fromRGB(unpack(data.Text)) or uipallet.Text
		if data.Font then
			local success, font = pcall(Font.new,
				data.Font:find('rbxasset') and data.Font
				or string.format('rbxasset://fonts/families/%s.json', data.Font)
			)

			if success then
				uipallet.Font = font
			end
		end

		local success, font = pcall(Font.new, uipallet.Font.Family, Enum.FontWeight.SemiBold)
		if success then
			uipallet.FontSemiBold = font
		end
	end

	fontsize.Font = uipallet.Font
end