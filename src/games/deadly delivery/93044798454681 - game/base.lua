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

-- Deadly Delivery run place (Underground, 93044798454681). The lobby is a separate product, this
-- half is the dungeon the match teleports into.
-- Everything is routed through one Remote_Event with a name string, the wrappers are in
-- Shared.Core.TEvent (FireRemote(name, ...)) and the shared client state in Shared.Core.Value.
-- Loot and containers are models under Workspace.GameSystem (Loots, InteractiveItem) and carry
-- their own attributes (Looted, Open, w, sz) instead of ProximityPrompts.
local dungeon = {
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
	dungeon.Value = safeRequire(core, 'Value')
	dungeon.TEvent = safeRequire(core, 'TEvent')
end)

function dungeon.fire(name, ...)
	local event = dungeon.TEvent
	if not (event and typeof(event.FireRemote) == 'function') then return false end

	return (pcall(event.FireRemote, name, ...))
end

function dungeon.value(name)
	local module = dungeon.Value
	local value = module and module[name]
	return value and value.Value or nil
end

function dungeon.backpack()
	return dungeon.value('Backpack')
end

function dungeon.interactTarget()
	return dungeon.value('InteractTarget')
end

function dungeon.gameSystem(name)
	local system = workspace:FindFirstChild('GameSystem')
	return system and system:FindFirstChild(name) or nil
end

function dungeon.character()
	local character = lplr.Character
	if not character then return end

	return character, character:FindFirstChildOfClass('Humanoid'), character:FindFirstChild('HumanoidRootPart')
end

function dungeon.position()
	local _, _, root = dungeon.character()
	return root and root.Position
end

local function interactableOf(item)
	if item:IsA('Model') then
		return item:FindFirstChild('Interactable') or item.PrimaryPart
	end
end

-- loot that dropped in the level: every model in Loots.World that carries an Interactable part
function dungeon.loot()
	local folder = dungeon.gameSystem('Loots')
	folder = folder and folder:FindFirstChild('World')

	local found = {}
	if not folder then return found end

	for _, item in folder:GetChildren() do
		local part = interactableOf(item)
		if part then
			table.insert(found, {Model = item, Part = part})
		end
	end

	return found
end

-- containers the level generates (crates, cabinets, soil mounds, oil buckets); Looted marks the
-- ones that already gave their loot up
function dungeon.containers()
	local folder = dungeon.gameSystem('InteractiveItem')

	local found = {}
	if not folder then return found end

	for _, item in folder:GetChildren() do
		local part = interactableOf(item)
		if part and item:GetAttribute('Looted') ~= true then
			table.insert(found, {Model = item, Part = part})
		end
	end

	return found
end

function dungeon.interact(model)
	return dungeon.fire('Interactable', model)
end

-- picked up loot does not go to Value.Item (that table is the money and resource counters:
-- 101 money, 201/301/1301 materials). The character physically carries each piece, and the
-- client sees them as tools in GameSystem.Loots.Player.
function dungeon.carried()
	local folder = dungeon.gameSystem('Loots')
	folder = folder and folder:FindFirstChild('Player')

	local found = {}
	if not folder then return found end

	for _, item in folder:GetChildren() do
		table.insert(found, item)
	end

	return found
end

function dungeon.itemCount()
	return #dungeon.carried()
end

-- The game drives the humanoid itself: MoveTo does nothing and any velocity written to the root
-- is zeroed on the next step, so the only way to move the character is to step its CFrame. The
-- step is kept small (4 studs) and paced, which looks like fast walking instead of one long jump.
function dungeon.walkTo(position, timeout)
	local _, humanoid, root = dungeon.character()
	if not (humanoid and root) then return false end

	local deadline = os.clock() + (timeout or 12)
	local attempts = 0

	while os.clock() < deadline do
		local current = root.Position
		local delta = position - current
		local distance = delta.Magnitude
		if distance <= 4 then return true end

		local step = math.min(4, distance)
		root.CFrame = CFrame.lookAt(current + delta.Unit * step, position)
		task.wait(0.12)

		-- a step that did not move the character means the way is blocked: nudge it sideways,
		-- then backwards, and jump on the way so a step or a low prop does not park the loop
		if (root.Position - current).Magnitude < 1 then
			attempts = attempts + 1
			local side = delta.Unit:Cross(Vector3.yAxis)
			if side.Magnitude > 0 then
				side = side.Unit
			else
				side = Vector3.xAxis
			end

			humanoid.Jump = true
			local offset
			if attempts % 3 == 1 then
				offset = side * 4
			elseif attempts % 3 == 2 then
				offset = -side * 4
			else
				offset = -delta.Unit * 5
			end

			root.CFrame = root.CFrame + offset
			task.wait(0.1)

			if attempts >= 9 then return false end
		else
			attempts = 0
		end
	end

	return (root.Position - position).Magnitude <= 6
end

vape.Libraries.dungeon = dungeon
vape:Clean(function()
	vape.Libraries.dungeon = nil
	table.clear(dungeon)
end)
