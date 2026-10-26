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

local webhook = {}

-- discord.com, canary.discord.com and the older discordapp.com are all valid
function webhook.validate(url)
	local host = type(url) == 'string' and url:match('^https://([%w%.%-]+)/api/webhooks/%d+/%S+$')
	return host ~= nil and (host:match('discord%.com$') or host:match('discordapp%.com$')) ~= nil
end

-- the chunk env is not always the executor env, so getgenv is tried before the plain
-- globals; an executor never swaps these out while running, so it is resolved once
local requestFunction
local requestResolved = false

local function getRequestFunction()
	if requestResolved then return requestFunction end
	requestResolved = true

	local genv = getgenv and getgenv()
	for _, env in {genv or {}, {request = request, http_request = http_request, syn = syn}} do
		if typeof(env) == 'table' then
			requestFunction = (typeof(env.request) == 'function' and env.request)
				or (typeof(env.http_request) == 'function' and env.http_request)
				or (typeof(env.syn) == 'table' and typeof(env.syn.request) == 'function' and env.syn.request)

			if requestFunction then break end
		end
	end

	return requestFunction
end

-- payload is the raw table the discord api expects, true when discord took it
function webhook.send(url, payload)
	if not webhook.validate(url) then return false, 'Invalid webhook url' end

	local post = getRequestFunction()
	if not post then return false, 'No http request function available' end

	local encoded, body = pcall(httpService.JSONEncode, httpService, payload)
	if not encoded then return false, 'Failed to encode: '..tostring(body) end

	local sent, response = pcall(post, {
		Method = 'POST',
		Url = url,
		Body = body,
		Headers = {
			['Content-Type'] = 'application/json',
			-- discord turns away some of the default executor user agents
			['User-Agent'] = 'Mozilla/5.0'
		}
	})

	if not sent then return false, 'Request failed: '..tostring(response) end
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
	local source = type(embed.fields) == 'table' and embed.fields or {}

	for index, field in source do
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
	if fields[1] then built.fields = fields end

	return webhook.send(url, {username = username, embeds = {built}})
end

return webhook
