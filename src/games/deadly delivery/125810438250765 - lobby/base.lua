local run = function(func)
	func()
end
local cloneref = cloneref or function(obj)
	return obj
end

local playersService = cloneref(game:GetService('Players'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))

local lplr = playersService.LocalPlayer
local vape = shared.vape
local entitylib = vape.Libraries.entity
local targetinfo = vape.Libraries.targetinfo

-- Deadly Delivery (place 125810438250765, universe 8950496606) keeps its lobby in this place:
-- Workspace.LobbyScene is the hub, Workspace.Match holds one model per match pad, and the
-- actual run happens after joining a match. Nothing here uses the Team service or the Humanoid
-- replacement the game performs on its monsters, so the entity library default stays untouched.
-- The lobby state is all in Shared.Core.Value:
--   Value.MatchId.Value       the match the client is in, nil while standing in the lobby
--   Value.MatchInfo.Value     matchId -> {matchState, mode, size, onlyFriends, playerList}
--   Value.Backpack.Value      {count, size, ...}, joining is blocked while count >= size
-- Match pads are models tagged MatchModel with a MatchId attribute, and the game joins one by
-- firing the JoinMatch remote through Shared.Core.TEvent when the local player walks on it.
local deadlydelivery = {
	Match = nil,
	TEvent = nil,
	Value = nil
}

local function safeRequire(parent, name)
	local module = parent and parent:FindFirstChild(name)
	if not module then return end

	local suc, value = pcall(require, module)
	if suc and type(value) == 'table' then
		return value
	end
end

run(function()
	local shared = replicatedStorage:WaitForChild('Shared', 30)
	local core = shared and shared:WaitForChild('Core', 30)
	deadlydelivery.Value = safeRequire(core, 'Value')
	deadlydelivery.TEvent = safeRequire(core, 'TEvent')
	deadlydelivery.Match = workspace:FindFirstChild('Match')
end)

function deadlydelivery.matchId()
	local module = deadlydelivery.Value
	return module and module.MatchId and module.MatchId.Value or nil
end

function deadlydelivery.matches()
	local module = deadlydelivery.Value
	local info = module and module.MatchInfo and module.MatchInfo.Value
	return type(info) == 'table' and info or {}
end

function deadlydelivery.backpackFull()
	local module = deadlydelivery.Value
	local backpack = module and module.Backpack and module.Backpack.Value
	return type(backpack) == 'table' and backpack.count >= backpack.size
end

-- matchId -> model, so a match can be picked by distance like the game does when you walk on
-- a pad, or simply by the first id
function deadlydelivery.models()
	local found = {}
	local folder = deadlydelivery.Match or workspace:FindFirstChild('Match')
	if not folder then return found end

	for _, model in folder:GetChildren() do
		local id = model:GetAttribute('MatchId')
		if id then
			found[id] = model
		end
	end

	return found
end

function deadlydelivery.joinable(match)
	if type(match) ~= 'table' then return false end
	if match.matchState == 'Creating' then return false end
	if match.onlyFriends then return false end

	return true
end

function deadlydelivery.fire(name, ...)
	local event = deadlydelivery.TEvent
	if not (event and typeof(event.FireRemote) == 'function') then return false end

	return (pcall(event.FireRemote, name, ...))
end

function deadlydelivery.join(id)
	return deadlydelivery.fire('JoinMatch', id)
end

function deadlydelivery.leave()
	return deadlydelivery.fire('LeaveMatch')
end

-- joining only creates the match: the client then opens the Match panel and the run starts once
-- UploadSetting arrives with the party settings, otherwise the server drops the match after a
-- few seconds and the player is put back in the lobby
function deadlydelivery.upload(settings)
	return deadlydelivery.fire('UploadSetting', settings)
end

function deadlydelivery.dungeonLevel()
	local module = deadlydelivery.Value
	local data = module and module.DungeonData and module.DungeonData.Value
	return type(data) == 'table' and data.highestLevel or 0
end

-- the panel the game opens for a match is UIManager's 'Match' screen and stays on top after a
-- direct upload, so it is closed the same way the Create button closes it
function deadlydelivery.closeMatchUI()
	local client = replicatedStorage:FindFirstChild('Client')
	local core = client and client:FindFirstChild('Core')
	local module = core and core:FindFirstChild('UIManager')
	if not module then return end

	local suc, manager = pcall(require, module)
	if suc and manager and typeof(manager.CloseUI) == 'function' then
		pcall(manager.CloseUI, 'Match')
	end
end

vape.Libraries.deadlydelivery = deadlydelivery
vape:Clean(function()
	vape.Libraries.deadlydelivery = nil
	table.clear(deadlydelivery)
end)
