local isfile = isfile or function(file)
	local suc, res = pcall(function()
		return readfile(file)
	end)
	return suc and res ~= nil and res ~= ''
end
local delfile = delfile or function(file)
	writefile(file, '')
end

local function correct(path)
	return isfile(path) and select(1, readfile(path):find('--This watermark is used to delete the file if its cached, remove it to make the file persist after inhaler updates.', 1, true)) == 1
end

local function downloadFile(path, func)
	if not correct(path) then
		if isfile(path) then
			delfile(path)
		end

		local suc, res = pcall(function()
			local commit = isfile('InhalerV4/profiles/commit.txt') and readfile('InhalerV4/profiles/commit.txt') or 'main'
			return game:HttpGet('https://raw.githubusercontent.com/Night5449791/InhalerCompiled/'..commit..'/'..select(1, path:gsub('InhalerV4/', '')), true)
		end)
		if not suc or res == '404: Not Found' then
			error(res)
		end
		if path:find('.lua') then
			res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after inhaler updates.\n'..res
		end
		writefile(path, res)
	end
	return (func or readfile)(path)
end

local function wipeFolder(path)
	if not isfolder(path) then return end
	for _, file in listfiles(path) do
		if not isfile(file) then continue end
		if file:find('loader') then continue end
		if correct(file) then
			delfile(file)
		end
	end
end

for _, folder in {'InhalerV4', 'InhalerV4/games', 'InhalerV4/profiles', 'InhalerV4/assets', 'InhalerV4/libraries', 'InhalerV4/guis'} do
	if not isfolder(folder) then
		makefolder(folder)
	end
end

if not shared.VapeDeveloper then
	local _, subbed = pcall(function()
		return game:HttpGet('https://github.com/Night5449791/InhalerCompiled')
	end)

	local assetVer = '1'
	local commit = subbed:find('currentOid')
	commit = commit and subbed:sub(commit + 13, commit + 52) or nil
	commit = commit and #commit == 40 and commit or 'main'

	if commit == 'main' or (isfile('InhalerV4/profiles/commit.txt') and readfile('InhalerV4/profiles/commit.txt') or '') ~= commit then
		wipeFolder('InhalerV4')
		wipeFolder('InhalerV4/games')
		wipeFolder('InhalerV4/guis')
		wipeFolder('InhalerV4/libraries')
	end

	if (isfile('InhalerV4/profiles/asset.txt') and readfile('InhalerV4/profiles/asset.txt') or '') ~= assetVer then
		wipeFolder('InhalerV4/assets')
	end

	writefile('InhalerV4/profiles/asset.txt', assetVer)
	writefile('InhalerV4/profiles/commit.txt', commit)
end

if not isfile('InhalerV4/profiles/isvape.txt') then
	if isfolder('newvape/profiles') then
		for _, file in listfiles('newvape/profiles') do
			if isfile(file) then
				local name = file:match('([^/\\]+)$')
				if name and name ~= 'asset.txt' and name ~= 'commit.txt' then
					pcall(function()
						writefile('InhalerV4/profiles/'..name, readfile(file))
					end)
				end
			end
		end
	end
	writefile('InhalerV4/profiles/isvape.txt', 'false')
end

return loadstring(downloadFile('InhalerV4/main.lua'), 'main')()