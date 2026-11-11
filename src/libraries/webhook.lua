local cloneref = cloneref or function(obj)
	return obj
end
local httpService = cloneref(game:GetService('HttpService'))

local webhook = {}

function webhook.validate(url)
	local host = type(url) == 'string' and url:match('^https://([%w%.%-]+)/api/webhooks/%d+/%S+$')
	return host ~= nil and (host:match('discord%.com$') or host:match('discordapp%.com$')) ~= nil
end

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
			['User-Agent'] = 'Mozilla/5.0'
		}
	})

	if not sent then return false, 'Request failed: '..tostring(response) end
	if not response or response.Success == false then
		return false, 'Discord refused: '..tostring(response and (response.StatusMessage or response.Body) or 'no response')
	end

	return true
end

local function clamp(text, limit)
	text = tostring(text or '')
	return #text > limit and text:sub(1, limit) or text
end

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

	if fields[1] then built.fields = fields end

	return webhook.send(url, {username = username, embeds = {built}})
end

return webhook
