local FastChange
local ChooseTeam

local function openTeamMenu()
	local home = lplr.PlayerGui:FindFirstChild('Home', true)
	local switch = home and home.hud.Topbar.MenuFrame.SwitchTeams
	if switch then
		firesignal(switch.MouseButton1Click)
	end
end

local function switchTeam(name)
	local teamGui = lplr.PlayerGui:FindFirstChild('TeamsFrame', true)
	if not teamGui then return false end
	for _, holder in teamGui:GetChildren() do
		if holder.Name == name and holder.Button.AutoButtonColor then
			firesignal(holder.Button.MouseButton1Click)
			return true
		end
	end
	return false
end

FastChange = vape.Categories.Blatant:CreateModule({
	Name = 'FastChange',
	Function = function(callback)
		if not callback then return end

		local picked
		if lplr.Team == teams.Neutral then
			picked = switchTeam(ChooseTeam.Value)
		else
			openTeamMenu()
			task.wait(0.8)
			picked = switchTeam(ChooseTeam.Value)
		end

		if not picked then
			notif('FastChange', 'Could not switch to '..ChooseTeam.Value..'.', 2, 'warning')
		end

		FastChange:Toggle()
	end,
	Tooltip = 'Fast team switch via the team menu'
})

ChooseTeam = FastChange:CreateDropdown({
	Name = 'Team',
	List = {'Guards', 'Inmates'}
})
