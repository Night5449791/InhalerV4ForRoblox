local UserSnipe
local Username
local DisplayName
local Sort

-- matches against the live player list using the username and/or display name
local function findTarget()
	local name = (Username.Value or ''):lower():gsub('%s+', '')
	local display = (DisplayName.Value or ''):lower():gsub('%s+', '')

	if name == '' and display == '' then
		return nil
	end

	for _, plr in playersService:GetPlayers() do
		if plr == lplr then continue end

		local pname = plr.Name:lower()
		local pdisplay = plr.DisplayName:lower()

		if (name ~= '' and pname == name) or (display ~= '' and pdisplay == display) then
			return plr
		end
	end

	return nil
end

local function finishSnipe(target)
	notif('UserSnipe', 'Found '..target.Name..' ('..target.DisplayName..') in this server.', 10)
	shared.vapeusersnipe = nil
	UserSnipe:Toggle()
end

UserSnipe = vape.Categories.World:CreateModule({
	Name = 'UserSnipe',
	Function = function(callback)
		if callback then
			-- restore the inputs from the last run so the search survives a teleport
			if (Username.Value == '' and DisplayName.Value == '') and shared.vapeusersnipe then
				Username:SetValue(shared.vapeusersnipe.name or '')
				DisplayName:SetValue(shared.vapeusersnipe.display or '')
			end

			local name = (Username.Value or ''):gsub('%s+', '')
			local display = (DisplayName.Value or ''):gsub('%s+', '')

			if name == '' and display == '' then
				notif('UserSnipe', 'Enter a username or display name first.', 5, 'warning')
				UserSnipe:Toggle()
				return
			end

			shared.vapeusersnipe = {
				name = name,
				display = display
			}

			local target = findTarget()
			if target then
				finishSnipe(target)
				return
			end

			task.spawn(function()
				-- give the server a moment to populate the player list before hopping
				task.wait(2)

				local found = findTarget()
				if found then
					finishSnipe(found)
					return
				end

				notif('UserSnipe', 'Not in this server, hopping...', 3)
				serverHop(nil, Sort.Value)
			end)
		else
			shared.vapeusersnipe = nil
		end
	end,
	Tooltip = 'Spams serverhop until the target username or display name shows up in a server, then lands you there.'
})
Username = UserSnipe:CreateTextBox({
	Name = 'Username',
	Placeholder = 'Target username'
})
DisplayName = UserSnipe:CreateTextBox({
	Name = 'Display Name',
	Placeholder = 'Target display name'
})
Sort = UserSnipe:CreateDropdown({
	Name = 'Sort',
	List = {'Descending', 'Ascending'},
	Tooltip = 'Descending - Prefers full servers\nAscending - Prefers empty servers'
})

-- resume the search after a teleport (shared persists across the hop)
if shared.vapeusersnipe then
	task.spawn(function()
		if not UserSnipe.Enabled then
			UserSnipe:Toggle()
		end
	end)
end
