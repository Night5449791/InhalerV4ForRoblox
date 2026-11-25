local AutoTeam
local AutoOnDied
local RespawnCooldown
local lastSpawnTime

local function joinTeam(targetName)
	local deadline = targetName and os.clock() + RespawnCooldown.Value + 1 or nil
	while AutoTeam.Enabled and (not lplr.Team or lplr.Team == teams.Neutral) and (not deadline or os.clock() < deadline) do
		local teamGui = lplr.PlayerGui:FindFirstChild('TeamsFrame', true)

		if teamGui then
			for _, holder in teamGui:GetChildren() do
				local button = holder:FindFirstChild('Button')
				if button and button.AutoButtonColor and (not targetName or holder.Name == targetName) then
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

local function pickTarget(skip)
	local teamGui = lplr.PlayerGui:FindFirstChild('TeamsFrame', true)
	if not teamGui then return nil end

	for _, holder in teamGui:GetChildren() do
		local button = holder:FindFirstChild('Button')
		if button and button.AutoButtonColor and holder:IsA('GuiObject') and holder.Visible then
			if skip and holder.Name == skip then continue end
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

	local deadline = os.clock() + RespawnCooldown.Value
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
			AutoTeam:Clean(lplr.CharacterAdded:Connect(function(char)
				if not AutoTeam.Enabled or not AutoOnDied.Enabled then return end

				task.wait(RespawnCooldown.Value)
				if not AutoTeam.Enabled then return end

				local humanoid = char and char:FindFirstChildOfClass('Humanoid')
				if not humanoid or humanoid.Health <= 0 or humanoid:GetState() == Enum.HumanoidStateType.Dead then return end

				local spawnTime = char:GetAttribute('SpawnTime')
				if not spawnTime or spawnTime == lastSpawnTime then return end
				lastSpawnTime = spawnTime

				local current = lplr.Team and lplr.Team.Name or nil
				if current and not leaveTeam() then return end

				local target = pickTarget(current)
				joinTeam(target)
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
RespawnCooldown = AutoTeam:CreateSlider({
	Name = 'Respawn Cooldown',
	Min = 1,
	Max = 15,
	Default = 5,
	Decimal = 10,
	Suffix = 's',
	Tooltip = 'Server respawn delay before re-picking a team'
})
