local run = function(func)
	func()
end
local cloneref = cloneref or function(obj)
	return obj
end

local playersService = cloneref(game:GetService('Players'))
local inputService = cloneref(game:GetService('UserInputService'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local runService = cloneref(game:GetService('RunService'))

local gameCamera = workspace.CurrentCamera
local lplr = playersService.LocalPlayer
local vape = shared.vape
local entitylib = vape.Libraries.entity
local targetinfo = vape.Libraries.targetinfo
local redwood = {
	Remotes = nil,
	Teams = {
		Fugitive = 'Fugitive',
		Guards = 'Guards',
		Neutral = 'Neutral',
		Prisoners = 'Prisoners',
		Krampus = 'Krampus',
		Military = 'Military',
	}
}

local function isFriend(plr, recolor)
	if vape.Categories.Friends.Options['Use friends'].Enabled then
		local friend = table.find(vape.Categories.Friends.ListEnabled, plr.Name) and true
		if recolor then
			friend = friend and vape.Categories.Friends.Options['Recolor visuals'].Enabled
		end
		return friend
	end
	return nil
end

local function notif(...)
	return vape:CreateNotification(...)
end

local function waitForChildOfType(obj, name, timeout, prop)
	local checktick = tick() + timeout
	local returned
	repeat
		returned = prop and obj[name] or obj:FindFirstChildOfClass(name)
		if returned or checktick < tick() then break end
		task.wait()
	until false
	return returned
end

function redwood.attributeFolder(char)
	return char and char:FindFirstChild('AttributeFolder') or nil
end

function redwood.state(char, name)
	local folder = redwood.attributeFolder(char)
	local state = folder and folder:FindFirstChild(name)
	return state and state.Value or nil
end

function redwood.hasState(char, name)
	local folder = redwood.attributeFolder(char)
	return folder ~= nil and folder:FindFirstChild(name) ~= nil
end

function redwood.team(plr)
	return plr and plr.Team and plr.Team.Name or nil
end

function redwood.isTeam(plr, team)
	return redwood.team(plr) == team
end

function redwood.fire(name, ...)
	local remotes = redwood.Remotes
	local remote = remotes and remotes:FindFirstChild(name)
	if not remote or typeof(remote.FireServer) ~= 'function' then return end

	pcall(remote.FireServer, remote, ...)
end

function redwood.invoke(name, ...)
	local remotes = redwood.Remotes
	local remote = remotes and remotes:FindFirstChild(name)
	if not remote or typeof(remote.InvokeServer) ~= 'function' then return end

	local suc, result = pcall(remote.InvokeServer, remote, ...)
	return suc and result or nil
end

function redwood.nearestPlayer(team, range)
	local character = lplr.Character
	local root = character and character:FindFirstChild('HumanoidRootPart')
	if not root then return end

	local closest, closestDistance = nil, range or math.huge
	for _, plr in playersService:GetPlayers() do
		if plr ~= lplr and (not team or redwood.isTeam(plr, team)) then
			local char = plr.Character
			local other = char and char:FindFirstChild('HumanoidRootPart')
			local humanoid = char and char:FindFirstChildOfClass('Humanoid')
			if other and humanoid and humanoid.Health > 0 then
				local magnitude = (other.Position - root.Position).Magnitude
				if magnitude < closestDistance then
					closest, closestDistance = plr, magnitude
				end
			end
		end
	end

	return closest
end

local function addressValue(value)
	if type(value) ~= 'table' then return tonumber(value) or 0 end

	local min, max = tonumber(value[1]), tonumber(value[2])
	if not min then return 0 end
	if max then return Random.new():NextNumber(min, max) end
	return min
end

function redwood.humanoid(character)
	return character and character:FindFirstChildOfClass('Humanoid') or nil
end

function redwood.isDead(plr)
	local character = plr and plr.Character
	local humanoid = redwood.humanoid(character)
	return humanoid == nil or humanoid.Health <= 0
end

local hostileTeams = {
	[redwood.Teams.Guards] = {[redwood.Teams.Prisoners] = true, [redwood.Teams.Fugitive] = true},
	[redwood.Teams.Prisoners] = {[redwood.Teams.Guards] = true},
	[redwood.Teams.Fugitive] = {[redwood.Teams.Guards] = true}
}

function redwood.isTarget(plr, strict)
	if not plr or plr == lplr or isFriend(plr) or redwood.isDead(plr) then return false end
	if redwood.hasState(plr.Character, 'Handcuffed_') then return false end

	local myTeam, team = redwood.team(lplr), redwood.team(plr)
	if strict and myTeam and team then
		local allowed = hostileTeams[myTeam]
		return allowed ~= nil and allowed[team] == true
	end

	return not (team and myTeam and team == myTeam)
end

function redwood.targetCheck(ent)
	if not ent or ent.NPC then return false end

	local plr = ent.Player
	if not plr or plr == lplr or isFriend(plr) then return false end
	if ent.Health and ent.Health <= 0 then return false end
	if ent.Character and redwood.hasState(ent.Character, 'Handcuffed_') then return false end

	local myTeam, team = redwood.team(lplr), redwood.team(plr)
	return not (team and myTeam and team == myTeam)
end

function redwood.meleeTool()
	local character = lplr.Character
	if not character then return end

	for _, tool in character:GetChildren() do
		if tool:IsA('Tool') then
			local server = tool:FindFirstChild('MeleeScriptServer')
			if server and server:FindFirstChild('InflictTarget') then
				return tool
			end
		end
	end
end

function redwood.attack(target, partName)
	local tool = redwood.meleeTool()
	if not tool then return false end

	local remote = tool.MeleeScriptServer:FindFirstChild('InflictTarget')
	local setting = tool:FindFirstChild('Setting')
	local frame = setting and setting:FindFirstChild('1')
	local character = target and (target.Character or target)
	if not (remote and frame and character) then return false end

	local suc, config = pcall(require, frame)
	if not suc or type(config) ~= 'table' then return false end

	local humanoid = redwood.humanoid(character)
	local root = character:FindFirstChild('HumanoidRootPart')
	local part = (partName and character:FindFirstChild(partName)) or character:FindFirstChild('Head') or root
	if not (part and humanoid and root) then return false end
	if humanoid.Health <= 0 then return false end

	local combo = tool:FindFirstChild('Combo')

	return pcall(remote.FireServer, remote, part, part.Position, nil, humanoid, root, addressValue(config.BaseDamage), addressValue(config.BackstabDamage), gameCamera.CFrame.LookVector, false, combo and combo.Value or 1)
end

vape.Libraries.redwood = redwood
vape:Clean(function()
	vape.Libraries.redwood = nil
	redwood.Remotes = nil
end)

run(function()
	local storage = replicatedStorage:WaitForChild('Storage', 30)
	local remotes = storage and storage:WaitForChild('Remotes', 30)
	if not remotes then return end

	redwood.Remotes = remotes
end)

local function gcTables(keys)
	if typeof(filtergc) == 'function' then
		return filtergc('table', {Keys = keys}, false)
	end

	local found = {}
	if typeof(getgc) ~= 'function' then return found end

	for _, object in getgc(true) do
		if type(object) ~= 'table' then continue end

		local matches = true
		for _, key in keys do
			if rawget(object, key) == nil then
				matches = false
				break
			end
		end

		if matches then
			table.insert(found, object)
		end
	end

	return found
end

run(function()
	task.delay(3, function()
		task.spawn(function()
			local patched = {}

			while shared.vape and shared.vape.Loaded ~= nil do
				for _, core in gcTables({'Detected', 'RLocked', 'AddDetector', 'Detectors'}) do
					if not patched[core] and type(core.Detectors) == 'table' and typeof(core.Detected) == 'function' then
						patched[core] = true

						rawset(core, 'Detected', function()
							return false
						end)
					end
				end

				task.wait(2)
			end
		end)
	end)
end)

run(function()
	entitylib.targetCheck = redwood.targetCheck

	entitylib.getEntityColor = function(ent)
		if not (ent.Player and vape.Settings.Modules.Options['Use team color'].Enabled) then return end
		if isFriend(ent.Player, true) then
			return Color3.fromHSV(vape.Categories.Friends.Options['Friends color'].Hue, vape.Categories.Friends.Options['Friends color'].Sat, vape.Categories.Friends.Options['Friends color'].Value)
		end

		local team = ent.Player.Team
		return team and team.TeamColor.Color
	end
end)

for _, v in {'MurderMystery'} do
	vape:Remove(v)
end
