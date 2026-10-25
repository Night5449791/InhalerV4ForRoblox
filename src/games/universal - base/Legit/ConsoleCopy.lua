-- A [C] at the end of every line in the developer console (F9). Pressing the line
-- copies it, flips the mark to [√] and goes back to [C] after 2.5s.
--
-- The mark is appended to the line itself, so it sits right after the log instead of
-- floating over it — and it is only ever display text: the clipboard always gets the
-- clean message, never the [C] / [√] we added.
--
-- The console lives at
--   CoreGui.DevConsoleMaster.DevConsoleWindow.DevConsoleUI.MainView.ClientLog
-- and every entry in ClientLog holds the text row as `msg`. Both are version
-- dependent. DevConsoleMaster itself persists in CoreGui once the console has been
-- opened (it just sits hidden), so the marks are attached to it as soon as it exists
-- — whether or not F9 is pressed afterwards — and the printed line is only the
-- fallback when that screen is not where we expect it.
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
-- [row] = its mark (the row itself for clickable rows, a catcher for labels),
-- [row] = the clean message it copies
local originals = {}
local marks = {}
local connections = {}

local enabled = false
local console
local view

local function remember(message)
	if type(message) ~= 'string' or message == '' or remembered[message] then return end

	remembered[message] = true
	table.insert(rememberedOrder, message)

	if #rememberedOrder > MAX_REMEMBERED then
		remembered[table.remove(rememberedOrder, 1)] = nil
	end
end

local function forget(row)
	local mark = marks[row]
	local original = originals[row]

	marks[row] = nil
	originals[row] = nil

	pcall(function()
		-- a catcher we made lives inside the row; the row itself was only retexted
		if mark and mark ~= row then
			mark:Destroy()
		end

		if original ~= nil and row.Parent then
			row.Text = original
		end
	end)
end

local function decorate(row)
	if not row:IsA('TextLabel') and not row:IsA('TextButton') then return end
	if row.Name == 'ConsoleCopyMark' or marks[row] then return end

	-- the timestamp / icon cells next to a log line are not the message; leave them be
	if row.Name == 'Timestamp' or row.Name == 'TimestampLabel' or row.Name == 'icon' or row.Name == 'Icon' then
		return
	end

	local text = row.Text
	if text == '' then return end

	-- once the console screen exists, mark every line in it; before it does, only
	-- lines we watched LogService print (so we never touch unrelated CoreGui labels)
	local container = view or console
	if container then
		if not row:IsDescendantOf(container) then return end
	elseif not remembered[text] then
		return
	end

	-- the marker is appended to the line, right after the log, not floating on top of
	-- it. the clipboard gets `text`, the clean message, regardless of the marker.
	local originalColor = row.TextColor3
	row.Text = text .. '  ' .. IDLE

	local function press()
		if setclipboard then
			pcall(setclipboard, text)
		end

		row.Text = text .. '  ' .. DONE
		row.TextColor3 = Color3.fromRGB(120, 255, 130)

		task.delay(RESET_AFTER, function()
			if not row.Parent then return end

			row.Text = text .. '  ' .. IDLE
			row.TextColor3 = originalColor
		end)
	end

	if row:IsA('TextButton') then
		-- the console row already takes a click (to expand it); ours runs alongside
		marks[row] = row
		table.insert(connections, row.MouseButton1Click:Connect(press))
	else
		-- a label cannot be clicked, so drop a transparent catcher over the row
		local catcher = Instance.new('TextButton')
		catcher.Name = 'ConsoleCopyMark'
		catcher.BackgroundTransparency = 1
		catcher.Text = ''
		catcher.AutoButtonColor = false
		catcher.Size = UDim2.fromScale(1, 1)
		catcher.ZIndex = (row.ZIndex or 1) + 2
		catcher.Parent = row
		catcher.MouseButton1Click:Connect(press)
		marks[row] = catcher
	end

	originals[row] = text

	-- rows are recycled while the console scrolls, so the line under the mark changes
	-- and we re-append the marker to whatever the console just put there
	table.insert(connections, row:GetPropertyChangedSignal('Text'):Connect(function()
		if row.Text:sub(-5) == '  ' .. IDLE or row.Text:sub(-5) == '  ' .. DONE then
			return
		end

		text = row.Text
		originals[row] = text
		row.Text = text .. '  ' .. IDLE
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

-- the console body, or nil when this roblox build names it differently. ClientLog is
-- the scroll of log lines; falling back to MainView keeps the marks working when the
-- inner name is not what we expect, and away from the tab/tool bar
local function viewOf(master)
	local window = master:FindFirstChild('DevConsoleWindow')
	local ui = window and window:FindFirstChild('DevConsoleUI')
	local main = ui and ui:FindFirstChild('MainView')

	local log = main and (main:FindFirstChild('ClientLog') or main:FindFirstChild('LogView') or main:FindFirstChild('Log'))

	return log or main
end

local function attach()
	for _, child in CoreGui:GetChildren() do
		if child.Name ~= 'DevConsoleMaster' then continue end

		-- anchor to the whole screen so the marks survive even when MainView is named
		-- differently in this roblox build; view is only a tighter scan target
		console = child
		view = viewOf(child)
		scan(view or console)

		return
	end
end

local function stop()
	enabled = false
	view = nil
	console = nil

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

			-- rows are recycled without firing DescendantAdded, the console screen can
			-- appear late, and some builds rebuild it on open — so keep attaching and
			-- re-scanning until the module is switched off
			task.spawn(function()
				while enabled do
					task.wait(1.5)

					if not console then
						attach()
					end

					local root = view or console
					if root then
						pcall(scan, root)
					end
				end
			end)
		else
			stop()
		end
	end,
	Tooltip = 'Adds a [C] to every developer console line — click the line to copy it.'
})
