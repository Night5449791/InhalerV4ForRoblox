local Crosshair
local Image
local original

local DEFAULT_IMAGE = 'rbxassetid://98794608762931'

local function resolveImage(value)
	if not value or value == '' then
		return ''
	end

	if value:find('rbxasset', 1, true) then
		return value
	end

	return isfile(value) and getcustomasset(value) or ''
end

local function setImage(image)
	local equip = oldequip or pl.Equip
	if equip then
		debug.setconstant(equip, 30, image)
	end
end

local function getImage()
	local equip = oldequip or pl.Equip
	if equip and debug.getconstant then
		local success, value = pcall(debug.getconstant, equip, 30)
		if success and type(value) == 'string' then
			return value
		end
	end
end

Crosshair = vape.Legit:CreateModule({
	Name = 'Crosshair',
	Function = function(callback)
		if callback then
			original = original or getImage()

			setImage(resolveImage(Image.Value))
		else
			setImage(original or DEFAULT_IMAGE)
		end
	end,
	Tooltip = 'Change the crosshair icon'
})
Image = Crosshair:CreateTextBox({
	Name = 'Image',
	Placeholder = 'assetid',
	Function = function()
		if Crosshair.Enabled then
			setImage(resolveImage(Image.Value))
		end
	end
})
