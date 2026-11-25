local AutoTeam
local AutoOnDied
local lastSpawnTime
local respawnCooldown = 5

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
		if callback then
			AutoTeam:Clean(lplr.CharacterAdded:Connect(function(char)
				if not AutoTeam.Enabled or not AutoOnDied.Enabled then return end

				local humanoid = char and char:FindFirstChildOfClass('Humanoid')
				if not humanoid or humanoid.Health <= 0 or humanoid:GetState() == Enum.HumanoidStateType.Dead then return end

				local spawnTime = char:GetAttribute('SpawnTime')
				if not spawnTime or spawnTime == lastSpawnTime then return end
				lastSpawnTime = spawnTime

				if lplr.Team and lplr.Team ~= teams.Neutral then
					task.wait(respawnCooldown)
					if not AutoTeam.Enabled then return end
				end

				if not lplr.Team or lplr.Team == teams.Neutral then
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
