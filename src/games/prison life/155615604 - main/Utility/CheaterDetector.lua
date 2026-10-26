local CheaterDetector
local webhookUrl
local whitelist = vape.Libraries.whitelist
local jsonEncode, jsonDecode = httpService.JSONEncode, httpService.JSONDecode
local osDate, osTime = os.date, os.time
local DB_VERSION = 3
local cheaterOptions = {}
local filePath = 'newvape/cheaters.json'
local backupPath = 'newvape/cheaters.json.bak'
local brokenPath = 'newvape/cheaters.json.broken'
local Cheaters = {Version = DB_VERSION, Names = {}, Users = {}, Count = 0}
-- the global list the owner's client uploads to the backend. it is read-only here: a
-- local edit must not rewrite somebody else's entry, and "Clear cheater list" must
-- leave it alone, so it lives in its own two maps instead of inside Cheaters
local Remote = {Users = {}, Names = {}}
local remoteRevision = -1
local remoteEnabled = true
local remoteTagged = {}
local moduleEnabled = false
local TAG_COLOR = Color3.new(1, 0, 0)
local EMBED_RED = 15548997
local EMBED_GREEN = 5763911
-- the name discord shows as the poster; the adder is still in the "Added By" field
local WEBHOOK_NAME = 'Inhaler CheaterDetector'

local function countCheaters(names, users)
	local count = 0
	for _ in names do count += 1 end
	for _ in users do count += 1 end
	return count
end

local function trimText(text)
	return text and text:match('^%s*(.-)%s*$') or nil
end

local function isWhitelisted(plr)
	return select(1, whitelist:get(plr)) ~= 0
end

-- vape.Notifications only exists once the gui is loaded, this file runs before that
local function notify(text, duration, type)
	if vape.Notifications then
		notif('CheaterDetector', text, duration, type)
	end
end

local function saveCheaters()
	Cheaters.Count = countCheaters(Cheaters.Names, Cheaters.Users)

	local encoded, content = pcall(jsonEncode, httpService, Cheaters)
	if not encoded then
		return notify('Failed to encode: '..tostring(content), 15, 'warning')
	end

	local written, err = pcall(writefile, filePath, content)
	if not written then
		return notify('Failed to write '..filePath..' ('..tostring(err)..')', 15, 'warning')
	end

	pcall(writefile, backupPath, content)
end

local function readDatabase(path)
	if not isfile(path) then return end

	local read, content = pcall(readfile, path)
	if not read or type(content) ~= 'string' then return end

	local decoded, data = pcall(jsonDecode, httpService, content)
	if not decoded or type(data) ~= 'table' then
		return nil, content
	end

	return data, content
end

local function loadCheaters()
	local data, content = readDatabase(filePath)
	local restored = false

	if not data then
		if content then
			pcall(writefile, brokenPath, content)
			notify('Cheater database is unreadable, a copy was kept at '..brokenPath, 15, 'warning')
		end

		data = readDatabase(backupPath)
		if data then
			restored = true
			notify('Restored the cheater database from backup.', 15, 'warning')
		end
	end

	if not data then return saveCheaters() end

	local version = type(data.Version) == 'number' and data.Version or 1
	local upgraded = false

	if version > DB_VERSION then
		Cheaters.Version = version
		notify('Cheater database is newer (v'..version..') than this script (v'..DB_VERSION..'), using it as is.', 15, 'warning')
	else
		if version < DB_VERSION then
			data.Version = DB_VERSION
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

local function tagCheater(plr, reason, alert, remote)
	whitelist.customtags[plr.Name] = reason and {{text = 'Exploiter', color = TAG_COLOR}} or nil
	tempTargets[plr.Name] = reason and true or nil
	-- remembered so a later refresh can take the tag back off when the entry leaves
	-- the global list, without touching a tag another module put on that player
	remoteTagged[plr.Name] = reason and remote and true or nil

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

local function getRemoteReason(plr)
	if not remoteEnabled then return end

	return Remote.Users[tostring(plr.UserId)]
		or Remote.Names[plr.Name:lower()]
		or Remote.Names[plr.DisplayName:lower()]
end

local function matchesNamePattern(value, pattern)
	value, pattern = value:lower(), pattern:lower()
	if not pattern:find('*', 1, true) then
		return value == pattern
	end

	return value:match('^'..pattern:gsub('([%^%$%(%)%%%.%[%]%+%-%?])', '%%%1'):gsub('%*', '.*')..'$') ~= nil
end

