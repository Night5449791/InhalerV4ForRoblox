local FastChange
local ChooseTeam

FastChange = vape.Categories.Blatant:CreateModule({
	Name = 'FastChange',
	Function = function(callback)
		if callback then
			local picked = false

			if lplr.Team == teams.Neutral then
				local teamGui = lplr.PlayerGui:FindFirstChild('TeamsFrame', true)
				if teamGui then
					for _, holder in teamGui:GetChildren() do
						if holder.Name == ChooseTeam.Value and holder.Button.AutoButtonColor then
							firesignal(holder.Button.MouseButton1Click)
							picked = true
							break
						end
					end
				end
			else
				local home = lplr.PlayerGui:FindFirstChild('Home', true)
				local switch = home and home.hud.Topbar.MenuFrame.SwitchTeams
				if switch then
					firesignal(switch.MouseButton1Click)
				end

				task.wait(0.75)

				local teamGui = lplr.PlayerGui:FindFirstChild('TeamsFrame', true)
				if teamGui then
					for _, holder in teamGui:GetChildren() do
						if holder.Name == ChooseTeam.Value and holder.Button.AutoButtonColor then
							firesignal(holder.Button.MouseButton1Click)
							picked = true
							break
						end
					end
				end
			end

			if not picked then
				notif('FastChange', 'Could not switch to '..ChooseTeam.Value..'.', 2, 'warning')
			end

			FastChange:Toggle()
		end
	end,
	Tooltip = 'Fast team switch via the team menu'
})

ChooseTeam = FastChange:CreateDropdown({
	Name = 'Team',
	List = {'Guards', 'Inmates'}
})