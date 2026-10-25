-- A [C] at the end of every line in the developer console (F9). Pressing one copies
-- that line, flips to [√] and goes back to [C] after 2.5s.
--
-- The mark is its own button and the row text is never touched, so there is nothing
-- to strip: what lands on the clipboard is exactly what the console printed.
--
-- The console lives at
--   CoreGui.DevConsoleMaster.DevConsoleWindow.DevConsoleUI.MainView.ClientLog
-- and every entry in ClientLog holds the text row as `msg`. Both are version
-- dependent, so the path is tried first and the printed line itself is the fallback.
local ConsoleCopy
local ColorV

-- every executor names this differently
local setclipboard = setclipboard or (syn and syn.write_clipboard) or (clipboard and clipboard.set) or toclipboard
local LogService = game:GetService('LogService')
local CoreGui = game:GetService('CoreGui')

local IDLE, DONE = '[C]', '[√]'
local RESET_AFTER = 2.5
local MAX_REMEMBERED = 150

-- what LogService has printed, so a row can be recognised even when the console's
-- own container is not where we expect it
local remembered = {}
local rememberedOrder = {}
-- [mark button] = the line it copies, [row] = its mark
local originals = {}
local marks = {}
local connections = {}

local enabled = false
local view
local markerColor = Color3.fromRGB(110, 200, 255)

local function remember(message)
	if type(message) ~= 'string' or message == '' or remembered[message] then return end

	remembered[message] = true
	table.insert(rememberedOrder, message)

	if #rememberedOrder > MAX_REMEMBERED then
		remembered[table.remove(rememberedOrder, 1)] = nil
	end
end

local function copy(mark)
	local line = originals[mark]
	if not line or not mark.Parent then return end

	if setclipboard then
		pcall(setclipboard, line)
	end

	mark.Text = DONE
	mark.TextColor3 = Color3.fromRGB(120, 255, 130)

	task.delay(RESET_AFTER, function()
		if not mark.Parent then return end

		mark.Text = IDLE
		mark.TextColor3 = markerColor
	end)
end

local function forget(row)
	local mark = marks[row]
	if not mark then return end

	marks[row] = nil
	originals[mark] = nil
	pcall(function()
		mark:Destroy()
	end)
end

local function decorate(row)
	if not row:IsA('TextLabel') and not row:IsA('TextButton') then return end
	if row.Name == 'ConsoleCopyMark' or marks[row] then return end

	local text = row.Text
	if text == '' then return end

	if view then
		if not row:IsDescendantOf(view) then return end
	elseif not remembered[text] then
		-- outside the console we only touch lines we saw LogService print
		return
	end

	local mark = Instance.new('TextButton')
	mark.Name = 'ConsoleCopyMark'
	mark.BackgroundTransparency = 1
	mark.AutoButtonColor = false
	mark.Text = IDLE
	mark.TextColor3 = markerColor
	mark.TextSize = row.TextSize > 0 and row.TextSize or 14
	mark.Font = row.Font
	mark.TextXAlignment = Enum.TextXAlignment.Right
	mark.Size = UDim2.new(0, 30, 1, 0)
	mark.Position = UDim2.new(1, -30, 0, 0)
	mark.ZIndex = (row.ZIndex or 1) + 2
	mark.Parent = row

	marks[row] = mark
	originals[mark] = text

	table.insert(connections, mark.MouseButton1Click:Connect(function()
		copy(mark)
	end))

	-- rows are recycled while the console scrolls, so the line under the mark changes
	table.insert(connections, row:GetPropertyChangedSignal('Text'):Connect(function()
		if marks[row] == mark then
			originals[mark] = row.Text
		end
	end))
end

-- rows destroyed by the console (closed, or scrolled out) leave dead entries behind
local function sweep()
	for row, mark in marks do
		if not row.Parent or not mark.Parent then
			forget(row)
		end
	end
end

local function scan(root)
	sweep()

	for _, row in root:GetDescendants() do
		pcall(decorate, row)
	end
end

-- the console body, or nil when this roblox build names it differently
local function viewOf(master)
	local window = master:FindFirstChild('DevConsoleWindow')
	local ui = window and window:FindFirstChild('DevConsoleUI')
	local main = ui and ui:FindFirstChild('MainView')

	return main
end

local function attach()
	for _, child in CoreGui:GetChildren() do
		if child.Name ~= 'DevConsoleMaster' then continue end

		view = viewOf(child)
		if view then
			scan(view)
		else
			scan(child)
		end

		return
	end
end

local function stop()
	enabled = false
	view = nil

	for _, connection in connections do
		pcall(function()
			connection:Disconnect()
		end)
	end

	table.clear(connections)

	for row in marks do
		forget(row)
	end

	table.clear(marks)
	table.clear(originals)
	table.clear(remembered)
	table.clear(rememberedOrder)
end

ConsoleCopy = vape.Legit:CreateModule({
	Name = 'ConsoleCopy',
	Function = function(callback)
		if callback then
			enabled = true

			table.insert(connections, LogService.MessageOut:Connect(function(message)
				remember(message)
			end))

			table.insert(connections, CoreGui.DescendantAdded:Connect(function(row)
				pcall(decorate, row)
			end))

			-- the window is only built the first time F9 is pressed
			table.insert(connections, CoreGui.ChildAdded:Connect(function(child)
				if child.Name == 'DevConsoleMaster' then attach() end
			end))

			attach()

			-- a recycled row never fires DescendantAdded, so the ones already on
			-- screen are picked up here instead
			task.spawn(function()
				while enabled do
					task.wait(1.5)

					if view then
						pcall(scan, view)
					end
				end
			end)
		else
			stop()
		end
	end,
	Tooltip = 'Adds a [C] to every developer console line — press it to copy that line.'
})
ColorV = ConsoleCopy:CreateColorSlider({
	Name = 'Mark color',
	DefaultHue = 0.55,
	Function = function(hue, sat, val)
		markerColor = Color3.fromHSV(hue, sat, val)

		for _, mark in marks do
			mark.TextColor3 = mark.Text == DONE and Color3.fromRGB(120, 255, 130) or markerColor
		end
	end
})
