local adonis = {
	Name = 'Adonis',
	Game = '*'
}

local antiThreads = {}
local hooks = {}

local function getExecutorFunc(name)
	local fn = getgenv and getgenv()[name] or _G[name]
	return typeof(fn) == 'function' and fn or nil
end

local function hookFunction(original, replacement)
	if typeof(hookfunction) ~= 'function' then return original end
	if typeof(iscclosure) == 'function' and iscclosure(original) and typeof(oth) == 'table' and typeof(oth.hook) == 'function' then
		return oth.hook(original, replacement)
	end
	if typeof(islclosure) == 'function' and islclosure(replacement) and typeof(newcclosure) == 'function' then
		replacement = newcclosure(replacement)
	end
	return hookfunction(original, replacement)
end

function adonis.Detect()
	if typeof(getreg) ~= 'function' or typeof(getgc) ~= 'function' or typeof(isfunctionhooked) ~= 'function' then
		return false
	end

	local detected = false
	local ok, regs = pcall(getreg)
	if not ok or type(regs) ~= 'table' then return false end

	for _, thread in regs do
		if typeof(thread) ~= 'thread' then continue end

		local sok, source = pcall(debug.info, thread, 1, 's')
		if sok and source and (source:find('.Core.Anti', 1, true) or source:find('.Plugins.Anti_Cheat', 1, true)) then
			detected = true
			antiThreads[#antiThreads + 1] = thread
		end
	end

	return detected
end

function adonis.Bypass()
	if typeof(coroutine) == 'table' and typeof(coroutine.close) == 'function' then
		for _, thread in antiThreads do
			pcall(coroutine.close, thread)
		end
	end

	local adonisTables = {}
	if typeof(filtergc) == 'function' then
		local ok, result = pcall(filtergc, 'table', {Keys = {'Detected', 'RLocked'}}, false)
		if ok and type(result) == 'table' then
			for _, adonisTable in result do
				if typeof(rawget(adonisTable, 'Detected')) ~= 'function' then continue end
				adonisTables[#adonisTables + 1] = adonisTable
			end
		end
	else
		local ok, objects = pcall(getgc, true)
		if ok and type(objects) == 'table' then
			for _, object in objects do
				if type(object) ~= 'table' then continue end
				local isAdonisOrigin = typeof(rawget(object, 'Detected')) == 'function' and rawget(object, 'RLocked')
				if not isAdonisOrigin then continue end
				adonisTables[#adonisTables + 1] = object
			end
		end
	end

	for _, adonisTable in adonisTables do
		for _, detectionFunc in adonisTable do
			if typeof(detectionFunc) ~= 'function' or (typeof(isfunctionhooked) == 'function' and isfunctionhooked(detectionFunc)) or hooks[detectionFunc] then
				continue
			end

			hooks[detectionFunc] = hookFunction(detectionFunc, function(action, info, nocrash)
				coroutine.yield()
				return task.wait(9e9)
			end)
		end
	end

	return true
end

function adonis.Start()
	if not adonis.Detect() then return false end
	return adonis.Bypass()
end

function adonis.Restore()
	for detectionFunc, original in hooks do
		pcall(hookfunction, detectionFunc, original)
	end

	table.clear(hooks)
	table.clear(antiThreads)
end

return adonis
