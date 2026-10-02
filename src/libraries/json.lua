-- json.lua
-- Minimal JSON file I/O library for Roblox executors.
--
-- Usage:
--   local json = require(path.to.this.module)
--   json.write('newvape/data.json', { hello = 'world', n = 42 })
--   local data = json.read('newvape/data.json')
--
-- Encoder/decoder prefers executor globals (jsonEncode/jsonDecode) and falls
-- back to HttpService. File helpers are executor globals (writefile/readfile/
-- isfile/isfolder/makefolder) and are used directly.

local cloneref = cloneref or function(value)
	return value
end

local httpService = cloneref(game:GetService('HttpService'))

local encode, decode
if type(jsonEncode) == 'function' and type(jsonDecode) == 'function' then
	encode = jsonEncode
	decode = jsonDecode
else
	encode = function(value)
		return httpService:JSONEncode(value)
	end
	decode = function(str)
		return httpService:JSONDecode(str)
	end
end

local function ensureFolder(path)
	local dir = path:match('^(.*)[\\/]')
	if dir and dir ~= '' and not isfolder(dir) then
		makefolder(dir)
	end
end

local function write(path, content)
	ensureFolder(path)
	writefile(path, encode(content))
end

local function read(path)
	if not isfile(path) then
		return nil
	end

	local ok, result = pcall(decode, readfile(path))
	return ok and result or nil
end

return {
	write = write,
	read = read,
	encode = encode,
	decode = decode
}