local function splitCheaterText(text)
	local words = {}
	for word in text:gmatch('%S+') do
		words[#words + 1] = word
	end

	if #words == 0 then return end

	local entries, exact = {}, {}
	for _, plr in playersService:GetPlayers() do
		local username, displayName = plr.Name:lower(), plr.DisplayName:lower()
		entries[#entries + 1] = {plr, username, displayName}
		exact[username] = exact[username] or plr
		exact[displayName] = exact[displayName] or plr
	end

	for i = #words, 1, -1 do
		local name = table.concat(words, ' ', 1, i)
		local lowered = name:lower()
		local hit = exact[lowered]

		if hit then
			return hit, table.concat(words, ' ', i + 1), name
		end

		-- the pattern is built once per prefix instead of once per online player
		local wildcard = lowered:find('*', 1, true)
			and '^'..lowered:gsub('([%^%$%(%)%%%.%[%]%+%-%?])', '%%%1'):gsub('%*', '.*')..'$'
		local partial, wildcardMatches

		for _, entry in entries do
			if wildcard and (entry[2]:match(wildcard) or entry[3]:match(wildcard)) then
				wildcardMatches = wildcardMatches or {}
				wildcardMatches[#wildcardMatches + 1] = entry[1]
			end

			if not partial and (entry[2]:sub(1, #lowered) == lowered or entry[3]:sub(1, #lowered) == lowered) then
				partial = entry[1]
			end
		end

		if wildcardMatches then
			return wildcardMatches[1], table.concat(words, ' ', i + 1), name, wildcardMatches
		end

		if partial then
			return partial, table.concat(words, ' ', i + 1), name
		end
	end

	if text:find('*', 1, true) then
		return nil, nil, text, {}
	end

	return nil, table.concat(words, ' ', 2), words[1]
end

local function sendWebhookLog(plr, name, reason, removed, previous)
	if not cheaterOptions.Webhook.Enabled then return end

	if not webhook then
		return notify('Webhook library is missing, cannot post the update.', 10, 'warning')
	end

	local url = trimText(webhookUrl and webhookUrl.Value)
	if not url or url == '' then
		return notify('Webhook is on but no url is set.', 10, 'warning')
	end

	local user = plr and plr.Name or name
	local display = plr and plr.DisplayName or name
	local id = plr and tostring(plr.UserId) or 'unknown'
	local fields = {}

	if removed then
		fields[1] = {name = 'Status', value = 'Removed from skidlist'}
		fields[2] = {name = 'Reason Was', value = previous or 'unknown'}
	else
		fields[1] = {name = '⚠️ Reason', value = '`'..(reason or 'manually added')..'`'}
	end

	fields[#fields + 1] = {name = 'Added By', value = lplr.Name, inline = true}
	fields[#fields + 1] = {name = 'Logged Date', value = osDate('%m/%d/%Y %H:%M:%S'), inline = true}

	task.spawn(function()
		local sent, err = webhook.sendEmbed(url, {
			title = removed and '✅ Skid Removed / Unflagged' or '🚨 Detected Skid Target',
			description = 'User: '..user..' (@'..display..')\nID: '..id,
			color = removed and EMBED_GREEN or EMBED_RED,
			fields = fields
		}, WEBHOOK_NAME)

		if not sent then
			notify('Webhook failed: '..tostring(err), 10, 'warning')
		end
	end)
end

local function editCheater(text, reason, remove)
	text = trimText(text)
	if not text or text == '' then
		return notify('No player given.', 8, 'warning')
	end

	local plr, rest, name, wildcardMatches = splitCheaterText(text)

	if wildcardMatches then
		local count = #wildcardMatches

		if count == 0 and not remove then
			return notify('No online players match that pattern.', 8, 'warning')
		end

		if count > 1 then
			if remove then
				local removed = 0
				for _, matched in wildcardMatches do
					if getCheaterReason(matched) ~= nil then
						editCheater(matched.Name, nil, true)
						removed += 1
					end
				end

				if removed == 0 then
					return notify('No matching players are on the cheater list.', 8, 'warning')
				end

				return
			end

			local addReason = trimText(reason) or (rest and rest ~= '' and rest) or 'manually added'
			for _, matched in wildcardMatches do
				editCheater(matched.Name, addReason, false)
			end
			return
		end
	end

	local onlineReason = plr and getCheaterReason(plr)

	-- a remove for someone who is not on the list falls back to the stored entries
	if remove and plr and not onlineReason then
		plr = nil
	end

	local storedUserId, storedUser

	if not plr then
		local matches = {}

		for userId, user in Cheaters.Users do
			if type(user) == 'table'
				and ((type(user.Name) == 'string' and matchesNamePattern(user.Name, name))
					or (type(user.DisplayName) == 'string' and matchesNamePattern(user.DisplayName, name))) then
				matches[#matches + 1] = {Id = tostring(userId), User = user}
			end
		end

		for storedName in Cheaters.Names do
			if matchesNamePattern(storedName, name) then
				matches[#matches + 1] = {Name = storedName}
			end
		end

		if remove and #matches > 1 then
			return notify('Pattern matches multiple cheater entries. Use a more specific name.', 10, 'warning')
		end

		local match = matches[1]
		storedUserId, storedUser = match and match.Id, match and match.User
		name = match and match.Name or (storedUser and (storedUser.Name or storedUser.DisplayName)) or name
	end

	local lowered = name:lower()
	local nameReason = not storedUserId and Cheaters.Names[lowered]
	local existing = onlineReason or (storedUser and (storedUser.Reason or 'known cheater')) or nameReason

	if not remove and existing then
		return notify((plr and plr.DisplayName or name)..' is already on the cheater list ('..existing..'), not added again.', 10, 'warning')
	end

	if remove and not (onlineReason ~= nil or storedUser ~= nil or nameReason ~= nil) then
		return notify((plr and plr.DisplayName or name)..' is not on the cheater list.', 8, 'warning')
	end

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
			Time = osTime()
		} or nil
		Cheaters.Names[plr.Name:lower()] = nil
		Cheaters.Names[plr.DisplayName:lower()] = nil
		tagCheater(plr, reason)
	elseif storedUserId then
		Cheaters.Users[storedUserId] = nil
	elseif remove then
		Cheaters.Names[lowered] = nil
	else
		Cheaters.Names[lowered] = reason
	end

	saveCheaters()
	sendWebhookLog(plr, name, reason, remove, existing)
	notify((plr and plr.DisplayName or name)..(remove and ' removed from the cheater list.' or ' added to the cheater list. ('..reason..')'), 10)
end

local function playerAdded(plr)
	if plr == lplr or isWhitelisted(plr) then return end

	local localReason = getCheaterReason(plr)
	local reason = localReason or getRemoteReason(plr)
	if reason then
		tagCheater(plr, reason, true, not localReason)
	end
end

-- the download lands in shared.inhalerSkidList; rebuilding these two maps is cheap,
-- re-tagging everyone is not, so it only runs when the revision actually moved
local function applyRemote(entries)
	table.clear(Remote.Users)
	table.clear(Remote.Names)

	for _, entry in entries do
		if type(entry) == 'table' then
			local reason = type(entry.r) == 'string' and entry.r or 'known cheater'
			local id = tostring(entry.i or '')

			if id:match('^%d+$') then
				Remote.Users[id] = reason
			end

			for _, name in {entry.u, entry.n} do
				if type(name) == 'string' and name ~= '' then
					Remote.Names[name:lower()] = reason
				end
			end
		end
	end
end

local function retagEveryone()
	for _, plr in playersService:GetPlayers() do
		if plr ~= lplr and not isWhitelisted(plr) then
			local localReason = getCheaterReason(plr)
			local reason = localReason or getRemoteReason(plr)

			if reason then
				-- an existing tag is left alone: it may belong to another module
				if not whitelist.customtags[plr.Name] then
					tagCheater(plr, reason, false, not localReason)
				end
			elseif remoteTagged[plr.Name] then
				-- it left the global list and was never local: only the tag this module
				-- put there is taken back off
				tagCheater(plr)
			end
		end
	end
end

local function syncRemote(force)
	local source = shared.inhalerSkidList
	if type(source) ~= 'table' then return end

	local revision = tonumber(source.rev) or 0
	if not force and revision == remoteRevision then return end
	remoteRevision = revision

	applyRemote(type(source.entries) == 'table' and source.entries or {})
	retagEveryone()
end

local function autoAddCheater(plr, flagType)
	if not cheaterOptions.AutomaticAdd.Enabled then return end
	if flagType ~= 'invalid animation' and flagType:sub(1, 13) ~= 'invalid state'
		and not (flagType == 'teleport' and cheaterOptions.Teleports.Enabled)
		and not (flagType == 'speed' and cheaterOptions.Speed.Enabled) then return end
	if plr == lplr or isWhitelisted(plr) or getCheaterReason(plr) then return end

	if cheaterOptions.KXAutoAdd.Value == 'KX compatible' then
		local message = '.addskid '..plr.DisplayName..' exploits/'..flagType..'(inhalerautoaddskid)'
		local sent, err = pcall(function()
			if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
				local channel = textChatService.ChatInputBarConfiguration.TargetTextChannel
				if not channel or not textChatService:CanUserChatAsync(lplr.UserId) then
					error('Chat is unavailable.')
				end
				channel:SendAsync(message)
			else
				replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(message, 'All')
			end
		end)
		if not sent then
			notify('KX-compatible chat add failed: '..tostring(err), 10, 'warning')
		end
		return
	end

	CheaterDetector:AddCheater(plr.Name, 'exploits/'..flagType)
end

loadCheaters()

-- the backend only downloads the global list for a game that asks for it, so every
-- other product does not pay for a payload nothing there reads
local skidSource = shared.inhalerSkidList
if type(skidSource) == 'table' then
	skidSource.wanted = true
end

CheaterDetector = vape.Categories.Utility:CreateModule({
	Name = 'CheaterDetector',
	Function = function(callback)
		moduleEnabled = callback

		if callback then
			CheaterDetector:Clean(playersService.PlayerAdded:Connect(playerAdded))
			CheaterDetector:Clean(vapeEvents.CheatFlagged.Event:Connect(autoAddCheater))

			-- the backend downloads the global list into shared and fires this; without
			-- a backend (or before its first download) the table is simply empty
			local source = shared.inhalerSkidList
			if type(source) == 'table' and typeof(source.Changed) == 'Instance' then
				CheaterDetector:Clean(source.Changed:Connect(function()
					syncRemote()
				end))
			end

			-- forced: a list downloaded before this module was switched on is picked up
			-- here, and the retag below then only has to announce the new joins
			syncRemote(true)

			cheaterOptions.Teleports.Object.Visible = cheaterOptions.AutomaticAdd.Enabled
			cheaterOptions.Speed.Object.Visible = cheaterOptions.AutomaticAdd.Enabled

			for _, v in playersService:GetPlayers() do
				playerAdded(v)
			end
		end
	end,
	Tooltip = 'Detects people with history of cheating\nCheaters are stored in '..filePath..'\nThe global list the owner uploads is read as a remote list.'
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

cheaterOptions.RemoteList = CheaterDetector:CreateToggle({
	Name = 'Remote list',
	Default = true,
	Function = function(enabled)
		remoteEnabled = enabled

		-- off takes the remote tags back off, on puts them back; an entry the local list
		-- also names keeps its tag either way
		if moduleEnabled then
			retagEveryone()
		end
	end,
	Tooltip = 'Also flags the global skid list the owner uploads to the backend.\nThose entries are read-only here: removing one leaves it in the global list.'
})

cheaterOptions.AutomaticAdd = CheaterDetector:CreateToggle({
	Name = 'Automatic Add',
	Default = false,
	Function = function(enabled)
		cheaterOptions.Teleports.Object.Visible = enabled
		cheaterOptions.Speed.Object.Visible = enabled
	end,
	Tooltip = 'Adds a player to the cheater list when CheatDetector flags an invalid humanoid state or an invalid animation; the two options below add the movement flags as well.\nThe reason is logged as exploits/<flag>.'
})

cheaterOptions.KXAutoAdd = CheaterDetector:CreateDropdown({
	Name = 'AutoAddMode',
	List = {'Inhaler only', 'KX compatible'},
	Tooltip = 'KX compatible sends the .addskid command in public chat.'
})

cheaterOptions.Teleports = CheaterDetector:CreateToggle({
	Name = 'Teleports',
	Default = false,
	Visible = false,
	Darker = true,
	Tooltip = 'Also add players flagged for teleporting'
})

cheaterOptions.Speed = CheaterDetector:CreateToggle({
	Name = 'Speed',
	Default = false,
	Visible = false,
	Darker = true,
	Tooltip = 'Also add players flagged for speeding'
})

cheaterOptions.Webhook = CheaterDetector:CreateToggle({
	Name = 'Webhook',
	Default = false,
	Tooltip = 'Posts every added or removed cheater to a discord webhook',
	Function = function(callback)
		if webhookUrl then
			webhookUrl.Object.Visible = callback
		end
	end
})

webhookUrl = CheaterDetector:CreateTextBox({
	Name = 'Webhook URL', -- for anyone reading this, we WONT LOG ur discord webhook and never will. dashboard is used to manage inhaler users
	Placeholder = 'https://discord.com/api/webhooks/...',
	Visible = false,
	Darker = true,
	Tooltip = 'Discord webhook url the cheater changes get posted to'
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
