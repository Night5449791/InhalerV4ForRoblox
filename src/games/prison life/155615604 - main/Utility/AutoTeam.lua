local AutoTeam
local AutoOnDied

local function openTeamMenu()
	local home = lplr.PlayerGui:FindFirstChild('Home', true)
	local switch = home and home.hud.Topbar.MenuFrame.SwitchTeams
	if switch then
		firesignal(switch.MouseButton1Click)
	end
end

local function joinFirstTeam()
	local teamGui = lplr.PlayerGui:FindFirstChild('TeamsFrame', true)
	if not teamGui then return end
	for _, holder in teamGui:GetChildren() do
		if holder.Button.AutoButtonColor then
			firesignal(holder.Button.MouseButton1Click)
			return
		end
	end
end

AutoTeam = vape.Categories.Utility:CreateModule({
	Name = 'AutoTeam',
	Function = function(callback)
		local diedConnection

		local function onDeath()
			if not AutoOnDied.Enabled then return end

			openTeamMenu()
			task.wait(1)
			joinFirstTeam()
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
			joinFirstTeam()

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
