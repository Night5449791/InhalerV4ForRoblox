local run = function(func)
	func()
end
local cloneref = cloneref or function(obj)
	return obj
end

local playersService = cloneref(game:GetService('Players'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local runService = cloneref(game:GetService('RunService'))

local gameCamera = workspace.CurrentCamera
local lplr = playersService.LocalPlayer
local vape = shared.vape
local entitylib = vape.Libraries.entity
local whitelist = vape.Libraries.whitelist
local targetinfo = vape.Libraries.targetinfo
local sessioninfo = vape.Libraries.sessioninfo

local friends = vape.Categories.Friends
local useFriends = friends.Options['Use friends']
local recolorFriends = friends.Options['Recolor visuals']
local friendsColor = friends.Options['Friends color']

local israel = {
	Tycoons = nil,
	Config = nil,
	Remotes = nil
}

local function isFriend(plr, recolor)
	if not useFriends.Enabled then return nil end

	local friend = table.find(friends.ListEnabled, plr.Name) and true
	if recolor then
		friend = friend and recolorFriends.Enabled
	end

	return friend
end

local function notif(...)
	return vape:CreateNotification(...)
end

function israel.tycoonsFolder()
	israel.Tycoons = israel.Tycoons or workspace:FindFirstChild('IsraelTycoons')
	return israel.Tycoons
end

-- the plot a player owns, read off PlotIndex so it survives them respawning
function israel.plot(plr)
	plr = plr or lplr
	if not plr then return end

	local folder = israel.tycoonsFolder()
	local index = plr:GetAttribute('PlotIndex')
	if not folder or not index then return end

	return folder:FindFirstChild('Plot'..index)
end

function israel.plotOwner(plot)
	local userId = plot and plot:GetAttribute('OwnerUserId')
	if typeof(userId) ~= 'number' or userId == 0 then return end

	for _, plr in playersService:GetPlayers() do
		if plr.UserId == userId then
			return plr
		end
	end
end

function israel.shielded(plr)
	local plot = israel.plot(plr)
	if not plot then return false end

	return plot:GetAttribute('NewbieShield') == true
end

function israel.cash(plr)
	plr = plr or lplr
	return plr and plr:GetAttribute('Cash') or 0
end

function israel.rebirths(plr)
	plr = plr or lplr
	return plr and plr:GetAttribute('Rebirths') or 0
end

run(function()
	local folder = replicatedStorage:WaitForChild('IsraelTycoon', 30)
	if not folder then return end

	local remotes = folder:WaitForChild('Remotes', 30)
	if remotes then
		israel.Remotes = remotes
	end

	local config = folder:FindFirstChild('Config')
	if config then
		local suc, loaded = pcall(require, config)
		if suc then
			israel.Config = loaded
		end
	end
end)

vape.Libraries.israel = israel
vape:Clean(function()
	vape.Libraries.israel = nil
	table.clear(israel)
end)

run(function()
	entitylib.targetCheck = function(entity)
		if entity.TeamCheck then
			return entity:TeamCheck()
		end

		if entity.Health <= 0 then return false end

		if entity.Player then
			if isFriend(entity.Player) then return false end
			if not select(2, whitelist:get(entity.Player)) then return false end
		end

		return true
	end

	entitylib.getEntityColor = function(ent)
		if isFriend(ent.Player, true) then
			return Color3.fromHSV(friendsColor.Hue, friendsColor.Sat, friendsColor.Value)
		end
	end
end)
entitylib.start()

sessioninfo:AddItem('Shekels', 0, function()
	return tostring(israel.cash())
end, false)
sessioninfo:AddItem('Rebirths', 0, function()
	return tostring(israel.rebirths())
end, false)

for _, v in {'MurderMystery'} do
	vape:Remove(v)
end
