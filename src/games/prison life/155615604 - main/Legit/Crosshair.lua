local Crosshair
local Image
local old

local function setImage(value)
	local equip = oldequip or pl.Equip
	if not equip then return end

	value = value or ''
	debug.setconstant(equip, 30, value:find('rbxasset', 1, true) and value or isfile(value) and getcustomasset(value) or '')
end

Crosshair = vape.Legit:CreateModule({
	Name = 'Crosshair',
	Function = function(callback)
		if callback then
			if not old and debug.getconstant then
				local success, value = pcall(debug.getconstant, oldequip or pl.Equip, 30)
				old = success and type(value) == 'string' and value or nil
			end

			setImage(Image.Value)
		else
			setImage(old or 'rbxassetid://98794608762931')
		end
	end,
	Tooltip = 'Change the crosshair icon'
})
Image = Crosshair:CreateTextBox({
	Name = 'Image',
	Placeholder = 'assetid',
	Function = function()
		if Crosshair.Enabled then
			setImage(Image.Value)
		end
	end
})
