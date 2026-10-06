-- Webhook library: minimal discord webhook poster.
-- Validates a webhook url, encodes the payload and posts it with whatever http
-- request function the executor happens to expose.
--
-- Usage (loaded as its own chunk):
--   local webhook = loadstring(downloadFile('newvape/libraries/webhook.lua'), 'webhook')()
--   webhook.validate(url)                    -> bool
--   webhook.send(url, payload)               -> bool, err
--   webhook.sendEmbed(url, embed, 'name')    -> bool, err
--
-- send and sendEmbed block until discord answers, spawn them from a task or the
-- caller stalls for as long as the request takes

local cloneref = cloneref or function(obj)
	return obj
end
local httpService = cloneref(game:GetService('HttpService'))

-- the chunk env is not always the executor env, these live on the real global
-- table, so getgenv has to be tried before the plain globals.
-- resolved once, an executor never swaps this out while running
local requestFunction
local requestResolved = false

local function getRequestFunction()
	if requestResolved then return requestFunction end
	requestResolved = true

	local genv = (getgenv and getgenv()) or _G

	if genv then
		requestFunction = typeof(genv.request) == 'function' and genv.request
			or typeof(genv.http_request) == 'function' and genv.http_request
			or (typeof(genv.syn) == 'table' and typeof(genv.syn.request) == 'function' and genv.syn.request)
			or nil
	end

	if not requestFunction then
		-- every executor names this differently, request is the common one
		requestFunction = typeof(request) == 'function' and request
			or typeof(http_request) == 'function' and http_request
			or (typeof(syn) == 'table' and typeof(syn.request) == 'function' and syn.request)
			or nil
	end

	return requestFunction
end

local webhook = {}

-- discord.com, canary.discord.com and the older discordapp.com are all valid
function webhook.validate(url)
	if type(url) ~= 'string' then return false end

	local host = url:match('^https://([%w%.%-]+)/api/webhooks/%d+/%S+$')
	if not host then return false end

	return host:match('discord%.com$') ~= nil or host:match('discordapp%.com$') ~= nil
end

-- payload is the raw table the discord api expects
-- returns true when discord took it, false plus a reason otherwise
function webhook.send(url, payload)
	if not webhook.validate(url) then
		return false, 'Invalid webhook url'
	end

	local requestFunction = getRequestFunction()
	if not requestFunction then
		return false, 'No http request function available'
	end

	local encoded, body = pcall(function()
		return httpService:JSONEncode(payload)
	end)

	if not encoded then
		return false, 'Failed to encode: '..tostring(body)
	end

	local sent, response = pcall(requestFunction, {
		Method = 'POST',
		Url = url,
		Headers = {
			['Content-Type'] = 'application/json',
			-- discord turns away some of the default executor user agents
			['User-Agent'] = 'Mozilla/5.0'
		},
		Body = body
	})

	if not sent then
		return false, 'Request failed: '..tostring(response)
	end

	if not response or response.Success == false then
		return false, 'Discord refused: '..tostring(response and (response.StatusMessage or response.Body) or 'no response')
	end

	return true
end

-- discord drops the whole embed when a single part is too long, so clamp it
local function clamp(text, limit)
	text = tostring(text or '')
	return #text > limit and text:sub(1, limit) or text
end

-- embed is a plain discord embed table {title, description, color, fields}
-- every field is {name = text, value = text, inline = bool}
function webhook.sendEmbed(url, embed, username)
	local fields = {}

	for index, field in type(embed.fields) == 'table' and embed.fields or {} do
		if index > 25 then break end

		table.insert(fields, {
			name = clamp(field.name, 256),
			value = clamp(field.value, 1024),
			inline = field.inline == true
		})
	end

	local built = {
		title = clamp(embed.title, 256),
		description = clamp(embed.description, 4096),
		color = embed.color
	}

	-- an empty array makes discord reject the payload, leave the key out
	if next(fields) then
		built.fields = fields
	end

	return webhook.send(url, {
		username = username,
		embeds = {built}
	})
end

return webhook
