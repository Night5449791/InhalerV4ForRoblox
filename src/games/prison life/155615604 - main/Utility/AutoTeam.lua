local AutoTeam
local AutoOnDied

-- the picker only exists while its menu is open and a single click can silently fail
-- (dead, menu closed, team list not replicated yet), so both are retried until the game
-- actually puts the player on a team
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

AutoTeam = vape.Categories.Utility:CreateModule({
	Name = 'AutoTeam',
	Function = function(callback)
		local diedConnection

		local function connectDeath(entity)
			local humanoid = entity and entity.Humanoid
			if not humanoid then return end

			if diedConnection then
				diedConnection:Disconnect()
			end

			diedConnection = humanoid.Died:Connect(function()
				if AutoOnDied.Enabled then
					task.wait(1.25)
					joinTeam()
				end
			end)
		end

		if callback then
			AutoTeam:Clean(entitylib.Events.LocalAdded:Connect(connectDeath))
			if entitylib.isAlive then
				connectDeath(entitylib.character)
			end

			joinTeam()
		else
			if diedConnection then
				diedConnection:Disconnect()
				diedConnection = nil
			end
		end
	end,
	Tooltip = 'Automatically join a team when joining the server'
})
AutoOnDied = AutoTeam:CreateToggle({
	Name = 'OnDied',
	Default = false,
	Tooltip = 'Automatically pick team on death'
})
