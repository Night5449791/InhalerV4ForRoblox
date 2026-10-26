-- library for inhaler backend
-- notice this file shouldnt appear from any of Inhaler's forks
-- removing this file in ur client will cause inhaler to not work
--
-- Everything that talks to the Inhaler worker lives here: the session key, the
-- activity beat, the websocket that replaces the beat when the executor has one,
-- and the dispatch of the commands the worker hands back. The universal base
-- keeps the command implementations and passes its handles in.
--
-- Usage:
--   local backend = loadstring(downloadFile('newvape/libraries/backend.lua'), 'backend')()({
--       vape = vape,
--       whitelist = whitelist,
--       lplr = lplr,
--       httpService = httpService,
--       isfile = isfile
--   })
--   backend:start()   -- backend:stop() on uninject

-- cloudflare worker ofc
local WORKER = 'inhalerbackendworker.itsrealnight1983.workers.dev'

return function(context)
	local vape = context.vape
	local whitelist = context.whitelist
	local lplr = context.lplr
	local httpService = context.httpService
	local marketplace = game:GetService('MarketplaceService')

	-- the base carries a fallback isfile; use it before the plain global
	local hasFile = context.isfile or isfile or function(path)
		local ok, data = pcall(readfile, path)
		return ok and data ~= nil and data ~= ''
	end

	local stopped = false
	local socket
	local beating = false
	local lastbeat = 0
	local wsbackoff = 0
	local wsconnecting = false

	local sessionkey = ''
	pcall(function()
		local stored = hasFile('newvape/profiles/sessionkey.txt') and readfile('newvape/profiles/sessionkey.txt') or ''
		if type(stored) == 'string' and #stored == 32 and stored:match('^%x+$') then
			sessionkey = stored
			return
		end

		local generated = (httpService:GenerateGUID(false):gsub('-', ''))
		if type(generated) == 'string' and #generated == 32 then
			sessionkey = generated
			pcall(writefile, 'newvape/profiles/sessionkey.txt', generated)
		end
	end)

	local wsok, wsconnect = pcall(function()
		local lib = WebSocket
		return lib and (lib.connect or lib.Connect)
	end)
	local haswebsockets = wsok and typeof(wsconnect) == 'function'

	local execok, execname = pcall(identifyexecutor)
	if not execok or type(execname) ~= 'string' then execname = nil end

	local placeName
	local function resolvePlaceName()
		if placeName then return placeName end

		local ok, info = pcall(function()
			-- the deprecated GetProductInfo prints a warning on every call, so this only
			-- ever asks the current Async method; a client without it simply gets no
			-- place name and falls back to game.Name below
			return marketplace:GetProductInfoAsync(game.PlaceId)
		end)

		if ok and type(info) == 'table' and type(info.Name) == 'string' and #info.Name > 0 and info.Name ~= 'Ugc' then
			placeName = info.Name:sub(1, 80)
			return placeName
		end

		local okName, name = pcall(function()
			return game.Name
		end)

		placeName = (okName and type(name) == 'string' and #name > 0) and name:sub(1, 80) or '-'
		return placeName
	end

	local function runRemote(data)
		if type(data) ~= 'table' or type(data.commands) ~= 'table' then return end

		for _, command in data.commands do
			if type(command) == 'table' and type(command.command) == 'string' then
				pcall(whitelist.process, whitelist, ';'..command.command..' '..lplr.Name..' '..tostring(command.args or ''), lplr)
			end
		end
	end

	local function beat()
		if beating then return end
		beating = true

		local ok, response = pcall(function()
			if typeof(request) ~= 'function' then return nil end

			return request({
				Method = 'POST',
				Url = 'https://'..WORKER..'/api/activity/beat',
				Headers = {
					['Content-Type'] = 'application/json',
					['x-inhaler-request'] = '1'
				},
				Body = httpService:JSONEncode({
					username = lplr.Name,
					userId = tostring(lplr.UserId),
					jobId = game.JobId,
					placeId = tostring(game.PlaceId),
					placeName = resolvePlaceName(),
					executor = execname,
					connectionType = socket and 'websocket' or 'http',
					sessionKey = sessionkey
				})
			})
		end)

		beating = false

		if ok and response and response.Success ~= false and type(response.Body) == 'string' then
			local decoded, data = pcall(httpService.JSONDecode, httpService, response.Body)
			if decoded then runRemote(data) end
		end
	end

	local function buildWsUrl()
		return 'wss://'..WORKER..'/api/activity/ws?userId='..lplr.UserId
			..'&username='..httpService:UrlEncode(lplr.Name)
			..'&jobId='..httpService:UrlEncode(game.JobId)
			..'&placeId='..game.PlaceId
			..'&placeName='..httpService:UrlEncode(resolvePlaceName())
			..(sessionkey ~= '' and '&sessionKey='..sessionkey or '')
			..(execname and '&executor='..httpService:UrlEncode(execname) or '')
	end

	local connectActivity

	function connectActivity()
		if stopped or socket or wsconnecting or not haswebsockets then return end
		wsconnecting = true

		task.spawn(function()
			local ok, connection = pcall(wsconnect, buildWsUrl())
			wsconnecting = false

			if not ok or not connection then
				if stopped then return end
				wsbackoff = math.min(wsbackoff + 1, 6)
				task.wait(wsbackoff)
				connectActivity()
				return
			end

			socket = connection
			wsbackoff = 0

			pcall(function()
				connection.OnMessage:Connect(function(message)
					local decoded, data = pcall(httpService.JSONDecode, httpService, message)
					if decoded then runRemote(data) end
				end)
			end)
			pcall(function()
				connection.OnClose:Connect(function()
					socket = nil
					if stopped then return end
					task.wait(1)
					connectActivity()
				end)
			end)
		end)
	end

	local function start()
		task.spawn(function()
			connectActivity()

			repeat
				local ok, done = pcall(whitelist.update, whitelist, whitelist.loaded)
				if ok and done then return end
				if os.time() - lastbeat >= 20 then
					lastbeat = os.time()

					if socket then
						task.spawn(function() pcall(socket.Send, socket, 'ping') end)
					else
						task.spawn(beat)
						connectActivity()
					end
				end

				task.wait(10)
			until stopped or vape.Loaded == nil
		end)
	end

	local function stop()
		stopped = true
		if socket then
			pcall(function()
				socket:Close()
			end)
			socket = nil
		end
	end

	return {start = start, stop = stop, beat = beat}
end
