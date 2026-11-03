local AutoTeam
local AutoOnDied

local function joinTeam()
	while AutoTeam.Enabled and (not lplr.Team or lplr.Team == teams.Neutral) do
		local teamGui = lplr.PlayerGui:FindFirstChild('TeamsFrame', true)

		if teamGui then
			for _, holder in teamGui:GetChildren() do
				local button = holder:FindFirstChild('Button')
				if button and button.AutoButtonColor then
					firesignal(button.MouseButton1Click)
					break
				end
			end

			task.wait(0.5)
		else
			local home = lplr.PlayerGui:FindFirstChild('Home', true)
			local switch = home and home.hud.Topbar.MenuFrame.SwitchTeams
			if switch then
				firesignal(switch.MouseButton1Click)
			end

			task.wait(1)
		end
	end
end

local function pickTarget()
	local teamGui = lplr.PlayerGui:FindFirstChild('TeamsFrame', true)
	if not teamGui then return nil end

	for _, holder in teamGui:GetChildren() do
		local button = holder:FindFirstChild('Button')
		if button and button.AutoButtonColor and holder:IsA('GuiObject') and holder.Visible then
			return holder.Name
		end
	end

	return nil
end

local function leaveTeam()
	local home = lplr.PlayerGui:FindFirstChild('Home', true)
	local switch = home and home.hud.Topbar.MenuFrame.SwitchTeams
	if not switch then return false end

	firesignal(switch.MouseButton1Click)

	local deadline = os.clock() + 3
	while os.clock() < deadline do
		if not lplr.Team or lplr.Team == teams.Neutral then return true end
		task.wait(0.1)
	end

	return false
end

AutoTeam = vape.Categories.Utility:CreateModule({
	Name = 'AutoTeam',
	Function = function(callback)
		if callback then
			AutoTeam:Clean(lplr.CharacterAdded:Connect(function()
				if not AutoOnDied.Enabled then return end

				task.wait(0.5)

				if not AutoTeam.Enabled or not lplr.Team or lplr.Team == teams.Neutral then return end

				local target = pickTarget()
				if not target or target == lplr.Team.Name then return end

				if leaveTeam() then
					joinTeam()
				end
			end))

			joinTeam()
		end
	end,
	Tooltip = 'Automatically join a team when joining the server'
})
AutoOnDied = AutoTeam:CreateToggle({
	Name = 'OnDied',
	Default = false,
	Tooltip = 'Re-pick a team when you respawn'
})
