-- cheaters are stored locally in newvape/cheaters.json
-- the list starts empty and is user managed

local CheaterDetector
local cheaterOptions = {}
local filePath = 'newvape/cheaters.json'
local Cheaters = {Names = {}, Users = {}}
local httpService = cloneref(game:GetService('HttpService'))

local function trimText(text)
	return text and text:match('^%s*(.-)%s*$') or nil
end

-- vape.Notifications only exists once the gui is loaded, this file runs before that
local function notify(text, duration, type)
	if vape.Notifications then
		notif('CheaterDetector', text, duration, type)
	end
end

local function saveCheaters()
	if not isfolder('newvape') then
		pcall(makefolder, 'newvape')
	end

	local encoded, content = pcall(function()
		return httpService:JSONEncode(Cheaters)
	end)

	if not encoded then
		return notify('Failed to encode: '..tostring(content), 15, 'warning')
	end

	local written, err = pcall(writefile, filePath, content)
	if not written then
		notify('Failed to write '..filePath..' ('..tostring(err)..')', 15, 'warning')
	end
end

local function loadCheaters()
	if not isfile(filePath) then
		return saveCheaters() -- creates the file on first run
	end

	local decoded, data = pcall(function()
		return httpService:JSONDecode(readfile(filePath))
	end)

	if not decoded or type(data) ~= 'table' then
		return saveCheaters()
	end

	Cheaters.Names = type(data.Names) == 'table' and data.Names or {}
	Cheaters.Users = type(data.Users) == 'table' and data.Users or {}
end

-- a reason of nil removes the tag instead
local function tagCheater(plr, reason, alert)
	whitelist.customtags[plr.Name] = reason and {{text = 'Exploiter', color = Color3.new(1, 0, 0)}} or nil
	tempTargets[plr.Name] = reason and true or nil

	if reason and alert and cheaterOptions.Notifications.Enabled then
		notify('Cheater Detected ('..reason..'): '..plr.DisplayName, 60, 'alert')
	end
end

local function getCheaterReason(plr)
	local user = Cheaters.Users[tostring(plr.UserId)]
	if user then
		return user.Reason or 'known cheater'
	end

	return Cheaters.Names[plr.Name:lower()] or Cheaters.Names[plr.DisplayName:lower()]
end

local function findCheaterPlayer(text)
	text = text and text:lower()
	if not text or text == '' then return end

	local partial
	for _, plr in playersService:GetPlayers() do
		if plr.Name:lower() == text or plr.DisplayName:lower() == text then return plr end

		if not partial and (plr.Name:lower():sub(1, #text) == text or plr.DisplayName:lower():sub(1, #text) == text) then
			partial = plr
		end
	end

	return partial
end

-- ".addskid <display name> <reason>" - display names can contain spaces, so the
-- longest match against an online player wins and whatever follows is the reason
local function splitCheaterText(text)
	local words = {}
	for word in text:gmatch('%S+') do
		table.insert(words, word)
	end

	if #words == 0 then return end

	for i = #words, 1, -1 do
		local name = table.concat(words, ' ', 1, i)
		local plr = findCheaterPlayer(name)
		if plr then
			return plr, table.concat(words, ' ', i + 1), name
		end
	end

	-- nobody online matches, the first word is the name and the rest the reason
	return nil, table.concat(words, ' ', 2), words[1]
end

-- remove = true drops the player, otherwise they get added with the given reason
local function editCheater(text, reason, remove)
	text = trimText(text)
	if not text or text == '' then return notify('No player given.', 8, 'warning') end

	local plr, rest, name = splitCheaterText(text)
	if not name then return notify('No player given.', 8, 'warning') end

	-- a removal has no reason, that is what untags the player
	local given = trimText(reason)
	if remove then
		reason = nil
	else
		reason = (given and given ~= '' and given) or (rest and rest ~= '' and rest) or 'manually added'
	end

	if plr then
		Cheaters.Users[tostring(plr.UserId)] = not remove and {
			Name = plr.Name,
			DisplayName = plr.DisplayName,
			Reason = reason,
			Time = os.time()
		} or nil
		Cheaters.Names[plr.Name:lower()] = nil
		Cheaters.Names[plr.DisplayName:lower()] = nil
		tagCheater(plr, reason)
	else
		Cheaters.Names[name:lower()] = not remove and reason or nil
	end

	saveCheaters()
	notify((plr and plr.DisplayName or name)..(remove and ' removed from the cheater list.' or ' added to the cheater list. ('..reason..')'), 10)
end

local function playerAdded(plr)
	if plr == lplr then return end

	local reason = getCheaterReason(plr)
	if reason then
		tagCheater(plr, reason, true)
	end
end

loadCheaters()

CheaterDetector = vape.Categories.Utility:CreateModule({
	Name = 'CheaterDetector',
	Function = function(callback)
		if callback then
			CheaterDetector:Clean(playersService.PlayerAdded:Connect(playerAdded))
			for _, v in playersService:GetPlayers() do
				task.spawn(playerAdded, v)
			end
		end
	end,
	Tooltip = 'Detects people with history of cheating\nCheaters are stored in '..filePath
})

function CheaterDetector:AddCheater(text, reason)
	editCheater(text, reason)
end

function CheaterDetector:RemoveCheater(text)
	editCheater(text, nil, true)
end

cheaterOptions.Notifications = CheaterDetector:CreateToggle({
	Name = 'Notifications',
	Default = true,
	Tooltip = 'Notifies you when a known cheater joins'
})

local addBox
addBox = CheaterDetector:CreateTextBox({
	Name = 'Add cheater',
	Placeholder = 'DisplayName',
	Player = true,
	Tooltip = 'Adds a player to the local cheater list\n"DisplayName reason"',
	Function = function(enter)
		if not enter then return end

		local text = addBox.Value
		addBox:SetValue('')
		editCheater(text)
	end
})

CheaterDetector:CreateButton({
	Name = 'Clear cheater list',
	Tooltip = 'Removes every locally stored cheater',
	Function = function()
		for _, plr in playersService:GetPlayers() do
			tagCheater(plr)
		end

		table.clear(Cheaters.Names)
		table.clear(Cheaters.Users)
		saveCheaters()
		notify('Cleared the cheater list.', 10)
	end
})
