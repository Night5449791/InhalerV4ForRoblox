local ServerHop
local Sort
local AvoidJoined

local JOBID_PATH = 'newvape/serverhop.txt'
local joinedList, joinedSet = {}, {}
local avoidJoined = true

-- `attempted` is the skip list serverHop() checks, feeding it the joined servers
-- is what keeps the hop away from servers we already visited
local function filterJoinedServers()
	for index = #attempted, 1, -1 do
		if joinedSet[attempted[index]] then
			table.remove(attempted, index)
		end
	end

	if not avoidJoined then return end

	for _, id in joinedList do
		if not table.find(attempted, id) then
			table.insert(attempted, id)
		end
	end
end

local function logJobId(id)
	if not id or id == '' or joinedSet[id] then return end

	joinedSet[id] = true
	table.insert(joinedList, id)
	if #joinedList > 200 then
		joinedSet[table.remove(joinedList, 1)] = nil
	end

	if avoidJoined and not table.find(attempted, id) then
		table.insert(attempted, id)
	end

	pcall(writefile, JOBID_PATH, table.concat(joinedList, '\n'))
end

local success, data = pcall(readfile, JOBID_PATH)
if success and type(data) == 'string' then
	for id in data:gmatch('%S+') do
		if not joinedSet[id] then
			joinedSet[id] = true
			table.insert(joinedList, id)
		end
	end
end

logJobId(game.JobId)
vape:Clean(lplr.OnTeleport:Connect(function()
	logJobId(game.JobId)
end))

ServerHop = vape.Categories.Utility:CreateModule({
	Name = 'ServerHop',
	Function = function(callback)
		if callback then
			ServerHop:Toggle()
			logJobId(game.JobId)
			filterJoinedServers()
			serverHop(nil, Sort.Value)
		end
	end,
	Tooltip = 'Teleports into a unique server'
})
Sort = ServerHop:CreateDropdown({
	Name = 'Sort',
	List = {'Descending', 'Ascending'},
	Tooltip = 'Descending - Prefers full servers\nAscending - Prefers empty servers'
})
AvoidJoined = ServerHop:CreateToggle({
	Name = 'Avoid Joined Servers',
	Default = true,
	Function = function(callback)
		avoidJoined = callback
		filterJoinedServers()
	end,
	Tooltip = 'Logs the job id of every server you join and skips those servers while hopping.'
})
ServerHop:CreateButton({
	Name = 'Rejoin Previous Server',
	Function = function()
		notif('ServerHop', shared.vapeserverhopprevious and 'Rejoining previous server...' or 'Cannot find previous server', 5)

		if shared.vapeserverhopprevious then
			teleportService:TeleportToPlaceInstance(game.PlaceId, shared.vapeserverhopprevious)
		end
	end
})
ServerHop:CreateButton({
	Name = 'Clear Joined Servers',
	Function = function()
		filterJoinedServers()
		table.clear(joinedList)
		table.clear(joinedSet)
		pcall(writefile, JOBID_PATH, '')
		notif('ServerHop', 'Cleared the joined server log.', 5)
	end
})
