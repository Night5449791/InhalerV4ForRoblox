local AntiVotekick
local Mode
local teleportService = cloneref(game:GetService('TeleportService'))
local kickFile = 'InhalerV4/profiles/CENTAURAkick.json'
local voteCounter
local valueConnection
local rejoining
local trigger

local function loadKickData()
	if not isfile(kickFile) then return {} end

	local ok, content = pcall(readfile, kickFile)
	if not ok or type(content) ~= 'string' then return {} end

	local decoded, data = pcall(httpService.JSONDecode, httpService, content)
	if not decoded or type(data) ~= 'table' then return {} end

	return data
end

local function saveKickData(data)
	local encoded, content = pcall(httpService.JSONEncode, httpService, data)
	if encoded then
		pcall(writefile, kickFile, content)
	end
end

local function recordKick()
	local userId = tostring(lplr.UserId)
	local data = loadKickData()
	local entry = type(data[userId]) == 'table' and data[userId] or {}
	entry.jobs = type(entry.jobs) == 'table' and entry.jobs or {}

	for _, job in entry.jobs do
		if type(job) == 'table' and job.jobid == game.JobId then
			return
		end
	end

	entry.jobs[#entry.jobs + 1] = {
		jobid = game.JobId,
		timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
	}
	data[userId] = entry
	saveKickData(data)
end

local function getLoggedJobs()
	local userId = tostring(lplr.UserId)
	local data = loadKickData()
	local entry = data[userId]
	local jobs = type(entry) == 'table' and type(entry.jobs) == 'table' and entry.jobs or nil
	local logged, timestamps = {}, {}

	if jobs then
		for _, job in jobs do
			if type(job) == 'table' and type(job.jobid) == 'string' then
				logged[job.jobid] = true
				if type(job.timestamp) == 'string' then
					timestamps[job.jobid] = job.timestamp
				end
			end
		end
	end

	return logged, timestamps
end

local function joinServer(jobId)
	pcall(function()
		teleportService:TeleportToPlaceInstance(game.PlaceId, jobId, lplr)
	end)
end

local function serverhop()
	local logged, timestamps = getLoggedJobs()

	local success, data = pcall(function()
		local response = game:HttpGet('https://games.roblox.com/v1/games/'..game.PlaceId..'/servers/Public?sortOrder=1&excludeFullGames=true&limit=100')
		return httpService:JSONDecode(response)
	end)
	if not success or type(data) ~= 'table' or type(data.data) ~= 'table' then return end

	local candidates = {}
	local visited = {}
	for _, server in data.data do
		if server.id ~= game.JobId and tonumber(server.playing) < playersService.MaxPlayers then
			visited[#visited + 1] = server.id
			if not logged[server.id] then
				candidates[#candidates + 1] = server.id
			end
		end
	end

	if candidates[1] then
		joinServer(candidates[math.random(1, #candidates)])
		return
	end

	local oldest
	for _, jobId in visited do
		local stamp = timestamps[jobId]
		if stamp and (not oldest or stamp < timestamps[oldest]) then
			oldest = jobId
		end
	end

	if oldest then
		joinServer(oldest)
	elseif visited[1] then
		joinServer(visited[1])
	end
end

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
		task.wait(1)

		recordKick()

		if Mode.Value == 'ServerHop' then
			pcall(function()
				lplr:Kick('Inhaler: Anti Votekick is working')
			end)
			serverhop()
		else
			local target = vape.Modules and vape.Modules.Rejoin
			if not target then return end
			pcall(function()
				lplr:Kick('Inhaler: Anti Votekick is working')
			end)
			if not target.Enabled then
				pcall(function()
					target:Toggle()
				end)
			end
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
