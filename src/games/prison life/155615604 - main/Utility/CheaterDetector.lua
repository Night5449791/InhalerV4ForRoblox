-- cheaters are stored locally in newvape/cheaters.json

local CheaterDetector
local DB_VERSION = 2
local cheaterOptions = {}
local filePath = 'newvape/cheaters.json'
local backupPath = 'newvape/cheaters.json.bak'
local brokenPath = 'newvape/cheaters.json.broken'
local Cheaters = {Version = DB_VERSION, Names = {}, Users = {}, Count = 0}
local httpService = cloneref(game:GetService('HttpService'))
local TAG_COLOR = Color3.new(1, 0, 0)

local function countCheaters(names, users)
	local count = 0

	for _ in names do
		count += 1
	end

	for _ in users do
		count += 1
	end

	return count
end

local function trimText(text)
	return text and text:match('^%s*(.-)%s*$') or nil
end

local function ensureFolder()
	if not isfolder('newvape') then
		pcall(makefolder, 'newvape')
	end
end

-- vape.Notifications only exists once the gui is loaded, this file runs before that
local function notify(text, duration, type)
	if vape.Notifications then
		notif('CheaterDetector', text, duration, type)
	end
end

local function saveCheaters()
	ensureFolder()

	-- derived, never trust a stale count from disk
	Cheaters.Count = countCheaters(Cheaters.Names, Cheaters.Users)

	local encoded, content = pcall(function()
		return httpService:JSONEncode(Cheaters)
	end)

	if not encoded then
		return notify('Failed to encode: '..tostring(content), 15, 'warning')
	end

	local written, err = pcall(writefile, filePath, content)
	if not written then
		notify('Failed to write '..filePath..' ('..tostring(err)..')', 15, 'warning')
		return
	end

	-- mirror only once the live file is known good, so a later truncated write
	-- can always be rolled back to this snapshot
	pcall(writefile, backupPath, content)
end

-- an outdated database only needs the current version stamped on it, every
-- derived field (Count) is rebuilt by saveCheaters anyway
local function upgradeCheaters(data)
	data.Version = DB_VERSION
end

-- returns the decoded table plus the raw text it came from, the raw text is
-- handed back on failure so the caller can still preserve it
local function readDatabase(path)
	if not isfile(path) then return end

	local read, content = pcall(readfile, path)
	if not read or type(content) ~= 'string' then return end

	local decoded, data = pcall(function()
		return httpService:JSONDecode(content)
	end)

	if not decoded or type(data) ~= 'table' then
		return nil, content
	end

	return data, content
end

-- never overwrite data we failed to read, keep a copy for manual recovery
local function quarantineDatabase(content)
	if not content then return end

	ensureFolder()
	pcall(writefile, brokenPath, content)
end

local function loadCheaters()
	local data, content = readDatabase(filePath)
	local restored = false

	if not data then
		-- unreadable, keep a copy of it and fall back to the last good snapshot
		if content then
			quarantineDatabase(content)
			notify('Cheater database is unreadable, a copy was kept at '..brokenPath, 15, 'warning')
		end

		data = readDatabase(backupPath)
		if data then
			restored = true
			notify('Restored the cheater database from backup.', 15, 'warning')
		end
	end

	if not data then
		-- nothing left to recover, start clean, a broken copy was kept above
		return saveCheaters()
	end

	local version = type(data.Version) == 'number' and data.Version or 1
	local upgraded = false

	if version > DB_VERSION then
		-- written by a newer script, do not rewrite it and drop unknown fields
		Cheaters.Version = version
		notify('Cheater database is newer (v'..version..') than this script (v'..DB_VERSION..'), using it as is.', 15, 'warning')
	else
		if version < DB_VERSION then
			upgradeCheaters(data)
			upgraded = true
		end

		Cheaters.Version = data.Version
	end

	Cheaters.Names = type(data.Names) == 'table' and data.Names or {}
	Cheaters.Users = type(data.Users) == 'table' and data.Users or {}
	Cheaters.Count = countCheaters(Cheaters.Names, Cheaters.Users)

	if upgraded then
		saveCheaters()
		notify('Upgraded cheater database to v'..DB_VERSION..'.', 10)
	elseif restored then
		saveCheaters() -- write the recovered data back over the broken file
	elseif content and not isfile(backupPath) then
		pcall(writefile, backupPath, content) -- seed the backup on first run
	end
end

-- a reason of nil removes the tag instead
local function tagCheater(plr, reason, alert)
	whitelist.customtags[plr.Name] = reason and {{text = 'Exploiter', color = TAG_COLOR}} or nil
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

-- ".addskid <display name> <reason>" - display names can contain spaces, so the
-- longest match against an online player wins and whatever follows is the reason.
-- the players are lowered once here instead of once per candidate name
local function splitCheaterText(text)
	local words = {}
	for word in text:gmatch('%S+') do
		table.insert(words, word)
	end

	if #words == 0 then return end

	local entries = {}
	for _, plr in playersService:GetPlayers() do
		table.insert(entries, {plr, plr.Name:lower(), plr.DisplayName:lower()})
	end

	for i = #words, 1, -1 do
		local name = table.concat(words, ' ', 1, i)
		local rest = table.concat(words, ' ', i + 1)
		local lowered = name:lower()
		local partial

		for _, entry in entries do
			if entry[2] == lowered or entry[3] == lowered then
				return entry[1], rest, name
			end

			if not partial and (entry[2]:sub(1, #lowered) == lowered or entry[3]:sub(1, #lowered) == lowered) then
				partial = entry[1]
			end
		end

		-- only fall back to a partial match once the whole server was checked
		if partial then
			return partial, rest, name
		end
	end

	-- nobody online matches, the first word is the name and the rest the reason
	return nil, table.concat(words, ' ', 2), words[1]
end

-- remove = true drops the player, otherwise they get added with the given reason
local function editCheater(text, reason, remove)
	text = trimText(text)
	if not text or text == '' then return notify('No player given.', 8, 'warning') end

	-- splitCheaterText always hands a name back once text is not empty
	local plr, rest, name = splitCheaterText(text)

	-- a removal has no reason, that is what untags the player
	if remove then
		reason = nil
	else
		local given = trimText(reason)
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
				playerAdded(v)
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
