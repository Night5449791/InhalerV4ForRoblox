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

local function rebuildSkip()
	table.clear(skip)
	for _, name in List.ListEnabled do
		skip[name] = true
	end
end

local function modifyPart(part)
	if modified[part] then return end

	originals[part] = part.LocalTransparencyModifier
	modified[part] = true
	part.LocalTransparencyModifier = 0.5
end

local function restoreParts()
	for part, value in originals do
		if part.Parent then
			part.LocalTransparencyModifier = value
		end
	end

	table.clear(modified)
	table.clear(originals)
end

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
			restoreParts()
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
