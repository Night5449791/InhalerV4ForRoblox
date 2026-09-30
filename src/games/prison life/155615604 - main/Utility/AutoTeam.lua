local AutoTeam

local function requestTeam(team)
	local remotes = replicatedStorage:FindFirstChild('Remotes')
	local remote = remotes and remotes:FindFirstChild('RequestTeamChange')
	if remote and team and lplr.Team ~= team then
		remote:InvokeServer(team, 1)
	end
end

local function findTeamButton(teamName)
	local gui = lplr.PlayerGui:FindFirstChild('TeamsFrame', true)
	if not gui then return end

	local lowered = teamName and teamName:lower()
	for _, holder in gui:GetChildren() do
		local button = holder:FindFirstChild('Button')
		if not (button and button.AutoButtonColor) then continue end
		if not lowered or holder.Name:lower():find(lowered, 1, true) then
			return button
		end
	end
end

local function onDied()
	requestTeam(teams:FindFirstChild('Neutral'))
	AutoTeam:Join()
end

AutoTeam = vape.Categories.Utility:CreateModule({
	Name = 'AutoTeam',
	Function = function(callback)
		if callback then
			if entitylib.isAlive then
				AutoTeam:Clean(entitylib.character.Humanoid.Died:Connect(onDied))
			end

			AutoTeam:Clean(entitylib.Events.LocalAdded:Connect(function(entity)
				AutoTeam:Clean(entity.Humanoid.Died:Connect(onDied))
			end))

			AutoTeam:Join()
		end
	end,
	Tooltip = 'Automatically join a team when joining the server'
})

function AutoTeam:Join(teamName)
	local button = findTeamButton(teamName)
	if button then
		pickTeam(button)
		return true
	end

	local team = teamName and teams:FindFirstChild(teamName)
	if team then
		requestTeam(team)
		return true
	end

	return false
end
