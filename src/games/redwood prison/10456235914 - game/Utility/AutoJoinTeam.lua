local AutoJoinTeam
local Team
local Retry

-- the team chooser buttons carry an ObjectValue named Team pointing at game.Teams.<name>,
-- and the game invokes ChangeTeam:InvokeServer(team, button name)
local function teamButtonName(teamName)
	local gui = lplr.PlayerGui:FindFirstChild('IntroGui')
	local intro = gui and gui:FindFirstChild('IntroFrame')
	local holder = intro and intro:FindFirstChild('Frame')
	local buttons = holder and holder:FindFirstChild('Buttons')
	if not buttons then return end

	for _, button in buttons:GetChildren() do
		local value = button:FindFirstChild('Team')
		if value and value:IsA('ObjectValue') and value.Value and value.Value.Name == teamName then
			return button.Name
		end
	end
end

local function joinTeam(teamName)
	local team = game.Teams:FindFirstChild(teamName)
	if not team then return end

	return redwood.invoke('ChangeTeam', team, teamButtonName(teamName) or teamName)
end

AutoJoinTeam = vape.Categories.Utility:CreateModule({
	Name = 'AutoJoinTeam',
	Function = function(callback)
		if not callback then return end

		repeat
			if redwood.team(lplr) ~= Team.Value then
				joinTeam(Team.Value)
			end

			task.wait(Retry.Value)
		until not AutoJoinTeam.Enabled or vape.Loaded == nil
	end,
	Tooltip = 'Joins the selected team through the game team changer'
})
Team = AutoJoinTeam:CreateDropdown({
	Name = 'Team',
	List = {'Prisoners', 'Guards', 'Fugitive', 'Military', 'Krampus'},
	Function = function()
		if AutoJoinTeam.Enabled then
			AutoJoinTeam:Toggle()
			AutoJoinTeam:Toggle()
		end
	end
})
Retry = AutoJoinTeam:CreateSlider({
	Name = 'Retry delay',
	Min = 1,
	Max = 30,
	Default = 3,
	Suffix = function(val)
		return val == 1 and 'second' or 'seconds'
	end,
	Tooltip = 'The server rejects teams that are not balanced, so the request is repeated'
})
