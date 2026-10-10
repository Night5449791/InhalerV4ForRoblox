local GetHash
local Hash

-- whitelist.hashes is the same cache whitelist:get reads from, so this is exactly
-- the hash the whitelist gets checked against
local function getHash()
	return whitelist.hashes[lplr.Name..lplr.UserId]
end

GetHash = vape.Categories.World:CreateModule({
	Name = 'GetHash',
	Function = function(callback)
		if callback then
			GetHash:Toggle()

			local value = getHash()
			if value == '' then
				notif('GetHash', 'Hash library is not loaded.', 5, 'warning')
				return
			end

			Hash:SetValue(value)

			if not setclipboard then
				notif('GetHash', 'Your executor does not support clipboard.', 5, 'warning')
				return
			end

			setclipboard(value)
			notif('GetHash', 'Copied your whitelist hash.', 5)
		end
	end,
	Tooltip = 'generate hash for whitelist'
})
Hash = GetHash:CreateTextBox({
	Name = 'Hash',
	Placeholder = 'Enable to generate',
	Darker = true,
	Tooltip = 'sha512 of your name, user id and SelfReport'
})
GetHash:CreateButton({
	Name = 'Copy Hash',
	Function = function()
		if not setclipboard then
			notif('GetHash', 'Your executor does not support clipboard.', 5, 'warning')
			return
		end

		local value = Hash.Value ~= '' and Hash.Value or getHash()
		if value == '' then
			notif('GetHash', 'Hash library is not loaded.', 5, 'warning')
			return
		end

		setclipboard(value)
		notif('GetHash', 'Copied your whitelist hash.', 5)
	end,
	Tooltip = 'Copies your whitelist hash to the clipboard'
})
