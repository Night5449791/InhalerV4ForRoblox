local AutoTeam

AutoTeam = vape.Categories.Utility:CreateModule({
	Name = 'AutoTeam',
	Function = function(callback)
		local diedConnection

		local function onDeath()
			if not AutoOnDied.Enabled then return end

			local home = lplr.PlayerGui:FindFirstChild('Home', true)
			local switch = home and home.hud.Topbar.MenuFrame.SwitchTeams
			if switch then
				firesignal(switch.MouseButton1Click)
			end

			task.wait(1)

			local teamGui = lplr.PlayerGui:FindFirstChild('TeamsFrame', true)
			if teamGui then
				for _, holder in teamGui:GetChildren() do
					if holder.Button.AutoButtonColor then
						pickTeam(holder.Button)
						break
					end
				end
			end
		end

		local function connectDeath(entity)
			local humanoid = entity and entity.Humanoid
			if not humanoid then return end

			if diedConnection then
				diedConnection:Disconnect()
			end

			diedConnection = humanoid.Died:Connect(onDeath)
		end

		if callback then
			local gui = lplr.PlayerGui:FindFirstChild('TeamsFrame', true)
			if gui then
				for _, holder in gui:GetChildren() do
					if holder.Button.AutoButtonColor then
						firesignal(holder.Button.MouseButton1Click)
						break
					end
				end
			end

			AutoTeam:Clean(entitylib.Events.LocalAdded:Connect(connectDeath))
			if entitylib.isAlive then
				connectDeath(entitylib.character)
			end
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

-- firesignal(game:GetService("Players").LocalPlayer.PlayerGui.Home.hud.Topbar.MenuFrame.SwitchTeams.MouseButton1Click) switching neutral imma take note on