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

	local current = part.LocalTransparencyModifier
	if current ~= 0 then
		originals[part] = current
	end

	modified[part] = true
	part.LocalTransparencyModifier = 0.5
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
