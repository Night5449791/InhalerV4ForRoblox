local GetHash

GetHash = vape.Categories.World:CreateModule({
	Name = 'GetHash',
	Function = function(callback)
		if callback then
			local input = (GetHashUsername.Value or ''):gsub('%s+', '')
			local name, userid

			if input == '' then
				-- self hash
				name = lplr.Name
				userid = lplr.UserId
			else
				local s, id = pcall(playersService.GetUserIdFromNameAsync, playersService, input)
				if not s then
					notif('GetHash', 'failed to find user: '..input, 5)
					return
				end
				name = input
				userid = id
			end

			-- matches whitelist:get() -> hash.sha512(Name..UserId..'SelfReport')
			local h = hash.sha512(name..userid..'SelfReport')
			pcall(setclipboard, h)
			notif('GetHash', 'copied hash for '..name..'\n'..h, 10)
		end
	end,
	Tooltip = 'generate hash for whitelist'
})

GetHashUsername = GetHash:CreateTextBox({
	Name = 'Username',
	Placeholder = 'roblox username',
	Tooltip = 'leave it blank to copy self hash',
})