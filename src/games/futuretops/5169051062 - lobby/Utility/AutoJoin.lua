local AutoJoin

-- the hub runs its own lobby browser: the server answers GET_PUBLIC_SERVERS with
-- ("PUBLIC_SERVERS", {{Owner = userId, PlaceId = place, Players = {userIds}, ...}, ...})
-- and JOIN_SERVER teleports into that lobby, so no roblox web request is involved
local function requestLobbies(remote, timeout)
	local lobbies, connection

	connection = remote.OnClientEvent:Connect(function(kind, list)
		if kind == 'PUBLIC_SERVERS' and type(list) == 'table' then
			lobbies = list
		end
	end)

	remote:FireServer('GET_PUBLIC_SERVERS')

	local deadline = os.clock() + timeout
	repeat task.wait() until lobbies or os.clock() > deadline
	connection:Disconnect()

	return lobbies
end

local function findFullest(lobbies)
	local best

	for _, entry in lobbies do
		local players = type(entry.Players) == 'table' and #entry.Players or 0
		if players > 0 and (not best or players > best.Players) then
			best = {
				Owner = entry.Owner,
				PlaceId = entry.PlaceId,
				Players = players
			}
		end
	end

	return best
end

AutoJoin = vape.Categories.Utility:CreateModule({
	Name = 'AutoJoin',
	Function = function(callback)
		if not callback then return end

		-- acts once, so the toggle is dropped instead of staying lit
		AutoJoin:Toggle()
		notif('AutoJoin', 'Looking for the fullest lobby.', 2)

		local remote = replicatedStorage:FindFirstChild('Server')
		if not remote then
			notif('AutoJoin', 'Lobby remote not found', 5, 'warning')
			return
		end

		local lobbies = requestLobbies(remote, 3)
		if not lobbies then
			notif('AutoJoin', 'The lobby list did not arrive', 5, 'warning')
			return
		end

		local lobby = findFullest(lobbies)
		if not lobby then
			notif('AutoJoin', 'No joinable lobby found', 5, 'warning')
			return
		end

		-- the hub's own browser requests the details of a lobby and keeps them open for a
		-- moment before the accept button is even usable, so the same order is followed
		-- here instead of firing JOIN_SERVER straight off the list
		remote:FireServer('GET_SERVER_DATA', lobby.Owner, lobby.PlaceId)
		task.wait(1.3)

		notif('AutoJoin', 'Joining a '..lobby.Players..' player lobby.', 5)
		remote:FireServer('JOIN_SERVER', lobby.Owner, lobby.PlaceId)
	end,
	Tooltip = 'Joins the public lobby with the most players'
})
