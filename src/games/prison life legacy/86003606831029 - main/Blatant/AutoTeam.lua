local AutoTeam
local Team
local switching = false

local function jobKey()
	local hex = tonumber('0x'..game.JobId:sub(1, 2))
	if not hex then return end

	local first = tostring(hex):sub(1, 2)
	local value = tonumber(first)
	if not value then return end

	if value == 24 then return first..'lop' end
	if value < 40 then
		if value < 10 then return '77dnuk' end
		return first..'wxug'
	end
	return first..'dnuk'
end

AutoTeam = vape.Categories.Blatant:CreateModule({
	Name = 'AutoTeam',
	Function = function(callback)
		if not callback or switching then return end
		switching = true

		task.spawn(function()
			local colors = {
				Guards = 'Bright blue',
				Inmates = 'Bright orange',
				Neutral = 'Medium stone grey',
				Criminals = 'Really red'
			}
			local color = colors[Team.Value]
			local key = jobKey()

			if color and key and Remotes.R then
				local suc = pcall(function()
					Remotes.R:InvokeServer(nil, color, key)
				end)
				vape:CreateNotification('AutoTeam', suc and ('Switched to '..Team.Value) or 'Failed to switch team', 5)
			end

			task.wait(0.2)
			switching = false
			AutoTeam:Toggle()
		end)
	end,
	Tooltip = 'Instantly switches team'
})
Team = AutoTeam:CreateDropdown({
	Name = 'Team',
	List = {'Guards', 'Inmates', 'Neutral', 'Criminals'}
})
