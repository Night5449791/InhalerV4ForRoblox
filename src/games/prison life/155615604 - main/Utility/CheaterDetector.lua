-- cheaters are stored locally in newvape/profile/cheaters-<GameId>.json
-- the list starts empty and is user managed

local CheaterDetector
local cheaterOptions = {}
local filePath = 'newvape/profile/cheaters-'..tostring(game.GameId)..'.json'
local Cheaters = {Names = {}, Users = {}}
local canSave = json ~= nil

-- vape.Notifications only exists once the gui is loaded, this file runs before that
local function notify(text, duration, type)
	if vape.Notifications then
		notif('CheaterDetector', text, duration, type)
	end
end

local function saveCheaters()
	if not canSave then
		notify('Failed to save, json library is unavailable.', 15, 'warning')
	elseif not pcall(json.write, filePath, Cheaters) then
		notify('Failed to write '..filePath, 15, 'warning')
	end
end

local function loadCheaters()
	local data = canSave and json.read(filePath)
	if not data then
		return saveCheaters() -- creates the file on first run
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

-- remove = true drops the player, otherwise they get added with the given reason
local function editCheater(text, reason, remove)
	text = text and text:match('^%s*(.-)%s*$')
	if not text or text == '' then return notify('No player given.', 8, 'warning') end

	-- a removal has no reason, that is what untags the player
	if remove then
		reason = nil
	else
		reason = (reason and reason:match('^%s*(.-)%s*$')) or 'manually added'
	end

	local plr = findCheaterPlayer(text)

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
		Cheaters.Names[text:lower()] = not remove and reason or nil
	end

	saveCheaters()
	notify((plr and plr.DisplayName or text)..(remove and ' removed from the cheater list.' or ' added to the cheater list. ('..reason..')'), 10)
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
	Tooltip = 'Adds a player to the local cheater list',
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
