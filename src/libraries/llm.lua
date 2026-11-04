-- LLM library: a thin client for any openai-compatible chat completions api.
-- Talks to whatever endpoint the user configures, keeps the transport here so the
-- modules above it only deal with messages and replies.
--
-- Usage (loaded as its own chunk):
--   local llm = loadstring(downloadFile('newvape/libraries/llm.lua'), 'llm')()
--   llm.chat({endpoint = ..., key = ..., model = ..., messages = {...}}) -> reply, err
--   llm.models({endpoint = ..., key = ...})                              -> list, err
--
-- chat() fails before it spends anything when the model is not one the endpoint
-- knows, so a typo costs a /models lookup instead of a completion.

local cloneref = cloneref or function(obj)
	return obj
end
local httpService = cloneref(game:GetService('HttpService'))

-- a completion can take a while on a slow endpoint, but not forever
local REQUEST_TIMEOUT = 30

local llm = {}

local function getRequestFunction()
	local genv = getgenv and getgenv()
	for _, env in {genv or {}, {request = request, http_request = http_request, syn = syn}} do
		if typeof(env) == 'table' then
			local fn = (typeof(env.request) == 'function' and env.request)
				or (typeof(env.http_request) == 'function' and env.http_request)
				or (typeof(env.syn) == 'table' and typeof(env.syn.request) == 'function' and env.syn.request)

			if fn then return fn end
		end
	end
end

local function trim(value)
	if typeof(value) ~= 'string' then return '' end
	return (value:match('^%s*(.-)%s*$'))
end

-- the base url a user pastes is not always the full path, so the suffix is appended
-- only when it is missing. A url that already ends in a known route is left alone
function llm.resolveEndpoint(endpoint, route)
	local base = trim(endpoint)
	if base == '' then return nil, 'no endpoint set' end

	base = base:gsub('/+$', '')
	if base:find(route, 1, true) then return base end

	return base..route
end

-- runs a request and folds every transport-level failure into one (nil, err) pair,
-- so no caller has to pcall the executor function itself
local function call(options, url, method, body, headers)
	local post = getRequestFunction()
	if not post then return nil, 'no http request function in this executor' end

	local payload = {
		Url = url,
		Method = method or 'GET',
		Headers = headers or {}
	}

	if body ~= nil then
		local encoded, text = pcall(httpService.JSONEncode, httpService, body)
		if not encoded then return nil, 'failed to encode the request body' end

		payload.Headers['Content-Type'] = 'application/json'
		payload.Body = text
	end

	-- the executor call blocks, so a request that never answers would hold the thread;
	-- the timeout is advisory: the thread is let go and the reply is ignored
	local done = false
	local timer = task.delay(REQUEST_TIMEOUT, function()
		done = true
	end)

	local ok, response = pcall(post, payload)
	task.cancel(timer)

	if not ok then return nil, 'request failed: '..tostring(response) end
	if done then return nil, 'request timed out after '..REQUEST_TIMEOUT..'s' end
	if typeof(response) ~= 'table' then return nil, 'request returned nothing' end

	local status = tonumber(response.StatusCode or response.Status) or 0
	local text = response.Body or ''

	if status < 200 or status >= 300 then
		-- the api puts a useful message in the body; a bare status is not enough to
		-- tell a bad model apart from a bad key
		local decoded, data = pcall(httpService.JSONDecode, httpService, text)
		local detail = decoded and typeof(data) == 'table'
			and data.error
			and (typeof(data.error) == 'string' and data.error or data.error.message)
			or nil

		return nil, 'api answered '..status..(detail and (': '..tostring(detail)) or ''), status
	end

	local decoded, data = pcall(httpService.JSONDecode, httpService, text)
	if not decoded or typeof(data) ~= 'table' then return nil, 'api returned no json' end

	return data, nil, status
end

-- every model the endpoint offers, as a plain array of ids. Used to prove a model
-- name exists before a completion is attempted
function llm.models(config)
	local url = llm.resolveEndpoint(config and config.endpoint, '/models')
	if not url then return nil, 'no endpoint set' end

	local key = trim(config and config.key)
	if key == '' then return nil, 'no api key set' end

	local data, err, status = call(config, url, 'GET', nil, {Authorization = 'Bearer '..key})
	if not data then return nil, err, status end

	local list = typeof(data.data) == 'table' and data.data or nil
	if not list then return nil, 'the endpoint returned no model list' end

	local ids = {}
	for _, entry in list do
		if typeof(entry) == 'table' and typeof(entry.id) == 'string' then
			table.insert(ids, entry.id)
		end
	end

	return ids
end

-- true when the model is one the endpoint advertises. An endpoint that will not list
-- its models is treated as "cannot verify" rather than "invalid"
function llm.hasModel(config, model)
	local wanted = trim(model)
	if wanted == '' then return false, 'no model set' end

	local ids, err, status = llm.models(config)
	if not ids then
		-- a listing endpoint is optional: a 404 means the api simply does not expose
		-- /models, which is not evidence that the model is wrong. Any other failure
		-- means the check could not be made, so the completion is allowed to try
		if status == 404 or status == 405 then
			return nil, 'the endpoint does not list models'
		end

		return nil, err
	end

	for _, id in ids do
		if id == wanted then return true end
	end

	return false, 'the endpoint does not offer "'..wanted..'"'
end

-- one completion. `config` is {endpoint, key, model, messages, maxTokens, temperature}.
-- The model is verified first: a wrong name fails here, before a single token is spent
function llm.chat(config)
	local url = llm.resolveEndpoint(config and config.endpoint, '/chat/completions')
	if not url then return nil, 'no endpoint set' end

	local key = trim(config and config.key)
	if key == '' then return nil, 'no api key set' end

	local model = trim(config and config.model)
	if model == '' then return nil, 'no model set' end

	local known, modelErr = llm.hasModel(config, model)
	-- `false` means the endpoint listed its models and this one is not among them:
	-- stop here, before a completion is paid for. `nil` means the check could not be
	-- made, and the request is allowed to proceed
	if known == false then return nil, modelErr or ('unknown model "'..model..'"') end

	local messages = config and config.messages
	if typeof(messages) ~= 'table' or #messages == 0 then return nil, 'no messages to send' end

	local data, err = call(config, url, 'POST', {
		model = model,
		messages = messages,
		max_tokens = tonumber(config.maxTokens) or 120,
		temperature = tonumber(config.temperature) or 0.8
	}, {Authorization = 'Bearer '..key})

	if not data then return nil, err end

	local choice = typeof(data.choices) == 'table' and data.choices[1] or nil
	local message = typeof(choice) == 'table' and choice.message or nil
	local content = typeof(message) == 'table' and message.content or nil

	if typeof(content) ~= 'string' or content:match('^%s*$') then
		return nil, 'the api returned an empty reply'
	end

	return content
end

return llm
