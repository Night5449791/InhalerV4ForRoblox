local AntiVotekick
local Mode
local voteCounter
local valueConnection
local rejoining
local trigger

local function watchCounter(counter)
	if not counter:IsA('IntValue') then return end
	voteCounter = counter

	if valueConnection then
		valueConnection:Disconnect()
	end

	local function check()
		if voteCounter == counter and counter.Value > 0 then
			trigger()
		end
	end

	valueConnection = counter:GetPropertyChangedSignal('Value'):Connect(check)
	AntiVotekick:Clean(function()
		valueConnection = nil
	end)
	check()
end

local function startWatching()
	local votekickValues = replicatedStorage:FindFirstChild('VotekickValues')
	if not votekickValues then
		return replicatedStorage:WaitForChild('VotekickValues', 30)
	end
	return votekickValues
end

trigger = function()
	if rejoining then return end
	rejoining = true

	task.spawn(function()
		local target = vape.Modules and vape.Modules[Mode.Value]
		if not target then return end

		pcall(function()
			lplr:Kick('Inhaler: Anti Votekick is working')
		end)

		if not target.Enabled then
			pcall(function()
				target:Toggle()
			end)
		end
	end)
end

AntiVotekick = vape.Categories.Utility:CreateModule({
	Name = 'AntiVotekick',
	Function = function(callback)
		rejoining = nil
		if callback then
			local votekickValues = startWatching()
			if not votekickValues then return end

			local existing = votekickValues:FindFirstChild(lplr.Name)
			if existing then
				watchCounter(existing)
			end

			AntiVotekick:Clean(votekickValues.ChildAdded:Connect(function(child)
				if child.Name == lplr.Name then
					watchCounter(child)
				end
			end))
		else
			voteCounter = nil
			if valueConnection then
				valueConnection:Disconnect()
				valueConnection = nil
			end
		end
	end,
	Tooltip = 'Rejoins or serverhops when someone votekicks you'
})
Mode = AntiVotekick:CreateDropdown({
	Name = 'Mode',
	List = {'Rejoin', 'ServerHop'}
})
