-- adonis bypass for inhaler v4
-- adonis cries

local adonis = {
	Detected = false,
	Active = false
}

local genv = typeof(getgenv) == 'function' and getgenv() or nil
local debugInfo = typeof(debug) == 'table' and typeof(debug.info) == 'function' and debug.info or nil
local originals = {}
local antiThreads = {}

local function executorFunc(name)
	local fn = genv and genv[name] or _G[name]
	return typeof(fn) == 'function' and fn or nil
end

local function findDetectionTables()
	local found = {}
	local filtergc = executorFunc('filtergc')
	if filtergc then
		local ok, res = pcall(filtergc, 'table', {Keys = {'Detected', 'RLocked'}}, false)
		if ok and type(res) == 'table' then
			for _, object in res do
				found[#found + 1] = object
			end
		end
	end

	if found[1] then return found end

	local getgc = executorFunc('getgc')
	if not getgc then return found end

	local ok, objects = pcall(getgc, true)
	if not ok or type(objects) ~= 'table' then return found end

	for _, object in objects do
		if type(object) == 'table' and rawget(object, 'Detected') ~= nil and rawget(object, 'RLocked') ~= nil then
			found[#found + 1] = object
		end
	end

	return found
end

local function collectThreads()
	table.clear(antiThreads)
	local getreg = executorFunc('getreg')
	if not (getreg and debugInfo) then return end

	local ok, regs = pcall(getreg)
	if not ok or type(regs) ~= 'table' then return end

	for _, thread in regs do
		if typeof(thread) == 'thread' then
			local sok, source = pcall(debugInfo, thread, 1, 's')
			if sok and type(source) == 'string' then
				if source:find('.Core.Anti', 1, true) or source:find('.Plugins.Anti_Cheat', 1, true) then
					antiThreads[#antiThreads + 1] = thread
				end
			end
		end
	end
end

function adonis.Detect()
	if adonis.Detected then return true end
	collectThreads()
	adonis.Detected = #antiThreads > 0 or #findDetectionTables() > 0
	return adonis.Detected
end

local function hangDetection()
	coroutine.yield()
	return task.wait(9e9)
end

function adonis.Bypass()
	if adonis.Active then return true end
	if not adonis.Detect() then return false end

	local close = typeof(coroutine) == 'table' and typeof(coroutine.close) == 'function' and coroutine.close or nil
	if close then
		for _, thread in antiThreads do
			pcall(close, thread)
		end
	end

	local hookfunction = executorFunc('hookfunction')
	if not hookfunction then
		adonis.Active = true
		return true
	end

	local newcclosure = executorFunc('newcclosure')
	local hook = newcclosure and newcclosure(hangDetection) or hangDetection
	local isfunctionhooked = executorFunc('isfunctionhooked')

	for _, detectionTable in findDetectionTables() do
		for _, fn in detectionTable do
			if typeof(fn) == 'function' and not originals[fn] then
				local alreadyHooked = false
				if isfunctionhooked then
					local ok, res = pcall(isfunctionhooked, fn)
					alreadyHooked = ok and res == true
				end

				if not alreadyHooked then
					local ok, original = pcall(hookfunction, fn, hook)
					if ok and original then
						originals[fn] = original
					end
				end
			end
		end
	end

	adonis.Active = true
	return true
end

function adonis.Start()
	return adonis.Bypass()
end

function adonis.Restore()
	local hookfunction = executorFunc('hookfunction')
	if hookfunction then
		for fn, original in originals do
			pcall(hookfunction, fn, original)
		end
	end

	table.clear(originals)
	table.clear(antiThreads)
	adonis.Active = false
	adonis.Detected = false
end

return adonis
