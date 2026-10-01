local GetHash
local Mode
local Username

local function hashOf(name)
	local plr = name and playersService:FindFirstChild(name)
	local userid = plr and plr.UserId

	if not userid and name and name ~= '' then
		pcall(function()
			userid = playersService:GetUserIdFromNameAsync(name)
		end)
	end

	return userid and whitelist.hashes[name..userid] or nil
end

GetHash = vape.Categories.World:CreateModule({
	Name = 'GetHash',
	Function = function(callback)
		if callback then
			local value = Mode.Value == 'Username' and hashOf(Username.Value) or whitelist.hashes[lplr.Name..lplr.UserId]

			if not value then
				notif('GetHash', 'No hash found.', 5, 'warning')
			elseif setclipboard then
				setclipboard(value)
				notif('GetHash', 'Copied hash to clipboard.', 5)
			else
				notif('GetHash', 'setclipboard is not supported.', 5, 'warning')
			end

			GetHash:Toggle()
		end
	end,
	Tooltip = 'Copies the private member hash of yourself or a player.'
})
Mode = GetHash:CreateDropdown({
	Name = 'Mode',
	List = {'Self', 'Username'},
	Function = function(val)
		Username.Object.Visible = val == 'Username'
	end
})
Username = GetHash:CreateTextBox({
	Name = 'Username',
	Placeholder = 'Roblox username',
	Visible = false,
	Darker = true
})
