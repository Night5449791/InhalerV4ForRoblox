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
			local value = table.find(Mode.ListEnabled, 'Username') and hashOf(Username.Value) or whitelist.hashes[lplr.Name..lplr.UserId]

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
Mode = GetHash:CreateTextList({
	Name = 'Mode',
	Default = {'Self', 'Username'},
	Function = function()
		if Username then
			Username.Object.Visible = table.find(Mode.ListEnabled, 'Username') ~= nil
		end
	end
})
Username = GetHash:CreateTextBox({
	Name = 'Username',
	Placeholder = 'Roblox username',
	Visible = false,
	Darker = true
})
