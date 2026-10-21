local Xray
local List
local modified = setmetatable({}, {
	__mode = 'k'
})
local originals = setmetatable({}, {
	__mode = 'k'
})
local skip = {}
local scanToken = 0

-- the part-name list is checked for every descendant added, so it is turned into a hash set
-- instead of a linear table.find scan; rebuilt whenever the module is toggled on
local function rebuildSkip()
	table.clear(skip)
	for _, name in List.ListEnabled do
		skip[name] = true
	end
end

local function modifyPart(part)
	-- a part is only ever recorded once; a reparent re-fires DescendantAdded and re-writing the
	-- same property on every one of those would be wasted work
	if modified[part] then return end

	-- remember a non-zero modifier so disabling restores it instead of flattening it to 0
	local current = part.LocalTransparencyModifier
	if current ~= 0 then
		originals[part] = current
	end

	modified[part] = true
	part.LocalTransparencyModifier = 0.5
end

-- sweeping every BasePart of a large map in one frame hitches, so the sweep is spread over
-- frames and cancelled through the token when the module is toggled off mid-sweep
local function startScan()
	scanToken = scanToken + 1
	local token = scanToken

	task.spawn(function()
		local parts = workspace:QueryDescendants('BasePart')
		for index = 1, #parts do
			if scanToken ~= token then return end

			local part = parts[index]
			if not skip[part.Name] then
				modifyPart(part)
			end

			if index % 250 == 0 then
				task.wait()
			end
		end
	end)
end

Xray = vape.Categories.World:CreateModule({
	Name = 'Xray',
	Function = function(callback)
		if callback then
			rebuildSkip()
			Xray:Clean(workspace.DescendantAdded:Connect(function(part)
				if part:IsA('BasePart') and not skip[part.Name] then
					modifyPart(part)
				end
			end))

			startScan()
		else
			scanToken = scanToken + 1

			for part in modified do
				part.LocalTransparencyModifier = originals[part] or 0
			end

			table.clear(modified)
			table.clear(originals)
		end
	end,
	Tooltip = 'Renders whitelisted parts through walls.'
})
List = Xray:CreateTextList({
	Name = 'Part',
	Function = function()
		if Xray.Enabled then
			Xray:Toggle()
			Xray:Toggle()
		end
	end
})
