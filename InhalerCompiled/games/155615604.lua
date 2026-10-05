local run = function(func)
	func()
end
local cloneref = cloneref or function(obj)
	return obj
end
local vapeEvents = setmetatable({}, {
	__index = function(self, index)
		self[index] = Instance.new('BindableEvent')
		return self[index]
	end
})

local playersService = cloneref(game:GetService('Players'))
local inputService = cloneref(game:GetService('UserInputService'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local replicatedFirst = cloneref(game:GetService('ReplicatedFirst'))
local collectionService = cloneref(game:GetService('CollectionService'))
local marketplaceService = cloneref(game:GetService('MarketplaceService'))
local textChatService = cloneref(game:GetService('TextChatService'))
local tweenService = cloneref(game:GetService('TweenService'))
local runService = cloneref(game:GetService('RunService'))
local guiService = cloneref(game:GetService('GuiService'))
local teleportService = cloneref(game:GetService('TeleportService'))
local teams = cloneref(game:GetService('Teams'))
local coreGui = cloneref(game:GetService('CoreGui'))

local gameCamera = workspace.CurrentCamera
local lplr = playersService.LocalPlayer
local vape = shared.vape
local entitylib = vape.Libraries.entity
local whitelist = vape.Libraries.whitelist
local targetinfo = vape.Libraries.targetinfo
local sessioninfo = vape.Libraries.sessioninfo
local getfontbounds = vape.Libraries.getfontbounds

local pl = {}
local Spring = {}
local TracerHook = {Hooks = {}}
local VehicleWallbang = {Enabled = false}
local oldshoot, oldequip
local aimTimer, shootTimer, aimVec = os.clock(), os.clock()
local arrestCooldown = os.clock()
local tempTargets = {}
local gamepasses = {}
local flatMask = Vector3.new(1, 0, 1)

local function checkPoint(pos, params)
	for _, part in workspace:GetPartBoundsInRadius(pos, 0, params) do
		if part.CanCollide and (part:GetClosestPointOnSurface(pos) - pos).Magnitude <= 0.0001 then
			return false
		end
	end

	return true
end

local function canClick()
	local mousePosition = (inputService:GetMouseLocation() - guiService:GetGuiInset())

	for _, hit in lplr.PlayerGui:GetGuiObjectsAtPosition(mousePosition.X, mousePosition.Y) do
		local obj = hit:FindFirstAncestorOfClass('ScreenGui')
		if hit.Active and hit.Visible and obj and obj.Enabled then
			return false
		end
	end

	for _, hit in coreGui:GetGuiObjectsAtPosition(mousePosition.X, mousePosition.Y) do
		local obj = hit:FindFirstAncestorOfClass('ScreenGui')
		if hit.Active and hit.Visible and obj and obj.Enabled then
			return false
		end
	end

	return (not vape.gui.ScaledGui.ClickGui.Visible) and (not inputService:GetFocusedTextBox())
end

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

local function isTarget(plr)
	return (table.find(vape.Categories.Targets.ListEnabled, plr.Name) or tempTargets[plr.Name]) and true
end

local function notif(...)
	return vape:CreateNotification(...)
end

local function removeTags(str)
	str = str:gsub('<br%s*/>', '\n')
	return (str:gsub('<[^<>]->', ''))
end

local OriginScanner = {Cache = {}}
run(function()
	local rayParams = RaycastParams.new()
	local overlapParams = OverlapParams.new()
	rayParams.CollisionGroup = 'ClientBullet'
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.CollisionGroup = 'ClientBullet'
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	OriginScanner.Ray = rayParams

	local normals = Enum.NormalId:GetEnumItems()
	local positions = {
		Vector3.new(0, 1, 0),
		Vector3.new(1, 0, 0),
		Vector3.new(0.7, -0.5, -0.5),
		Vector3.new(-0.1, -0.8, -0.8),
		Vector3.new(-0.8, -0.5, -0.5),
		Vector3.new(-1, 0, 0),
		Vector3.new(-0.8, 0.4, 0.4),
		Vector3.new(0, 0.7, 0.7),
		Vector3.new(0.7, 0.5, 0.5),
		Vector3.new(1, 0, 0),
		Vector3.new(0.7, 0, -0.8),
		Vector3.new(-0.1, 0, -1),
		Vector3.new(-0.8, 0, -0.8),
		Vector3.new(-1, 0, 0),
		Vector3.new(-0.8, 0, 0.7),
		Vector3.new(0, 0, 1),
		Vector3.new(0.7, 0, 0.7),
		Vector3.new(1, 0, 0),
		Vector3.new(0.7, 0.4, -0.5),
		Vector3.new(-0.1, 0.7, -0.8),
		Vector3.new(-0.8, 0.4, -0.5),
		Vector3.new(-1, -0.1, 0),
		Vector3.new(-0.8, -0.5, 0.4),
		Vector3.new(0, -0.8, 0.7),
		Vector3.new(0.7, -0.6, 0.5),
		Vector3.new(0, -1, 0)
	}

	function OriginScanner:Scan(origin, target, extra, part, entity)
		if self.Cache[part] then
			return table.unpack(self.Cache[part])
		end

		local hitboxPositions = {}
		if checkPoint(target, overlapParams) then
			if extra and (origin - extra).Magnitude < 7.5 then
				self.Cache[part] = {extra}
				return extra
			end

			table.insert(hitboxPositions, target)
		end

		local scanPositions = {origin}
		local diff = CFrame.lookAt(origin * flatMask, target * flatMask).LookVector
		local rootPosition = entity.RootPart.Position
		for _, normal in normals do
			local offset = Vector3.fromNormalId(normal)

			if (offset * flatMask):Dot(-diff) > -0.5 then
				local pos = rootPosition + offset * 7.4

				if checkPoint(pos, overlapParams) then
					table.insert(hitboxPositions, pos)
				end
			end
		end

		for _, offset in positions do
			if (offset * flatMask):Dot(diff) > -0.5 then
				local pos = origin + offset * 6

				if checkPoint(pos, overlapParams) then
					table.insert(scanPositions, pos)
				end
			end
		end

		for _, hitbox in hitboxPositions do
			for _, pos in scanPositions do
				local ray = workspace:Raycast(hitbox, (pos - hitbox), rayParams)

				if not ray then
					self.Cache[part] = {pos, hitbox ~= target and hitbox or nil}
					return pos, hitbox
				end
			end
		end
	end

	function OriginScanner:UpdateIgnore()
		-- a nil character here would leave a hole at index 1 and drop the whole
		-- array, leaving nothing ignored so every wallbang scan gets blocked
		local ignoreList = {}
		if lplr.Character then
			table.insert(ignoreList, lplr.Character)
		end

		if VehicleWallbang.Enabled then
			table.insert(ignoreList, workspace.CarContainer)
		end

		for _, entity in entitylib.List do
			if entity.Character then
				table.insert(ignoreList, entity.Character)
			end
		end

		rayParams.FilterDescendantsInstances = ignoreList
		overlapParams.FilterDescendantsInstances = ignoreList
	end
end)

local Cheats = {Flags = {}, Flagged = {}, FlaggedInfo = {}}
run(function()
	function Cheats:Flag(plr, flagType, limit)
		if self.Flagged[plr.UserId] then
			return
		end

		if not self.Flags[plr.UserId] then
			self.Flags[plr.UserId] = {}
		end

		local flags = self.Flags[plr.UserId]
		flags[flagType] = (flags[flagType] or 0) + 1

		if flags[flagType] > limit then
			self.Flagged[plr.UserId] = true
			self.FlaggedInfo[plr.UserId] = flagType
			vapeEvents.CheatFlagged:Fire(plr, flagType)
		end
	end

	function Cheats:Clear()
		table.clear(self.Flags)
		table.clear(self.Flagged)
		table.clear(self.FlaggedInfo)
	end
end)

run(function()
	local function getMousePosition()
		if inputService.TouchEnabled then
			return gameCamera.ViewportSize / 2
		end
		return inputService.GetMouseLocation(inputService)
	end

	entitylib.getUpdateConnections = function(entity)
		local humanoid = entity.Humanoid
		return {
			humanoid:GetPropertyChangedSignal('Health'),
			humanoid:GetPropertyChangedSignal('MaxHealth'),
			entity.Character:GetAttributeChangedSignal('Trespassing'),
			entity.Character:GetAttributeChangedSignal('Hostile'),
			entity.Player:GetAttributeChangedSignal('InnocentKills'),
			{
				Connect = function()
					entity.Friend = entity.Player and isFriend(entity.Player) or nil
					entity.Target = entity.Player and isTarget(entity.Player) or nil
					return {Disconnect = function() end}
				end
			}
		}
	end

	entitylib.targetCheck = function(entity, skip)
		if entity.TeamCheck then
			return entity:TeamCheck()
		end
		if entity.NPC then return true end
		if isFriend(entity.Player) then return false end
		if not select(2, whitelist:get(entity.Player)) then return false end
		if vape.Settings.Modules.Options['Teams by server'].Enabled and (not skip or lplr.Team == teams.Guards) then
			return lplr.Team ~= entity.Player.Team and entity.Player.Team ~= teams.Neutral
		end
		return true
	end

	entitylib.isVulnerable = function(entity, attackCheck, skipCheck)
		if attackCheck and lplr.Team == teams.Guards and entity.Player.Team == teams.Inmates and not entity.Character:GetAttribute('Hostile') then
			return false
		end

		return entity.Health > 0 and entity.Humanoid:GetState() ~= Enum.HumanoidStateType.Dead and entity.SpawnTime < os.clock() and not entity.Character.FindFirstChildWhichIsA(entity.Character, 'ForceField') and (entity.Player.Team ~= teams.Inmates or (skipCheck or entity.Character:GetAttribute('Trespassing') or entity.Character:GetAttribute('Hostile')))
	end

	entitylib.EntityMouse = function(entitysettings)
		if entitylib.isAlive then
			local mouseLocation, sortingTable = entitysettings.MouseOrigin or getMousePosition(), {}
			local localPosition = entitysettings.Origin or entitylib.character.HumanoidRootPart.Position
			local partName = entitysettings.Part
			for _, entity in entitylib.List do
				if not entitysettings.Players and entity.Player then continue end
				if not entitysettings.NPCs and entity.NPC then continue end
				if not entity.Targetable then continue end
				local part = entity[partName]
				local position, vis = gameCamera.WorldToViewportPoint(gameCamera, part.Position)
				if not vis then continue end
				local mag = (mouseLocation - Vector2.new(position.x, position.y)).Magnitude
				if mag > entitysettings.Range then continue end
				if entitylib.isVulnerable(entity, entitysettings.AttackCheck) then
					if entitysettings.RangePosition then
						local pmag = (part.Position - localPosition).Magnitude
						if pmag > entitysettings.RangePosition then continue end
					end

					table.insert(sortingTable, {
						Entity = entity,
						Magnitude = entity.Target and -1 or mag
					})
				end
			end

			table.sort(sortingTable, entitysettings.Sort or function(a, b)
				return a.Magnitude < b.Magnitude
			end)

			for _, v in sortingTable do
				if entitysettings.Wallcheck then
					local part = v.Entity[partName]
					if entitylib.Wallcheck(entitysettings.Origin, part.Position, entitysettings.Wallbang, part, v.Entity) then continue end
				end
				table.clear(entitysettings)
				table.clear(sortingTable)
				return v.Entity
			end
			table.clear(sortingTable)
		end
		table.clear(entitysettings)
	end

	entitylib.EntityPosition = function(entitysettings)
		if entitylib.isAlive then
			local localPosition, sortingTable = entitysettings.Origin or entitylib.character.HumanoidRootPart.Position, {}
			local partName = entitysettings.Part
			for _, entity in entitylib.List do
				if not entitysettings.Players and entity.Player then continue end
				if not entitysettings.NPCs and entity.NPC then continue end
				if not entity.Targetable then continue end
				local mag = (entity[partName].Position - localPosition).Magnitude
				if mag > entitysettings.Range then continue end
				if entitylib.isVulnerable(entity, entitysettings.AttackCheck) then
					table.insert(sortingTable, {
						Entity = entity,
						Magnitude = entity.Target and -1 or mag
					})
				end
			end

			table.sort(sortingTable, entitysettings.Sort or function(a, b)
				return a.Magnitude < b.Magnitude
			end)

			for _, v in sortingTable do
				if entitysettings.Wallcheck then
					local part = v.Entity[partName]
					if entitylib.Wallcheck(localPosition, part.Position, entitysettings.Wallbang, part, v.Entity) then continue end
				end
				table.clear(entitysettings)
				table.clear(sortingTable)
				return v.Entity
			end
			table.clear(sortingTable)
		end
		table.clear(entitysettings)
	end

	entitylib.AllPosition = function(entitysettings)
		local returned = {}
		if entitylib.isAlive then
			local localPosition, sortingTable = entitysettings.Origin or entitylib.character.HumanoidRootPart.Position, {}
			local partName = entitysettings.Part
			for _, entity in entitylib.List do
				if not entitysettings.Players and entity.Player then continue end
				if not entitysettings.NPCs and entity.NPC then continue end
				if not (entity.Targetable or entitysettings.SkipTeam and entitylib.targetCheck(entity, true)) then continue end
				local mag = (entity[partName].Position - localPosition).Magnitude
				if mag > entitysettings.Range then continue end
				if entitylib.isVulnerable(entity, entitysettings.AttackCheck, entitysettings.SkipTeam) then
					table.insert(sortingTable, {
						Entity = entity,
						Magnitude = entity.Target and -1 or mag
					})
				end
			end

			table.sort(sortingTable, entitysettings.Sort or function(a, b)
				return a.Magnitude < b.Magnitude
			end)

			for _, v in sortingTable do
				if entitysettings.Wallcheck then
					local part = v.Entity[partName]
					if entitylib.Wallcheck(localPosition, part.Position, entitysettings.Wallbang, part, v.Entity) then continue end
				end
				table.insert(returned, v.Entity)
				if #returned >= (entitysettings.Limit or math.huge) then break end
			end
			table.clear(sortingTable)
		end
		table.clear(entitysettings)
		return returned
	end

	entitylib.getEntityColor = function(entity)
		if not (entity.Player and vape.Settings.Modules.Options['Use team color'].Enabled) then
			return
		end

		if isFriend(entity.Player, true) then
			return Color3.fromHSV(vape.Categories.Friends.Options['Friends color'].Hue, vape.Categories.Friends.Options['Friends color'].Sat, vape.Categories.Friends.Options['Friends color'].Value)
		end

		local color = tostring(entity.Player.TeamColor) ~= 'White' and entity.Player.TeamColor.Color or nil
		if entity.Player.Team == teams.Inmates and (entity.Character:GetAttribute('Hostile') or entity.Character:GetAttribute('Trespassing')) then
			return Color3.new(color.R, color.G * 0.5, color.B * 0.5)
		end

		return color
	end

	entitylib.Wallcheck = function(origin, position, checkPosition, part, entity)
		local ray = workspace.Raycast(workspace, position, (origin - position), OriginScanner.Ray)
		if ray or workspace.Raycast(workspace, origin, (position - origin), OriginScanner.Ray) then
			return not checkPosition or not OriginScanner:Scan(checkPosition, position, ray and ray.Position + ray.Normal * 0.01 or nil, part, entity)
		end

		return false
	end
end)
entitylib.start()

run(function()
	pl = {
		GunTracers = require(replicatedStorage.SharedModules.GunTracers)
	}

	local gui = lplr.PlayerGui:WaitForChild('Home', 10)
	gui = gui and gui.hud.ActionArea
	if vape.Loaded == nil then
		return
	end

	local function getShootFunction()
		for _, connection in getconnections(gui.InputBegan) do
			if connection.Function then
				pl.Shoot = debug.getupvalue(connection.Function, 2)
				pl.Reload = debug.getupvalue(pl.Shoot, 2)
				pl.Bullet = debug.getupvalue(pl.Shoot, 16)
				pl.PlaySound = debug.getupvalue(pl.Reload, 3)
				break
			end
		end

		for _, connection in getconnections(lplr.CharacterAdded) do
			if connection.Function and debug.info(connection.Function, 's'):find('GunController') then
				pl.ShootParams = debug.getupvalue(connection.Function, 2)
				pl.Equip = debug.getupvalue(connection.Function, 3)
				break
			end
		end

		for _, connection in getconnections(lplr:GetAttributeChangedSignal('BackpackEnabled')) do
			pl.SwitchUpdate = debug.getupvalue(debug.getupvalue(connection.Function, 10), 5)
			pl.SwitchTable = debug.getupvalue(debug.getupvalue(connection.Function, 8), 2)
			break
		end
	end

	getShootFunction()
	if not (pl.Bullet and pl.SwitchTable) then
		repeat
			getShootFunction()
			task.wait()
		until pl.Bullet and pl.SwitchTable or vape.Loaded == nil

		if vape.Loaded == nil then
			table.clear(pl)
		end
	end

	local kills = sessioninfo:AddItem('Kills')
	local deaths = sessioninfo:AddItem('Deaths')
	local arrests = sessioninfo:AddItem('Arrests')
	local cheaterkicked = sessioninfo:AddItem('Cheaters Kicked')
	local cheaters = sessioninfo:AddItem('Cheater List', '', function()
		local text = ''
		for _, plr in playersService:GetPlayers() do
			if Cheats.Flagged[plr.UserId] then
				local label = plr.DisplayName ~= plr.Name and plr.DisplayName or plr.Name
				local flag = Cheats.FlaggedInfo[plr.UserId] or 'unknown'
				text = text..'\n'..label..' ('..flag..')'
			end
		end

		return text
	end, false)

	table.insert(whitelist.tagcallback, function(plr, plrtag, rich)
		if plr then
			local entity = entitylib.getEntity(plr)
			if entity then
				if Cheats.Flagged[plr.UserId] then
					table.insert(plrtag, {text = rich and '⚠️' or 'Cheater'})
				end

				if plr.Team == teams.Inmates then
					if entity.Character:GetAttribute('Hostile') then
						table.insert(plrtag, {text = rich and '💢' or 'Hostile'})
					elseif entity.Character:GetAttribute('Trespassing') then
						table.insert(plrtag, {text = rich and '🔗' or 'Trespassing'})
					end
				elseif plr.Team == teams.Guards then
					local count = plr:GetAttribute('InnocentKills') or 0
					if count > 0 then
						table.insert(plrtag, {
							text = tostring(count),
							color = Color3.fromHSV(math.clamp(1 - (count / 2), 0, 1) / 2.5, 0.89, 0.75)
						})
					end
				end
			end
		end
	end)

	task.spawn(function()
		gamepasses = {
			['Riot Police'] = marketplaceService:UserOwnsGamePassAsync(lplr.UserId, 643697197),
			Mafia = marketplaceService:UserOwnsGamePassAsync(lplr.UserId, 1443271),
			Sniper = marketplaceService:UserOwnsGamePassAsync(lplr.UserId, 699360089)
		}
	end)

	OriginScanner:UpdateIgnore()
	for _, event in {'EntityAdded', 'LocalAdded'} do
		vape:Clean(entitylib.Events[event]:Connect(function()
			OriginScanner:UpdateIgnore()
		end))
	end

	vape:Clean(replicatedStorage.Killfeed.ChildAdded:Connect(function(obj)
		local names = {}

		-- killer
		local start = obj.Name:find('@')
		local endchar = obj.Name:find(')')
		table.insert(names, obj.Name:sub(start + 1, endchar - 1))

		-- victim
		start = obj.Name:find('killed ') + 7
		endchar = obj.Name:find(' ', start)
		table.insert(names, obj.Name:sub(start, endchar - 1))

		vapeEvents.PlayerKill:Fire(unpack(names))
		if names[1] == lplr.Name then
			kills:Increment()
		elseif names[2] == lplr.Name then
			deaths:Increment()
		end
	end))

	vape:Clean(vapeEvents.Arrested.Event:Connect(function()
		arrests:Increment()
	end))

	vape:Clean(replicatedStorage.Remotes.MessageReceived.OnClientEvent:Connect(function(msg)
		if msg:find('kicked') then
			cheaterkicked:Increment()

			task.defer(function()
				vapeEvents.CheaterKicked:Fire(msg:sub(1, msg:find(' ')))
			end)
		end
	end))

	vape:Clean(entitylib.Events.EntityUpdated:Connect(function(entity)
		if entity.Player and entity.Player.Team == teams.Inmates then
			vape.Categories.Friends.ColorUpdate:Fire()
		end
	end))

	vape:Clean(runService.RenderStepped:Connect(function()
		table.clear(OriginScanner.Cache)
	end))

	vape:Clean(function()
		table.clear(pl)
	end)
end)

run(function()
	-- https://github.com/J1ck/roblox-spring/blob/main/src/roblox-spring.luau
	Spring.__index = Spring

	function Spring.new(Properties)
		local TypeRefined = Properties or {}

		local self = setmetatable({
			Target = Vector3.new(),
			Position = Vector3.new(),
			Velocity = Vector3.new(),

			Mass = TypeRefined.Mass or 5,
			Force = TypeRefined.Force or 50,
			Damping	= TypeRefined.Damping or 4,
			Speed = TypeRefined.Speed or 4,
		}, Spring)

		return self
	end

	function Spring:Update(DeltaTime)
		local IterationsThisFrame = DeltaTime / ((1 / 60) / 8)
		local ScaledDeltaTime = DeltaTime * self.Speed / IterationsThisFrame

		for i = 1, math.round(IterationsThisFrame) do
			local IterationForce = self.Target - self.Position
			local Acceleration = (IterationForce * self.Force) / self.Mass

			Acceleration -= self.Velocity * self.Damping

			self.Velocity += Acceleration * ScaledDeltaTime
			self.Position += self.Velocity * ScaledDeltaTime
		end

		return self.Position
	end
end)

run(function()
	local oldtracer, oldtracertaser, oldtracersniper

	local function Hook(...)
		if debug.info(3, 's') ~= 'ReplicatedStorage.Scripts.Replication.ClientReplicator' then
			for _, v in TracerHook.Hooks do
				if v[2](...) then return end
			end
		end

		return oldtracer(...)
	end

	local function HookTaser(...)
		if debug.info(3, 's') ~= 'ReplicatedStorage.Scripts.Replication.ClientReplicator' then
			for _, v in TracerHook.Hooks do
				if v[2](...) then return end
			end
		end

		return oldtracertaser(...)
	end

	local function HookSniper(...)
		if debug.info(3, 's') ~= 'ReplicatedStorage.Scripts.Replication.ClientReplicator' then
			for _, v in TracerHook.Hooks do
				if v[2](...) then return end
			end
		end

		return oldtracersniper(...)
	end

	function TracerHook:Add(key, val, priority)
		table.insert(self.Hooks, {key, val, priority or 0})
		table.sort(self.Hooks, function(a, b)
			return a[3] < b[3]
		end)

		if not oldtracer then
			oldtracer = hookfunction(pl.GunTracers.createBullet, function(...)
				return Hook(...)
			end)

			oldtracertaser = hookfunction(pl.GunTracers.createTaser, function(...)
				return HookTaser(...)
			end)

			oldtracersniper = hookfunction(pl.GunTracers.createSniper, function(...)
				return HookSniper(...)
			end)
		end
	end

	function TracerHook:Remove(key)
		for i, v in self.Hooks do
			if v[1] == key then
				table.remove(self.Hooks, i)
				break
			end
		end

		if oldtracer and not next(self.Hooks) then
			if restorefunction then
				restorefunction(pl.GunTracers.createBullet)
				restorefunction(pl.GunTracers.createTaser)
				restorefunction(pl.GunTracers.createSniper)
			else
				hookfunction(pl.GunTracers.createBullet, oldtracer)
				hookfunction(pl.GunTracers.createTaser, oldtracertaser)
				hookfunction(pl.GunTracers.createSniper, oldtracersniper)
			end

			oldtracer = nil
			oldtracertaser = nil
			oldtracersniper = nil
		end
	end
end)

for _, v in {'Reach', 'Jesus', 'MurderMystery'} do
	vape:Remove(v)
end

run(function()
	local SilentAim
	local Target
	local Mode
	local Range
	local HitChance
	local HeadshotChance
	local AutoFire = {Enabled = false}
	local AutoFireRate
	local AutoFireTaser
	local AutoFireSwitch
	local Wallbang
	local CircleColor
	local CircleTransparency
	local CircleFilled
	local CircleObject
	local rand = Random.new()
	local old
	local hooked

	local function getMousePosition()
		if inputService.TouchEnabled then
			return gameCamera.ViewportSize / 2
		end

		return inputService.GetMouseLocation(inputService)
	end

	local backpack
	-- cached, both scanners below can run every AutoFire tick
	local function getBackpack()
		if not backpack or backpack.Parent ~= lplr then
			backpack = lplr:FindFirstChildWhichIsA('Backpack')
		end

		return backpack
	end

	-- 0 while the tool is reloading or carries no range attribute
	local function getToolRange(tool)
		if (tool:GetAttribute('Local_ReloadSession') or 0) > 0 then
			return 0
		end

		return tool:GetAttribute('Range') or 0
	end

	local function getShootTool(range)
		local tool = lplr.Character and lplr.Character:FindFirstChildWhichIsA('Tool')
		if tool and tool:GetAttribute('FireRate') and (not tool:GetAttribute('Local_IsShooting')) and (tool:GetAttribute('Local_CurrentAmmo') or 1) > 0 and getToolRange(tool) > range then
			return tool
		end

		local container = getBackpack()
		if container then
			for _, tool in container:GetChildren() do
				if tool:IsA('Tool') and tool:GetAttribute('FireRate') and (not tool:GetAttribute('Local_IsShooting')) and tool.Name ~= 'Taser' and getToolRange(tool) > range then
					return tool
				end
			end
		end
	end

	local function getMaxRange()
		local mag = 0
		local tool = lplr.Character and lplr.Character:FindFirstChildWhichIsA('Tool')
		if tool then
			mag = getToolRange(tool)
		end

		local container = getBackpack()
		if container then
			for _, tool in container:GetChildren() do
				if tool:IsA('Tool') and tool.Name ~= 'Taser' then
					local dist = getToolRange(tool)
					if dist > mag then
						mag = dist
					end
				end
			end
		end

		return mag
	end

	local entityMode
	local entityFunc
	-- caches the lookup so the 'Entity'..Mode.Value concat isnt rebuilt per shot
	local function getEntity(settings)
		if entityMode ~= Mode.Value then
			entityMode = Mode.Value
			entityFunc = entitylib['Entity'..entityMode]
		end

		return entityFunc(settings)
	end

	local function getTarget(origin, limit, attackcheck)
		if rand.NextNumber(rand, 0, 100) > (AutoFire.Enabled and 100 or HitChance.Value) then
			return
		end

		local targetPart = (rand.NextNumber(rand, 0, 100) < (AutoFire.Enabled and 100 or HeadshotChance.Value)) and 'Head' or 'RootPart'
		local entity = getEntity({
			Range = Mode.Value == 'Position' and math.min(Range.Value, limit) or Range.Value,
			RangePosition = limit,
			AttackCheck = attackcheck,
			Wallcheck = Target.Walls.Enabled and true or nil,
			Wallbang = Wallbang.Enabled and entitylib.character.RootPart.Position or nil,
			Part = targetPart,
			Origin = origin,
			Players = Target.Players.Enabled,
			NPCs = Target.NPCs.Enabled
		})

		if entity then
			targetinfo.Targets[entity] = tick() + 1
		end

		return entity, entity and entity[targetPart]
	end

	local function Hook(origin, direction, ...)
		local gundata = debug.getupvalue(oldshoot or pl.Shoot, 10)
		local entity, targetPart = getTarget(origin, gundata and gundata.Range or 1000, not gundata or gundata.Behavior ~= 'Taser')

		if not entity then
			return old(origin, direction, ...)
		end

		local aimPosition = targetPart.Position
		aimTimer = os.clock() + 0.3
		aimVec = aimPosition

		if Wallbang.Enabled then
			local ray
			if not OriginScanner.Cache[targetPart] then
				ray = workspace:Raycast(aimPosition, (origin - aimPosition), OriginScanner.Ray)
			end

			if OriginScanner.Cache[targetPart] or ray or workspace:Raycast(origin, (aimPosition - origin), OriginScanner.Ray) then
				local newOrigin, hit = OriginScanner:Scan(
					entitylib.character.RootPart.Position,
					aimPosition,
					ray and ray.Position + ray.Normal * 0.01 or nil,
					targetPart,
					entity
				)

				if newOrigin then
					for index, value in debug.getstack(3) do
						if value == origin then
							debug.setstack(3, index, newOrigin)
						end
					end

					origin = newOrigin
					if hit then
						return targetPart, hit
					end
				end
			end
		end

		return old(origin, aimPosition, ...)
	end

	SilentAim = vape.Categories.Combat:CreateModule({
		Name = 'SilentAim',
		Function = function(callback)
			if CircleObject then
				CircleObject.Visible = callback and Mode.Value == 'Mouse'
			end

			if callback then
				hooked = pl.Bullet
				old = hookfunction(hooked, function(...)
					return Hook(...)
				end)

				local fireDelay = os.clock()
				repeat
					if CircleObject and CircleObject.Visible then
						CircleObject.Position = getMousePosition()
					end

					if AutoFire.Enabled and entitylib.isAlive and fireDelay < os.clock() then
						fireDelay = os.clock() + (1 / AutoFireRate.Value)

						local tool = lplr.Character:FindFirstChildWhichIsA('Tool')
						local gundata = debug.getupvalue(oldshoot or pl.Shoot, 10)
						if tool and gundata then
							local limit = AutoFireSwitch.Enabled and getMaxRange() or gundata.Range or 1000
							local taser = gundata.Behavior == 'Taser'
							local headPosition = entitylib.character.Head.Position
							local entity = getEntity({
								Range = Mode.Value == 'Position' and math.min(Range.Value, limit) or Range.Value,
								RangePosition = limit,
								AttackCheck = not taser,
								Wallcheck = Target.Walls.Enabled and true or nil,
								Wallbang = Wallbang.Enabled and entitylib.character.RootPart.Position or nil,
								Part = 'Head',
								Origin = headPosition,
								Players = Target.Players.Enabled
							})

							if entity and entitylib.character.Humanoid.Health > 0 then
								local ammo = (tool:GetAttribute('Local_CurrentAmmo') or 0)
								local canFire = not tool:GetAttribute('Local_IsShooting') and ammo > 0
								if AutoFireSwitch.Enabled then
									local ideal = getShootTool((entity.Head.Position - headPosition).Magnitude)
									if ideal and tool ~= ideal then
										entitylib.character.Humanoid:EquipTool(ideal)
										canFire = false
									end
								end

								if canFire and not ((taser or AutoFireTaser.Enabled) and (entity.Character:GetAttribute('Tased') or entity.Character:GetAttribute('Arrested'))) then
									fireDelay = os.clock() + (AutoFireSwitch.Enabled and 0.05 or ammo > 1 and gundata.FireRate or 1 / AutoFireRate.Value)
									local obj = {UserInputState = Enum.UserInputState.Begin, UserInputType = Enum.UserInputType.MouseButton1, Position = Vector3.zero}
									task.spawn(pl.Shoot, obj)
									obj.UserInputState = Enum.UserInputState.End
								end
							end
						end
					end

					task.wait()
				until not SilentAim.Enabled
			else
				if old and hooked then
					-- pl gets cleared on uninject before this thread runs, so the function
					-- has to be restored through the reference captured while hooking
					if restorefunction then
						restorefunction(hooked)
					else
						hookfunction(hooked, old)
					end

					old, hooked = nil, nil
				end
			end
		end,
		ExtraText = function()
			return 'PrisonLife'
		end,
		Tooltip = 'Silently adjusts your aim towards the enemy'
	})
	Target = SilentAim:CreateTargets({
		Players = true,
		Walls = true
	})
	Mode = SilentAim:CreateDropdown({
		Name = 'Mode',
		List = {'Mouse', 'Position'},
		Function = function(val)
			if CircleObject then
				CircleObject.Visible = SilentAim.Enabled and val == 'Mouse'
			end
		end,
		Tooltip = 'Mouse - Checks for entities near the mouses position\nPosition - Checks for entities near the local character'
	})
	Range = SilentAim:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 1500,
		Default = 150,
		Function = function(val)
			if CircleObject then
				CircleObject.Radius = val
			end
		end,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	HitChance = SilentAim:CreateSlider({
		Name = 'Hit Chance',
		Min = 0,
		Max = 100,
		Default = 85,
		Suffix = '%'
	})
	HeadshotChance = SilentAim:CreateSlider({
		Name = 'Headshot Chance',
		Min = 0,
		Max = 100,
		Default = 65,
		Suffix = '%'
	})
	AutoFire = SilentAim:CreateToggle({
		Name = 'AutoFire',
		Function = function(callback)
			AutoFireRate.Object.Visible = callback
			AutoFireTaser.Object.Visible = callback
			AutoFireSwitch.Object.Visible = callback
		end,
		Tooltip = 'Automatically fires guns when the specified target conditions are met.'
	})
	AutoFireRate = SilentAim:CreateSlider({
		Name = 'Update rate',
		Min = 1,
		Max = 120,
		Default = 60,
		Visible = false,
		Darker = true,
		Suffix = 'hz'
	})
	AutoFireTaser = SilentAim:CreateToggle({
		Name = 'Ignore Tased',
		Visible = false,
		Darker = true
	})
	AutoFireSwitch = SilentAim:CreateToggle({
		Name = 'Auto Switch',
		Visible = false,
		Darker = true,
		Tooltip = 'Spam switch guns while shooting to get fast damage, only good with multiple tools.'
	})
	Wallbang = SilentAim:CreateToggle({
		Name = 'Wallbang',
		Tooltip = 'Allow you to shoot people through walls when specific conditions are met.\n(If the entity has a valid hitbox position exposed or if the shoot position can be moved past walls (eg hugging walls))'
	})
	SilentAim:CreateToggle({
		Name = 'Range Circle',
		Function = function(callback)
			if callback then
				CircleObject = Drawing.new('Circle')
				CircleObject.Filled = CircleFilled.Enabled
				CircleObject.Color = Color3.fromHSV(CircleColor.Hue, CircleColor.Sat, CircleColor.Value)
				CircleObject.Position = vape.gui.AbsoluteSize / 2
				CircleObject.Radius = Range.Value
				CircleObject.NumSides = 100
				CircleObject.Transparency = 1 - CircleTransparency.Value
				CircleObject.Visible = SilentAim.Enabled and Mode.Value == 'Mouse'
			else
				pcall(function()
					CircleObject.Visible = false
					CircleObject:Remove()
				end)
			end
			CircleColor.Object.Visible = callback
			CircleTransparency.Object.Visible = callback
			CircleFilled.Object.Visible = callback
		end
	})
	CircleColor = SilentAim:CreateColorSlider({
		Name = 'Circle Color',
		Function = function(hue, sat, val)
			if CircleObject then
				CircleObject.Color = Color3.fromHSV(hue, sat, val)
			end
		end,
		Darker = true,
		Visible = false
	})
	CircleTransparency = SilentAim:CreateSlider({
		Name = 'Transparency',
		Min = 0,
		Max = 1,
		Decimal = 10,
		Default = 0.5,
		Function = function(val)
			if CircleObject then
				CircleObject.Transparency = 1 - val
			end
		end,
		Darker = true,
		Visible = false
	})
	CircleFilled = SilentAim:CreateToggle({
		Name = 'Circle Filled',
		Function = function(callback)
			if CircleObject then
				CircleObject.Filled = callback
			end
		end,
		Darker = true,
		Visible = false
	})
end)

run(function()
	local TriggerBot
	local Targets
	local rayParams = RaycastParams.new()
	rayParams.CollisionGroup = 'ClientBullet'
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	
	local function getTriggerBotTarget()
		rayParams.FilterDescendantsInstances = VehicleWallbang.Enabled and {lplr.Character, workspace.CarContainer} or {lplr.Character}
	
		if entitylib.isAlive then
			local tool = debug.getupvalue(oldshoot or pl.Shoot, 1)
			local data = debug.getupvalue(oldshoot or pl.Shoot, 10)
	
			if tool and data and data.Range then
				local posX, posY
				if inputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
					posX = gameCamera.ViewportSize.X / 2
					posY = gameCamera.ViewportSize.Y / 2
				else
					local location = inputService:GetMouseLocation()
					posX = location.X
					posY = location.Y
				end
	
				local rayPos = gameCamera:ViewportPointToRay(posX, posY)
				local ray = workspace:Raycast(rayPos.Origin, rayPos.Direction * 1500, rayParams)
				if not ray then return end
	
				local vEntity
				for _, entity in entitylib.List do
					if entity.Targetable and entity.Character and (Targets.Players.Enabled and entity.Player or Targets.NPCs.Enabled and entity.NPC) and ray.Instance:IsDescendantOf(entity.Character) and entitylib.isVulnerable(entity, true) then
						vEntity = entity
						break
					end
				end
	
				if vEntity then
					local origin = entitylib.character.Head.Position
					local hitCheck = workspace:Raycast(origin, (ray.Position - origin), rayParams)
	
					if hitCheck and hitCheck.Instance:IsDescendantOf(vEntity.Character) and (ray.Position - origin).Magnitude <= data.Range then
						return vEntity
					end
				end
			end
		end
	end
	
	TriggerBot = vape.Categories.Combat:CreateModule({
		Name = 'TriggerBot',
		Function = function(callback)
			if callback then
				repeat
					if getTriggerBotTarget() then
						local obj = {UserInputState = Enum.UserInputState.Begin, UserInputType = Enum.UserInputType.MouseButton1, Position = Vector3.zero}
						task.spawn(pl.Shoot, obj)
						obj.UserInputState = Enum.UserInputState.End
					end
	
					task.wait()
				until not TriggerBot.Enabled
			end
		end,
		Tooltip = 'Shoots people that enter your crosshair'
	})
	Targets = TriggerBot:CreateTargets({
		Players = true,
		NPCs = true
	})
end)

run(function()
	local AntiInvisible
	local threads = {}
	local allowedAnims = {
		-- default roblox animations
		['http://www.roblox.com/asset/?id=125750702'] = true,
		['http://www.roblox.com/asset/?id=128777973'] = true,
		['http://www.roblox.com/asset/?id=128853357'] = true,
		['http://www.roblox.com/asset/?id=129423030'] = true,
		['http://www.roblox.com/asset/?id=129423131'] = true,
		['http://www.roblox.com/asset/?id=129967390'] = true,
		['http://www.roblox.com/asset/?id=129967478'] = true,
		['http://www.roblox.com/asset/?id=178130996'] = true,
		['http://www.roblox.com/asset/?id=180426354'] = true,
		['http://www.roblox.com/asset/?id=180435571'] = true,
		['http://www.roblox.com/asset/?id=180435792'] = true,
		['http://www.roblox.com/asset/?id=180436148'] = true,
		['http://www.roblox.com/asset/?id=180436334'] = true,
		['http://www.roblox.com/asset/?id=182393478'] = true,
		['http://www.roblox.com/asset/?id=182435998'] = true,
		['http://www.roblox.com/asset/?id=182436842'] = true,
		['http://www.roblox.com/asset/?id=182436935'] = true,
		['http://www.roblox.com/asset/?id=182491037'] = true,
		['http://www.roblox.com/asset/?id=182491065'] = true,
		['http://www.roblox.com/asset/?id=182491248'] = true,
		['http://www.roblox.com/asset/?id=182491277'] = true,
		['http://www.roblox.com/asset/?id=182491368'] = true,
		['http://www.roblox.com/asset/?id=182491423'] = true,
		-- game animations
		['rbxassetid://279227693'] = true,
		['rbxassetid://279229192'] = true,
		['rbxassetid://287112271'] = true,
		['rbxassetid://388723916'] = true,
		['rbxassetid://388726667'] = true,
		['rbxassetid://389472570'] = true,
		['rbxassetid://405194080'] = true,
		['rbxassetid://405212265'] = true,
		['rbxassetid://481088553'] = true,
		['rbxassetid://481089053'] = true,
		['rbxassetid://484200742'] = true,
		['rbxassetid://484926359'] = true,
		['rbxassetid://83690472549256'] = true,
		['rbxassetid://107176344504758'] = true,
		['rbxassetid://111090572475133'] = true,
		['rbxassetid://113267949064300'] = true,
		['rbxassetid://131326339350805'] = true
	}
	
	local function AnimationAdded(anim, plr)
		if not allowedAnims[anim.Animation.AnimationId] and plr then
			if threads[anim] then
				task.cancel(threads[anim])
			end
	
			Cheats:Flag(plr, 'invalid animation', 1)
			threads[anim] = task.spawn(function()
				repeat
					anim:AdjustWeight(0, 0)
					task.wait()
				until not (anim.IsPlaying and AntiInvisible.Enabled)
	
				threads[anim] = nil
			end)
		end
	end
	
	local function EntityAdded(ent)
		local animator = ent.Humanoid:WaitForChild('Animator', 5)
	
		if animator and AntiInvisible.Enabled then
			AntiInvisible:Clean(animator.AnimationPlayed:Connect(function(anim)
				AnimationAdded(anim, ent.Player)
			end))
	
			for _, anim in animator:GetPlayingAnimationTracks() do
				task.spawn(AnimationAdded, anim, ent.Player)
			end
		end
	end
	
	for _, v in replicatedStorage:QueryDescendants('Animation') do
		allowedAnims[v.AnimationId] = true
	end
	
	AntiInvisible = vape.Categories.Blatant:CreateModule({
		Name = 'AntiInvisible',
		Function = function(callback)
			if callback then
				AntiInvisible:Clean(entitylib.Events.EntityAdded:Connect(EntityAdded))
				for _, v in entitylib.List do
					task.spawn(EntityAdded, v)
				end
			else
				for _, v in threads do
					task.cancel(v)
				end
				table.clear(threads)
			end
		end,
		Tooltip = 'Prevent people from using animations outside of the game\'s scope'
	})
end)

run(function()
	local AntiKillPlane
	
	AntiKillPlane = vape.Categories.Blatant:CreateModule({
		Name = 'AntiKillPlane',
		Function = function(callback)
			if callback then
				AntiKillPlane:Clean(runService.Heartbeat:Connect(function()
					if entitylib.isAlive then
						local root = entitylib.character.RootPart
						local diff = math.clamp(root.Position.Y, -10, 179.99) - root.Position.Y
	
						if math.abs(diff) > 0 then
							root.CFrame += Vector3.new(0, diff, 0)
							root.AssemblyLinearVelocity *= Vector3.new(1, 0, 1)
						end
					end
				end))
			end
		end,
		Tooltip = 'Prevents you from touching the kill plane'
	})
end)

run(function()
	local AntiRiotShield
	
	AntiRiotShield = vape.Categories.Blatant:CreateModule({
		Name = 'AntiRiotShield',
		Function = function(callback)
			if callback then
				repeat
					for _, entity in entitylib.List do
						local shield = entity.Character:FindFirstChild('RiotShieldPart')
						if shield then
							shield.CanQuery = false
						end
					end
	
					task.wait(0.05)
				until not AntiRiotShield.Enabled
			else
				for _, entity in entitylib.List do
					local shield = entity.Character:FindFirstChild('RiotShieldPart')
					if shield then
						shield.CanQuery = true
					end
				end
			end
		end,
		Tooltip = 'Allow you to shoot through riot shields.'
	})
end)

run(function()
	local AntiTaze
	local old, connection
	
	local function EntityAdded(ent)
		connection = getconnections(replicatedStorage.GunRemotes.PlayerTased.OnClientEvent)[1]
		if not (connection and connection.Function) then
			repeat
				connection = getconnections(replicatedStorage.GunRemotes.PlayerTased.OnClientEvent)[1]
				task.wait()
			until connection and connection.Function or not AntiTaze.Enabled
		end
	
		if connection and AntiTaze.Enabled then
			old = hookfunction(connection.Function, function()
				local char = lplr.Character
				lplr:SetAttribute('BackpackEnabled', false)
				if entitylib.isAlive then
					entitylib.character.Humanoid:UnequipTools()
				end
	
				task.wait(3.5)
				if lplr.Character == char then
					lplr:SetAttribute('BackpackEnabled', true)
				end
			end)
		end
	end
	
	AntiTaze = vape.Categories.Blatant:CreateModule({
		Name = 'AntiTaze',
		Function = function(callback)
			if callback then
				AntiTaze:Clean(entitylib.Events.LocalAdded:Connect(EntityAdded))
				if entitylib.isAlive then
					task.spawn(EntityAdded, entitylib.character)
				end
			else
				if old and connection.Function then
					hookfunction(connection.Function, old)
					old = nil
				end
			end
		end,
		Tooltip = 'Prevent you from getting tazed'
	})
end)

run(function()
	local AutoArrest
	local Range
	local HandCheck
	local CooldownBar
	local toggles = {}
	local cdholder, cdframe, cdlabel
	local arrestCooldown = 0
	
	AutoArrest = vape.Categories.Blatant:CreateModule({
		Name = 'AutoArrest',
		Function = function(callback)
			if callback then
				repeat
					local clock = os.clock()
					local check = arrestCooldown < clock
					if HandCheck.Enabled then
						local tool = entitylib.isAlive and lplr.Character:FindFirstChildWhichIsA('Tool')
						check = check and tool and tool.Name == 'Handcuffs'
					end
	
					if check then
						local entities = entitylib.AllPosition({
							Range = Range.Value,
							Players = true,
							Part = 'RootPart',
							TargetCheck = true
						})
	
						for _, ent in entities do
							if not ent.Character:GetAttribute('Arrested') then
								local toggle = ent.Player.Team and toggles[ent.Player.Team.Name]
								if toggle and not toggle.Enabled then
									continue
								end
	
								if ent.Player.Team == teams.Inmates and ent.Character:GetAttribute('Hostile') and not ent.Character:GetAttribute('Tased') then
									continue
								end
	
								if replicatedStorage.Remotes.ArrestPlayer:InvokeServer(ent.Player, 1) then
									arrestCooldown = os.clock() + 7
									vapeEvents.Arrested:Fire()
									notif('AutoArrest', 'Arrested '..(ent.Player.Name), 7)
								end
	
								break
							end
						end
					end
	
					if cdholder then
						cdholder.Visible = arrestCooldown > clock
	
						if cdholder.Visible then
							local diff = arrestCooldown - clock
							cdframe.Size = UDim2.new(math.clamp(diff / 7, 0, 1), -2, 1, -2)
							cdlabel.Text = (math.round(diff * 10) / 10)..'s'
						end
					end
	
					task.wait(0.05)
				until not AutoArrest.Enabled
			else
				if cdholder then
					cdholder.Visible = false
				end
			end
		end,
		Tooltip = 'Automatically uses handcuffs on nearby entities'
	})
	Range = AutoArrest:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 8,
		Default = 8,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	HandCheck = AutoArrest:CreateToggle({
		Name = 'Hand Check',
		Tooltip = 'Only arrest if you have handcuffs equipped.'
	})
	CooldownBar = AutoArrest:CreateToggle({
		Name = 'Cooldown Bar',
		Function = function(callback)
			if callback then
				cdholder = Instance.new('Frame')
				cdholder.Visible = false
				cdholder.BorderSizePixel = 0
				cdholder.BackgroundTransparency = 0.7
				cdholder.AnchorPoint = Vector2.new(0.5, 0)
				cdholder.BackgroundColor3 = Color3.new(1, 1, 1)
				cdholder.Size = UDim2.new(0.1, 0, 0, 5)
				cdholder.Position = UDim2.fromScale(0.5, 0.55)
				cdholder.Parent = vape.gui
				cdframe = Instance.new('Frame')
				cdframe.BorderSizePixel = 0
				cdframe.BackgroundTransparency = 0.3
				cdframe.BackgroundColor3 = Color3.new(1, 1, 1)
				cdframe.Size = UDim2.new(1, -2, 1, -2)
				cdframe.Position = UDim2.fromOffset(1, 1)
				cdframe.Parent = cdholder
				cdlabel = Instance.new('TextLabel')
				cdlabel.Size = UDim2.new(1, 0, 0, 14)
				cdlabel.Position = UDim2.fromOffset(0, 10)
				cdlabel.BackgroundTransparency = 1
				cdlabel.TextColor3 = Color3.new(1, 1, 1)
				cdlabel.TextScaled = true
				cdlabel.TextStrokeTransparency = 0
				cdlabel.Font = Enum.Font.Arial
				cdlabel.Parent = cdholder
			else
				if cdholder then
					cdholder:Destroy()
					cdholder = nil
				end
			end
		end,
		Tooltip = 'Show the cooldown for arresting'
	})
	
	for _, v in {'Inmates', 'Criminals'} do
		toggles[v] = AutoArrest:CreateToggle({
			Name = 'Arrest '..v,
			Default = true
		})
	end
end)

run(function()
	local AutoReset
	
	AutoReset = vape.Categories.Blatant:CreateModule({
		Name = 'AutoReset',
		Function = function(callback)
			if callback then
				AutoReset:Clean(lplr:GetPropertyChangedSignal('Team'):Connect(function()
					if lplr.Team == teams.Criminals and entitylib.isAlive then
						entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Dead)
					end
				end))
			end
		end,
		Tooltip = 'Automatically reset after becoming a criminal.'
	})
end)

run(function()
	local AutoTaze
	local Range
	local VelocityCheck
	local cooldown = 0
	
	AutoTaze = vape.Categories.Blatant:CreateModule({
		Name = 'AutoTaze',
		Function = function(callback)
			if callback then
				repeat
					local backpack = lplr:FindFirstChildWhichIsA('Backpack')
					local taser = backpack and backpack:FindFirstChild('Taser')
	
					if taser and (taser:GetAttribute('CurrentAmmo') or 1) > 0 and cooldown < os.clock() and (arrestCooldown - os.clock()) < 3 then
						if not VelocityCheck.Enabled or entitylib.isAlive and entitylib.character.RootPart.AssemblyLinearVelocity.Magnitude < 40 then
							local entities = entitylib.AllPosition({
								Range = Range.Value,
								AttackCheck = false,
								Wallcheck = true,
								Part = 'Head',
								Origin = entitylib.isAlive and entitylib.character.Head.Position or Vector3.zero,
								Players = true
							})
	
							for _, entity in entities do
								if not (entity.Character:GetAttribute('Tased') or entity.Character:GetAttribute('Arrested')) then
									cooldown = os.clock() + 2
									entitylib.character.Humanoid:EquipTool(taser)
									break
								end
							end
						end
					end
	
					task.wait(0.05)
				until not AutoTaze.Enabled
			end
		end,
		Tooltip = 'Automatically taze people around you. (only works with SilentAim AutoFire with Position Mode enabled)'
	})
	Range = AutoTaze:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 52,
		Default = 52,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	VelocityCheck = AutoTaze:CreateToggle({
		Name = 'Velocity Check',
		Default = true
	})
end)

run(function()
	local FastChange
	local ChooseTeam
	
	local function openTeamMenu()
		local home = lplr.PlayerGui:FindFirstChild('Home', true)
		local switch = home and home.hud.Topbar.MenuFrame.SwitchTeams
		if switch then
			firesignal(switch.MouseButton1Click)
		end
	end
	
	local function switchTeam(name)
		local teamGui = lplr.PlayerGui:FindFirstChild('TeamsFrame', true)
		if not teamGui then return false end
		for _, holder in teamGui:GetChildren() do
			if holder.Name == name and holder.Button.AutoButtonColor then
				firesignal(holder.Button.MouseButton1Click)
				return true
			end
		end
		return false
	end
	
	FastChange = vape.Categories.Blatant:CreateModule({
		Name = 'FastChange',
		Function = function(callback)
			if not callback then return end
	
			local picked
			if lplr.Team == teams.Neutral then
				picked = switchTeam(ChooseTeam.Value)
			else
				openTeamMenu()
				task.wait(0.8)
				picked = switchTeam(ChooseTeam.Value)
			end
	
			if not picked then
				notif('FastChange', 'Could not switch to '..ChooseTeam.Value..'.', 2, 'warning')
			end
	
			FastChange:Toggle()
		end,
		Tooltip = 'Fast team switch via the team menu'
	})
	
	ChooseTeam = FastChange:CreateDropdown({
		Name = 'Team',
		List = {'Guards', 'Inmates'}
	})
	
end)

run(function()
	local FenceGodmode
	
	FenceGodmode = vape.Categories.Blatant:CreateModule({
		Name = 'FenceGodmode',
		Function = function(callback)
			for _, fence in workspace.Prison_Fences:QueryDescendants('BasePart:has(> TouchTransmitter)') do
				fence.CanTouch = not callback
			end
		end,
		Tooltip = 'Ignore damage from standing ontop of fences.'
	})
end)

run(function()
	local GunModifications
	local Spread
	local FireRate
	local Automatic
	local olddata, old = {}
	local oldhook
	
	local function Modify()
		local data = debug.getupvalue(oldshoot or pl.Shoot, 10)
		if data and GunModifications.Enabled then
			if old ~= data then
				olddata = table.clone(data)
				old = data
			end
	
			data.SpreadRadius = Spread.Enabled and 0 or olddata.SpreadRadius
			data.FireRate = (olddata.FireRate or 0) * (FireRate.Value / 100)
			data.AutoFire = Automatic.Enabled or olddata.AutoFire
		end
	end
	
	
	GunModifications = vape.Categories.Blatant:CreateModule({
		Name = 'GunModifications',
		Function = function(callback)
			if callback then
				oldequip = hookfunction(pl.Equip, function(...)
					local res = table.pack(oldequip(...))
					Modify()
					return unpack(res, 1, res.n)
				end)
	
				Modify()
			else
				if oldequip then
					if restorefunction then
						restorefunction(pl.Equip)
					else
						oldequip = nil
					end
				end
	
				if old then
					for i, v in olddata do
						old[i] = v
					end
					table.clear(olddata)
					old = nil
				end
			end
		end,
		Tooltip = 'Apply various modifications to enhance any firearm'
	})
	FireRate = GunModifications:CreateSlider({
		Name = 'FireRate Multiplier',
		Min = 1,
		Max = 100,
		Default = 100,
		Suffix = '%',
		Function = Modify
	})
	Spread = GunModifications:CreateToggle({
		Name = 'No Spread',
		Function = Modify
	})
	Automatic = GunModifications:CreateToggle({
		Name = 'Full Automatic',
		Function = Modify
	})
end)

run(function()
	local Killaura
	local Targets
	local AttackRange
	local AngleSlider
	local Max
	local Mouse
	local BoxSwingColor
	local BoxAttackColor
	local ParticleTexture
	local ParticleColor1
	local ParticleColor2
	local ParticleSize
	local Face
	local Overlay = OverlapParams.new()
	Overlay.FilterType = Enum.RaycastFilterType.Include
	local Particles, Boxes, AttackDelay = {}, {}, tick()
	
	local function getAttackData()
		if Mouse.Enabled then
			if not inputService:IsMouseButtonPressed(0) then return false end
		end
	
		return true
	end
	
	Killaura = vape.Categories.Blatant:CreateModule({
		Name = 'Killaura',
		Function = function(callback)
			if callback then
				repeat
					local canAttack = getAttackData()
					local attacked = {}
	
					if canAttack then
						local entities = entitylib.AllPosition({
							Range = AttackRange.Value,
							Wallcheck = Targets.Walls.Enabled or nil,
							Part = 'RootPart',
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Limit = Max.Value,
							AttackCheck = true,
							SkipTeam = true
						})
	
						if #entities > 0 then
							local selfpos = entitylib.character.RootPart.Position
							local localfacing = entitylib.character.RootPart.CFrame.LookVector * flatMask
							local maxAngle = math.rad(AngleSlider.Value) / 2
	
							for _, entity in entities do
								local delta = (entity.RootPart.Position - selfpos) * flatMask
								if math.acos(localfacing:Dot(delta.Unit)) > maxAngle then continue end
	
								targetinfo.Targets[entity] = tick() + 1
								table.insert(attacked, {
									Entity = entity,
									Check = BoxAttackColor
								})
	
								replicatedStorage.meleeEvent:FireServer(entity.Player, 1, 1)
							end
						end
					end
	
					for index, box in Boxes do
						box.Adornee = attacked[index] and attacked[index].Entity.RootPart or nil
						if box.Adornee then
							box.Color3 = Color3.fromHSV(attacked[index].Check.Hue, attacked[index].Check.Sat, attacked[index].Check.Value)
							box.Transparency = 1 - attacked[index].Check.Opacity
						end
					end
	
					for index, particle in Particles do
						particle.Position = attacked[index] and attacked[index].Entity.RootPart.Position or Vector3.new(math.huge, math.huge, math.huge)
						particle.Parent = attacked[index] and gameCamera or nil
					end
	
					if Face.Enabled and attacked[1] then
						local vec = attacked[1].Entity.RootPart.Position * flatMask
						entitylib.character.RootPart.CFrame = CFrame.lookAt(entitylib.character.RootPart.Position, Vector3.new(vec.X, entitylib.character.RootPart.Position.Y + 0.01, vec.Z))
					end
	
					task.wait(0.05)
				until not Killaura.Enabled
			else
				for _, box in Boxes do
					box.Adornee = nil
				end
	
				for _, particle in Particles do
					particle.Parent = nil
				end
			end
		end,
		Tooltip = 'Attack players around you\nwithout aiming at them.'
	})
	Targets = Killaura:CreateTargets({
		Players = true
	})
	AttackRange = Killaura:CreateSlider({
		Name = 'Attack range',
		Min = 1,
		Max = 12,
		Default = 12,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	AngleSlider = Killaura:CreateSlider({
		Name = 'Max angle',
		Min = 1,
		Max = 360,
		Default = 360
	})
	Max = Killaura:CreateSlider({
		Name = 'Max targets',
		Min = 1,
		Max = 10,
		Default = 10
	})
	Mouse = Killaura:CreateToggle({Name = 'Require mouse down'})
	Killaura:CreateToggle({
		Name = 'Show target',
		Function = function(callback)
			BoxSwingColor.Object.Visible = callback
			BoxAttackColor.Object.Visible = callback
			if callback then
				for i = 1, 10 do
					local box = Instance.new('BoxHandleAdornment')
					box.Adornee = nil
					box.AlwaysOnTop = true
					box.Size = Vector3.new(3, 5, 3)
					box.CFrame = CFrame.new(0, -0.5, 0)
					box.ZIndex = 0
					box.Parent = vape.holder
					Boxes[i] = box
				end
			else
				for _, box in Boxes do
					box:Destroy()
				end
				table.clear(Boxes)
			end
		end
	})
	BoxSwingColor = Killaura:CreateColorSlider({
		Name = 'Target Color',
		Darker = true,
		DefaultHue = 0.6,
		DefaultOpacity = 0.5,
		Visible = false
	})
	BoxAttackColor = Killaura:CreateColorSlider({
		Name = 'Attack Color',
		Darker = true,
		DefaultOpacity = 0.5,
		Visible = false
	})
	Killaura:CreateToggle({
		Name = 'Target particles',
		Function = function(callback)
			ParticleTexture.Object.Visible = callback
			ParticleColor1.Object.Visible = callback
			ParticleColor2.Object.Visible = callback
			ParticleSize.Object.Visible = callback
	
			if callback then
				for i = 1, 10 do
					local part = Instance.new('Part')
					part.Size = Vector3.new(2, 4, 2)
					part.Anchored = true
					part.CanCollide = false
					part.Transparency = 1
					part.CanQuery = false
					part.Parent = Killaura.Enabled and gameCamera or nil
					local particles = Instance.new('ParticleEmitter')
					particles.Brightness = 1.5
					particles.Size = NumberSequence.new(ParticleSize.Value)
					particles.Shape = Enum.ParticleEmitterShape.Sphere
					particles.Texture = ParticleTexture.Value
					particles.Transparency = NumberSequence.new(0)
					particles.Lifetime = NumberRange.new(0.4)
					particles.Speed = NumberRange.new(16)
					particles.Rate = 128
					particles.Drag = 16
					particles.ShapePartial = 1
					particles.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
						ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
					})
					particles.Parent = part
					Particles[i] = part
				end
			else
				for _, particle in Particles do
					particle:Destroy()
				end
				table.clear(Particles)
			end
		end
	})
	ParticleTexture = Killaura:CreateTextBox({
		Name = 'Texture',
		Default = 'rbxassetid://14736249347',
		Function = function()
			for _, particle in Particles do
				particle.ParticleEmitter.Texture = ParticleTexture.Value
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleColor1 = Killaura:CreateColorSlider({
		Name = 'Color Begin',
		Function = function(hue, sat, val)
			for _, particle in Particles do
				particle.ParticleEmitter.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(hue, sat, val)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
				})
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleColor2 = Killaura:CreateColorSlider({
		Name = 'Color End',
		Function = function(hue, sat, val)
			for _, particle in Particles do
				particle.ParticleEmitter.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(hue, sat, val))
				})
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleSize = Killaura:CreateSlider({
		Name = 'Size',
		Min = 0,
		Max = 1,
		Default = 0.2,
		Decimal = 100,
		Function = function(val)
			for _, particle in Particles do
				particle.ParticleEmitter.Size = NumberSequence.new(val)
			end
		end,
		Darker = true,
		Visible = false
	})
	Face = Killaura:CreateToggle({
		Name = 'Face target'
	})
end)

run(function()
	local NoJumpCooldown
	local old
	
	local function EntityAdded(ent)
		old = getconnections(ent.Humanoid:GetPropertyChangedSignal('Jump'))[1]
		if not old then
			repeat
				old = getconnections(ent.Humanoid:GetPropertyChangedSignal('Jump'))[1]
				task.wait()
			until old or not NoJumpCooldown.Enabled
	
			if not NoJumpCooldown.Enabled then
				return
			end
		end
	
		if old then
			old:Disable()
		end
	end
	
	NoJumpCooldown = vape.Categories.Blatant:CreateModule({
		Name = 'NoJumpCooldown',
		Function = function(callback)
			if callback then
				NoJumpCooldown:Clean(entitylib.Events.LocalAdded:Connect(EntityAdded))
				if entitylib.isAlive then
					task.spawn(EntityAdded, entitylib.character)
				end
			else
				if old then
					old:Enable()
					old = nil
				end
			end
		end,
		Tooltip = 'Remove the stamina cooldown from jumping'
	})
end)

run(function()
	local ToolGrip
	local DefaultGrip = Vector3.new(1, 2, 0)
	local SpecialGrips = {
		['Remington 870'] = Vector3.new(1, 2, 1.5),
		['AK-47'] = Vector3.new(1, 2, 1.5)
	}
	local originalGrips = setmetatable({}, {
		__mode = 'k'
	})
	
	local function ApplyGrip(tool)
		if not tool:IsA('Tool') then return end
	
		local grip = SpecialGrips[tool.Name] or DefaultGrip
		if tool.GripPos == grip then return end
	
		if originalGrips[tool] == nil then
			originalGrips[tool] = tool.GripPos
		end
	
		tool.GripPos = grip
	end
	
	local function RestoreGrips()
		for tool, grip in originalGrips do
			tool.GripPos = grip
		end
	
		table.clear(originalGrips)
	end
	
	local function EntityAdded()
		local backpack = lplr:FindFirstChildWhichIsA('Backpack')
		if not backpack then
			return
		end
	
		ToolGrip:Clean(backpack.ChildAdded:Connect(ApplyGrip))
		for _, tool in backpack:GetChildren() do
			ApplyGrip(tool)
		end
	end
	
	ToolGrip = vape.Categories.Blatant:CreateModule({
		Name = 'ToolGrip',
		Function = function(callback)
			if callback then
				ToolGrip:Clean(entitylib.Events.LocalAdded:Connect(EntityAdded))
				if entitylib.isAlive then
					task.spawn(EntityAdded)
				end
			else
				RestoreGrips()
			end
		end,
		Tooltip = 'applies tool grip pos'
	})
	
end)

run(function()
	local VehicleFly
	local Mode
	local Speed
	local welds = {}
	local hoverVelocity = Vector3.new(0, 2.25, 0)
	local up, down = 0, 0
	
	VehicleFly = vape.Categories.Blatant:CreateModule({
		Name = 'VehicleFly',
		Function = function(callback)
			if callback then
				up, down = 0, 0
				for _, v in {'InputBegan', 'InputEnded'} do
					VehicleFly:Clean(inputService[v]:Connect(function(input)
						if not inputService:GetFocusedTextBox() then
							if input.KeyCode == Enum.KeyCode.E then
								up = v == 'InputBegan' and 1 or 0
							elseif input.KeyCode == Enum.KeyCode.Q then
								down = v == 'InputBegan' and -1 or 0
							end
						end
					end))
				end
	
				if Mode.Value == 'Part' then
					local part = Instance.new('Part')
					part.Size = Vector3.new(50, 1, 50)
					part.Anchored = true
					part.CanQuery = false
					part.Transparency = 1
	
					VehicleFly:Clean(part)
					repeat
						local seat = entitylib.isAlive and entitylib.character.Humanoid.SeatPart
						if seat then
							part.CFrame = CFrame.new(seat.Position - Vector3.new(0, 2.2 - (up + down), 0))
							part.Parent = workspace
						else
							part.Parent = nil
						end
	
						task.wait(0.05)
					until not VehicleFly.Enabled
				else
					local inCar = false
					local old
					VehicleFly:Clean(runService.PreSimulation:Connect(function(dt)
						local seat = entitylib.isAlive and entitylib.character.Humanoid.SeatPart
						local root = seat and entitylib.character.RootPart
	
						if root then
							if seat ~= old then
								inCar = seat:IsDescendantOf(workspace.CarContainer) and seat:IsA('VehicleSeat')
								if inCar then
									welds = seat.Parent.Parent.Wheels:QueryDescendants('Rotate')
									for _, weld in welds do
										weld.Enabled = false
									end
								end
	
								old = seat
							end
	
							if inCar then
								local humanoid = entitylib.character.Humanoid
								root.AssemblyLinearVelocity = hoverVelocity
								root.CFrame = CFrame.lookAlong(root.Position, gameCamera.CFrame.LookVector) + (humanoid.MoveDirection + Vector3.new(0, up + down, 0)) * Speed.Value * dt
	
								if gameCamera.CameraSubject ~= humanoid then
									gameCamera.CameraSubject = humanoid
								end
							end
						elseif old then
							for _, weld in welds do
								weld.Enabled = true
							end
							old = nil
						end
					end))
				end
			else
				for _, weld in welds do
					weld.Enabled = true
				end
				table.clear(welds)
			end
		end,
		Tooltip = 'Allow you to fly with a vehicle'
	})
	Mode = VehicleFly:CreateDropdown({
		Name = 'Mode',
		List = {'CFrame', 'Part'},
		Function = function(val)
			Speed.Object.Visible = val == 'CFrame'
			if VehicleFly.Enabled then
				VehicleFly:Toggle()
				VehicleFly:Toggle()
			end
		end
	})
	Speed = VehicleFly:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 100,
		Default = 60,
		Darker = true
	})
end)

run(function()
	local VehicleSpeed
	local Speed
	local old
	local seats = {}
	
	VehicleSpeed = vape.Categories.Blatant:CreateModule({
		Name = 'VehicleSpeed',
		Function = function(callback)
			if callback then
				repeat
					local seat = entitylib.isAlive and entitylib.character.Humanoid.SeatPart
					if seat then
						if seat ~= old then
							if seat:IsDescendantOf(workspace.CarContainer) then
								seats = seat.Parent.Parent:QueryDescendants('VehicleSeat')
							end
	
							old = seat
						end
	
						for _, seat in seats do
							seat.MaxSpeed = Speed.Value
							seat.Torque = 4
						end
					end
	
					task.wait()
				until not VehicleSpeed.Enabled
			else
				table.clear(seats)
			end
		end,
		Tooltip = 'Increase vehicle speed'
	})
	Speed = VehicleSpeed:CreateSlider({
		Name = 'Speed',
		Min = 80,
		Max = 200,
		Default = 140
	})
end)

run(function()
	VehicleWallbang = vape.Categories.Blatant:CreateModule({
		Name = 'VehicleWallbang',
		Function = function(callback)
			OriginScanner:UpdateIgnore()
	
			if callback then
				pl.ShootParams.FilterDescendantsInstances = {lplr.Character, workspace.CarContainer}
	
				VehicleWallbang:Clean(entitylib.Events.LocalAdded:Connect(function()
					task.defer(function()
						pl.ShootParams.FilterDescendantsInstances = {lplr.Character, workspace.CarContainer}
					end)
				end))
			else
				pl.ShootParams.FilterDescendantsInstances = {lplr.Character}
			end
		end,
		Tooltip = 'Allow you to shoot through vehicles.'
	})
end)

run(function()
	local C4ESP
	local FillColor
	local OutlineColor
	local FillTransparency
	local OutlineTransparency
	local Reference = {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.holder
	
	local function Added(c4)
		local cham = Instance.new('Highlight')
		cham.Adornee = c4
		cham.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		cham.FillColor = Color3.fromHSV(FillColor.Hue, FillColor.Sat, FillColor.Value)
		cham.OutlineColor = Color3.fromHSV(OutlineColor.Hue, OutlineColor.Sat, OutlineColor.Value)
		cham.FillTransparency = FillTransparency.Value
		cham.OutlineTransparency = OutlineTransparency.Value
		cham.Parent = Folder
	
		Reference[c4] = cham
	end
	
	local function Removed(c4)
		if Reference[c4] then
			if vape.ThreadFix then
				setthreadidentity(8)
			end
	
			Reference[c4]:Destroy()
			Reference[c4] = nil
		end
	end
	
	C4ESP = vape.Categories.Render:CreateModule({
		Name = 'C4ESP',
		Function = function(callback)
			if callback then
				C4ESP:Clean(collectionService:GetInstanceAddedSignal('C4'):Connect(Added))
				C4ESP:Clean(collectionService:GetInstanceRemovedSignal('C4'):Connect(Removed))
	
				for _, c4 in collectionService:GetTagged('C4') do
					task.spawn(Added, c4)
				end
			else
				for _, cham in Reference do
					cham:Destroy()
				end
				table.clear(Reference)
			end
		end,
		Tooltip = 'Display all C4\'s placed'
	})
	FillColor = C4ESP:CreateColorSlider({
		Name = 'Color',
		Function = function(hue, sat, val)
			for _, cham in Reference do
				cham.FillColor = Color3.fromHSV(hue, sat, val)
			end
		end
	})
	OutlineColor = C4ESP:CreateColorSlider({
		Name = 'Outline Color',
		DefaultSat = 0,
		Function = function(hue, sat, val)
			for _, cham in Reference do
				cham.OutlineColor = Color3.fromHSV(hue, sat, val)
			end
		end
	})
	FillTransparency = C4ESP:CreateSlider({
		Name = 'Transparency',
		Min = 0,
		Max = 1,
		Default = 0.5,
		Function = function(val)
			for _, cham in Reference do
				cham.FillTransparency = val
			end
		end,
		Decimal = 10
	})
	OutlineTransparency = C4ESP:CreateSlider({
		Name = 'Outline Transparency',
		Min = 0,
		Max = 1,
		Default = 0.5,
		Function = function(val)
			for _, cham in Reference do
				cham.OutlineTransparency = val
			end
		end,
		Decimal = 10
	})
end)

run(function()
	local AutoDetonate
	local SafeCheck
	local localc4
	local ticks = 0
	local rayParams = RaycastParams.new()
	rayParams.CollisionGroup = 'ClientBullet'
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	
	AutoDetonate = vape.Categories.Utility:CreateModule({
		Name = 'AutoDetonate',
		Function = function(callback)
			if callback then
				AutoDetonate:Clean(collectionService:GetInstanceAddedSignal('C4'):Connect(function(c4)
					if c4:GetAttribute('UserId') == lplr.UserId then
						localc4 = c4
					end
				end))
	
				for _, c4 in collectionService:GetTagged('C4') do
					if c4:GetAttribute('UserId') == lplr.UserId then
						localc4 = c4
					end
				end
	
				repeat
					local backpack = lplr:FindFirstChildWhichIsA('Backpack')
	
					if backpack and localc4 then
						local tool = backpack:FindFirstChild('C4 Explosive')
	
						if tool then
							local entity = entitylib.EntityPosition({
								Players = true,
								Part = 'RootPart',
								Range = 25,
								Origin = localc4.Position
							})
	
							if entity then
								rayParams.FilterDescendantsInstances = {entity.Character, lplr.Character, localc4}
	
								local rootdiff = (entitylib.character.RootPart.Position - localc4.Position)
								local ray = workspace:Raycast(localc4.Position, (entity.RootPart.Position - localc4.Position), rayParams)
								if SafeCheck.Enabled and not ray then
									ray = not (workspace:Raycast(localc4.Position, rootdiff, rayParams) or rootdiff.Magnitude > 40)
								end
	
								if not ray then
									ticks += 1
									if ticks > 3 then
										local lastEquip = lplr.Character:FindFirstChildWhichIsA('Tool')
										entitylib.character.Humanoid:EquipTool(tool)
	
										task.spawn(function()
											replicatedStorage.Remotes.C4.ActivateC4:InvokeServer()
										end)
	
										if lastEquip then
											entitylib.character.Humanoid:EquipTool(lastEquip)
										else
											entitylib.character.Humanoid:UnequipTools()
										end
									end
	
									task.wait(0.05)
									continue
								end
							end
						end
					end
	
					ticks = 0
					task.wait(0.05)
				until not AutoDetonate.Enabled
			end
		end,
		Tooltip = 'Automatically detonate when enemies are nearby.'
	})
	SafeCheck = AutoDetonate:CreateToggle({
		Name = 'Safety Check'
	})
end)

run(function()
	local AutoReload
	local HotSwap
	local thread, oldplaysound
	local priority = {
		M4A1 = 1,
		['AK-47'] = 1,
		MP5 = 1,
		FAL = 1,
		['Remington 870'] = 2,
		M9 = 3,
		Revolver = 4
	}
	
	local function getWeapon()
		local items = {}
		local backpack = lplr:FindFirstChildWhichIsA('Backpack')
		if backpack then
			for _, tool in backpack:GetChildren() do
				if tool:GetAttribute('FireRate') and (tool:GetAttribute('Local_ReloadSession') or 0) <= 0 and tool.Name ~= 'Taser' and tool.Name ~= 'M700' then
					table.insert(items, tool)
				end
			end
	
			table.sort(items, function(a, b)
				return (priority[a.Name] or 100) < (priority[b.Name] or 100)
			end)
	
			return items[1]
		end
	end
	
	AutoReload = vape.Categories.Utility:CreateModule({
		Name = 'AutoReload',
		Function = function(callback)
			if callback then
				local gui = lplr.PlayerGui.Home.hud.BottomRightFrame.GunFrame.BulletsLabel
				if gui then
					AutoReload:Clean(gui:GetPropertyChangedSignal('Text'):Connect(function()
						if gui.Text ~= '...' then
							local tool = debug.getupvalue(pl.Shoot, 1)
							if tool and tool:GetAttribute('Local_CurrentAmmo') <= 0 then
								task.spawn(pl.Reload)
	
								if HotSwap.Enabled then
									local weapon = getWeapon()
	
									if weapon then
										entitylib.character.Humanoid:EquipTool(weapon)
									end
								end
							end
						end
					end))
	
					-- reimplementation of playsound to get rid of the bad error
					oldplaysound = hookfunction(pl.PlaySound, function(sound)
						local obj = debug.getupvalue(pl.Shoot, 1)
						obj = obj and obj:FindFirstChild('Handle')
						obj = obj and obj:FindFirstChild(sound)
	
						if obj then
							local clone = obj:Clone()
							clone.Parent = obj.Parent
							clone:Play()
	
							task.delay(5, clone.Destroy, clone)
						end
					end)
				end
			else
				if oldplaysound then
					if restorefunction then
						restorefunction(pl.PlaySound)
					else
						hookfunction(pl.PlaySound, oldplaysound)
					end
	
					oldplaysound = nil
				end
			end
		end,
		Tooltip = 'Automatically reload after reaching 0 bullets'
	})
	HotSwap = AutoReload:CreateToggle({
		Name = 'Auto Swap',
		Tooltip = 'Automatically swap weapons when reloading'
	})
end)

run(function()
	local AutoTeam
	local AutoOnDied
	
	local function openTeamMenu()
		local home = lplr.PlayerGui:FindFirstChild('Home', true)
		local switch = home and home.hud.Topbar.MenuFrame.SwitchTeams
		if switch then
			firesignal(switch.MouseButton1Click)
		end
	end
	
	local function joinFirstTeam()
		local teamGui = lplr.PlayerGui:FindFirstChild('TeamsFrame', true)
		if not teamGui then return end
		for _, holder in teamGui:GetChildren() do
			if holder.Button.AutoButtonColor then
				firesignal(holder.Button.MouseButton1Click)
				return
			end
		end
	end
	
	AutoTeam = vape.Categories.Utility:CreateModule({
		Name = 'AutoTeam',
		Function = function(callback)
			local diedConnection
	
			local function onDeath()
				if not AutoOnDied.Enabled then return end
	
				openTeamMenu()
				task.wait(0.8)
				joinFirstTeam()
			end
	
			local function connectDeath(entity)
				local humanoid = entity and entity.Humanoid
				if not humanoid then return end
	
				if diedConnection then
					diedConnection:Disconnect()
				end
	
				diedConnection = humanoid.Died:Connect(onDeath)
			end
	
			if callback then
				joinFirstTeam()
	
				AutoTeam:Clean(entitylib.Events.LocalAdded:Connect(connectDeath))
				if entitylib.isAlive then
					connectDeath(entitylib.character)
				end
			else
				if diedConnection then
					diedConnection:Disconnect()
					diedConnection = nil
				end
			end
		end,
		Tooltip = 'Automatically join a team when joining the server'
	})
	
	AutoOnDied = AutoTeam:CreateToggle({
		Name = 'OnDied',
		Default = false,
		Tooltip = 'Automatically pick team on death'
	})
	
end)

run(function()
	local AutoToxic
	local Presets = {}
	local cloned = {}
	local random = Random.new()
	
	local lines = {
		'prison life moment | kicked <obj>',
		'do you also want an antifling? | kicked <obj>',
		'i wonder why you got kicked | kicked <obj>',
	}
	
	local function sendMessage(obj)
		if not next(cloned) then
			cloned = table.clone(lines)
		end
	
		local message = table.remove(cloned, random:NextInteger(1, #cloned)):gsub('<obj>', obj or '')
	
		if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
			local channel = textChatService.ChatInputBarConfiguration.TargetTextChannel
	
			if textChatService:CanUserChatAsync(lplr.UserId) then
				channel:SendAsync(message)
				channel:SendPresetAsync(Presets['So close'])
			else
				channel:SendPresetAsync(Presets['So close'])
			end
		else
			replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(message, 'All')
		end
	end
	
	AutoToxic = vape.Categories.Utility:CreateModule({
		Name = 'AutoToxic',
		Function = function(callback)
			if callback then
				AutoToxic:Clean(vapeEvents.CheaterKicked.Event:Connect(sendMessage))
			end
		end,
		Tooltip = 'Says a message after a cheater gets kicked with CheatDetector enabled.'
	})
	
	pcall(function()
		for _, group in textChatService:GetPresetsAsync().categoryGroups do
			for _, category in group.categories do
				for _, message in category.messages do
					Presets[message.value] = message.presetId
				end
			end
		end
	end)
	
end)

run(function()
	local ChatCommand
	local addTarget
	local kickTargetList
	local TARGET_COLOR = Color3.new(1, 0, 0)
	
	local options = {}
	local teamAliases = {
		g = 'Guards',
		guard = 'Guards',
		guards = 'Guards',
		i = 'Inmates',
		inmate = 'Inmates',
		inmates = 'Inmates',
		c = 'Criminals',
		criminal = 'Criminals',
		criminals = 'Criminals'
	}
	local teamsService = cloneref(game:GetService('Teams'))
	local viewPlayer
	local followModule, followOldMove, followPlayer, followConnection
	
	local function trim(text)
		return text and text:match('^%s*(.-)%s*$') or nil
	end
	
	local function disconnect(connection)
		if connection then
			connection:Disconnect()
		end
	
		return nil
	end
	
	local function getLocalHumanoid()
		local character = lplr.Character
		local humanoid = character and character:FindFirstChildOfClass('Humanoid')
		return humanoid or (entitylib.character and entitylib.character.Humanoid)
	end
	
	-- Lists
	
	local function setListValue(list, value, enabled)
		if list and list.ListEnabled and enabled ~= (table.find(list.ListEnabled, value) ~= nil) then
			list:ChangeValue(value)
		end
	end
	
	local function clearListValues(list)
		if not list or not list.List then return 0 end
	
		local count = #list.List
		if count == 0 and #list.ListEnabled == 0 then return 0 end
	
		table.clear(list.List)
		table.clear(list.ListEnabled)
		list:ChangeValue()
		return count
	end
	
	-- Camera
	
	local function clearViewConnection()
		viewPlayer = nil
	end
	
	local function restoreCamera()
		clearViewConnection()
	
		local humanoid = getLocalHumanoid()
		if humanoid then
			gameCamera.CameraSubject = humanoid
			gameCamera.CameraType = Enum.CameraType.Custom
		end
	end
	
	-- Player lookup
	
	local function findEntity(prefix, includeDead)
		prefix = trim(prefix)
		if not prefix or prefix == '' then return end
	
		local lowered = prefix:lower()
		local length = #lowered
		local partial
	
		for _, entity in entitylib.List do
			local humanoid = entity.Humanoid
			if not humanoid or (not includeDead and humanoid.Health <= 0) then continue end
	
			local player = entity.Player
			if not player then continue end
	
			local name = player.Name:lower()
			local display = player.DisplayName:lower()
			if name == lowered or display == lowered then
				return entity
			end
	
			if not partial and (name:sub(1, length) == lowered or display:sub(1, length) == lowered) then
				partial = entity
			end
		end
	
		return partial
	end
	
	local function findPlayer(prefix, allowLeft)
		local entity = findEntity(prefix, true)
		if entity then
			return entity.Player
		end
	
		if not allowLeft then return end
	
		prefix = trim(prefix)
		if not prefix or prefix == '' then return end
	
		local lowered = prefix:lower()
		local length = #lowered
		local partial
	
		for _, plr in playersService:GetPlayers() do
			local name = plr.Name:lower()
			local display = plr.DisplayName:lower()
			if name == lowered or display == lowered then
				return plr
			end
	
			if not partial and (name:sub(1, length) == lowered or display:sub(1, length) == lowered) then
				partial = plr
			end
		end
	
		return partial
	end
	
	-- Follow
	
	local function getFollowEntity()
		if not followPlayer then return end
	
		return entitylib.getEntity(followPlayer)
	end
	
	local function stopFollow()
		followConnection = disconnect(followConnection)
	
		if followModule and followOldMove then
			followModule.moveFunction = followOldMove
		end
	
		followModule, followOldMove = nil, nil
		followPlayer = nil
	end
	
	local function startFollow(player)
		stopFollow()
	
		local module
		if not pcall(function()
			module = require(lplr.PlayerScripts.PlayerModule).controls
		end) or not module or not module.moveFunction then
			notif('ChatCommand', 'Follow is not supported in this game.', 5, 'warning')
			return
		end
	
		followPlayer = player
		followModule = module
		followOldMove = module.moveFunction
	
		module.moveFunction = function(self, vec, face)
			local humanoid = getLocalHumanoid()
			if not humanoid or humanoid.Health <= 0 then
				return followOldMove(self, vec, face)
			end
	
			local targetEntity = getFollowEntity()
			local targetRoot = targetEntity and targetEntity.RootPart
			local root = entitylib.character and entitylib.character.RootPart
			if targetRoot and root then
				local direction = (targetRoot.Position - root.Position) * Vector3.new(1, 0, 1)
				if direction.Magnitude > 1 then
					vec = direction.Unit
				end
			end
	
			return followOldMove(self, vec, face)
		end
	
		followConnection = runService.PreSimulation:Connect(function()
			local humanoid = getLocalHumanoid()
			if not humanoid or humanoid.Health <= 0 then
				stopFollow()
				return
			end
	
			if humanoid.Sit then
				humanoid.Sit = false
			end
	
			if not followPlayer or not followPlayer.Parent then
				stopFollow()
			end
		end)
	end
	
	-- Team switching
	
	local function findTeam(name)
		name = trim(name)
		if not name or name == '' then return end
	
		local lowered = name:lower()
		local team = teamsService:FindFirstChild(teamAliases[lowered] or name)
		if team then
			return team
		end
	
		for _, child in teamsService:GetChildren() do
			if child.Name:lower():sub(1, #lowered) == lowered then
				return child
			end
		end
	
		return nil
	end
	
	local function handleTeam(args)
		if not options.ChangeTeam.Enabled then return end
	
		local targetTeam = findTeam(args and args:match('^%S+$'))
		if not targetTeam then return end
	
		local autoTeam = vape.Modules.AutoTeam
		if autoTeam and autoTeam.Join then
			autoTeam:Join(targetTeam.Name)
			return
		end
	
		notif('ChatCommand', 'AutoTeam is not available in this game.', 5, 'warning')
	end
	
	-- Reload / servers
	
	local function handleReload()
		if not options.ReloadVape.Enabled then return end
	
		local success, err = pcall(function()
			vape:Save()
			shared.vapereload = true
			if shared.VapeDeveloper then
				loadstring(readfile('newvape/loader.lua'), 'loader')()
			else
				loadstring(game:HttpGet('https://raw.githubusercontent.com/Night5449791/InhalerCompiled/'..readfile('newvape/profiles/commit.txt')..'/loader.lua', true))()
			end
		end)
	
		if not success then
			notif('ChatCommand', 'Failed to reload : '..tostring(err), 5, 'warning')
		end
	end
	
	local function handleHop()
		if not options.ServerHop.Enabled then return end
	
		local serverHop = vape.Modules.ServerHop
		if serverHop then
			serverHop:Toggle()
		end
	end
	
	local function handleRejoin()
		if not options.Rejoin.Enabled then return end
	
		local rejoin = vape.Modules.Rejoin
		if rejoin and not rejoin.Enabled then
			rejoin:Toggle()
		end
	end
	
	-- Whitelist / target lists
	
	local function handleWhitelist(args, remove)
		if not options.Whitelist.Enabled then return end
	
		local player = findPlayer(args, remove)
		if not player then
			notif('Whitelist', 'No player found.', 5, 'warning')
			return
		end
	
		setListValue(vape.Categories.Friends, player.Name, not remove)
		notif('Whitelist', player.DisplayName..' has been '..(remove and 'unwhitelisted.' or 'whitelisted.'), 5)
	end
	
	local function clearAllTargets()
		local count = clearListValues(vape.Categories.Targets) + clearListValues(kickTargetList())
		notif('Blacklist', count > 0 and 'Cleared '..count..' target'..(count == 1 and '' or 's') or 'No targets to clear.', 5)
	end
	
	local function handleTargets(args, remove)
		if not options.Blacklist.Enabled then return end
	
		args = trim(args)
		if not args or args == '' then return end
	
		if args:lower() == 'all' then
			clearAllTargets()
			return
		end
	
		local player = findPlayer(args, remove)
		if not player then
			notif('Blacklist', 'No player found.', 5, 'warning')
			return
		end
	
		addTarget(player.Name, not remove)
		notif('Blacklist', player.DisplayName..' has been '..(remove and 'unblacklisted.' or 'blacklisted.'), 5)
	end
	
	-- KickExploit bridge
	
	local function kickModule()
		if vape and vape.Modules and vape.Modules.KickExploit then
			return vape.Modules.KickExploit
		end
	
		if vape and vape.Categories and vape.Categories.World then
			local worldModule = vape.Categories.World.Modules and vape.Categories.World.Modules.KickExploit
			if worldModule then
				return worldModule
			end
		end
	
		return nil
	end
	
	kickTargetList = function()
		local module = kickModule()
		if not module then return end
	
		return (module.Options and module.Options['Targets']) or module.List or module.Targets
	end
	
	local function setKickTarget(name, enabled)
		setListValue(kickTargetList(), name, enabled)
	end
	
	local function setKickMode(mode)
		local module = kickModule()
		if not module then return end
	
		local modeOption = (module.Options and module.Options['Mode']) or module.Mode
		if modeOption and modeOption.SetValue then
			modeOption:SetValue(mode)
		end
	end
	
	addTarget = function(name, enabled)
		setKickTarget(name, enabled)
		setListValue(vape.Categories.Targets, name, enabled)
	
		if enabled then
			whitelist.customtags[name] = {{text = 'Exploiter', color = TARGET_COLOR}}
			tempTargets[name] = true
		else
			whitelist.customtags[name] = nil
			tempTargets[name] = nil
		end
	end
	
	local kickTeams = {}
	local kickTeamMembers = {}
	
	local function addKickTeamMember(plr)
		if not plr or not next(kickTeams) or not plr.Team or not table.find(kickTeams, plr.Team) then return end
		if table.find(kickTeamMembers, plr.Name) then return end
	
		table.insert(kickTeamMembers, plr.Name)
		addTarget(plr.Name, true)
	end
	
	local function stopKickTeam()
		table.clear(kickTeams)
	
		for _, name in kickTeamMembers do
			addTarget(name, false)
		end
	
		table.clear(kickTeamMembers)
	end
	
	local function startKick(mode, text)
		local module = kickModule()
		if not module then return end
	
		setKickMode(mode)
		if not module.Enabled then
			module:Toggle()
		end
	
		if module.Enabled then
			notif('KickExploit', text, 5)
		else
			notif('KickExploit', 'KickExploit failed to enable.', 5, 'warning')
		end
	end
	
	local function stopKick()
		stopKickTeam()
	
		local module = kickModule()
		if module and module.Enabled then
			module:Toggle()
		end
	
		notif('KickExploit', 'Kick disabled.', 5)
	end
	
	local function handleKick(args)
		if not options.Kick.Enabled then return end
	
		if not kickModule() then
			notif('ChatCommand', 'KickExploit is not available in this game.', 5, 'warning')
			return
		end
	
		local name = trim((args or ''):match('^target%s+(.+)$') or args)
		if not name or name == '' then return end
	
		local lowered = name:lower()
		if lowered == 'all' then
			stopKickTeam()
			startKick('All', 'Flinging all players.')
			return
		elseif lowered == 'none' or lowered == 'off' or lowered == 'stop' then
			stopKick()
			return
		end
	
		local player = findPlayer(name, true)
		if not player then
			notif('KickExploit', 'No player found.', 5, 'warning')
			return
		end
	
		addTarget(player.Name, true)
		startKick('Individual', 'Flinging '..player.Name..'.')
	end
	
	local function handleKickTeam(args)
		if not options.Kick.Enabled then return end
	
		if not kickModule() then
			notif('ChatCommand', 'KickExploit is not available in this game.', 5, 'warning')
			return
		end
	
		local wanted = {}
		for token in (args or ''):gmatch('%S+') do
			local team = findTeam(token)
			if team and not table.find(wanted, team) then
				table.insert(wanted, team)
			end
		end
	
		if not next(wanted) then
			notif('KickExploit', 'No team found. (c/i/g, criminals/inmates/guards)', 5, 'warning')
			return
		end
	
		stopKickTeam()
		local names = {}
		for _, team in wanted do
			table.insert(kickTeams, team)
			table.insert(names, team.Name)
	
			for _, plr in team:GetPlayers() do
				addKickTeamMember(plr)
			end
		end
	
		startKick('Individual', 'Flinging '..table.concat(names, ', ')..'.')
	end
	
	local function handleKickMethod(args)
		if not options.Kick.Enabled then return end
	
		local module = kickModule()
		if not module then
			notif('ChatCommand', 'KickExploit is not available in this game.', 5, 'warning')
			return
		end
	
		local method = trim(args)
		if not method or method == '' then return end
	
		local option = module.Options and module.Options['Kick Mode']
		if not option or not option.SetValue then return end
	
		local lowered = method:lower()
		if lowered == 'normal' then
			option:SetValue('Normal')
			notif('KickExploit', 'Kick method: Normal', 5)
		elseif lowered == 'killfling' or lowered == 'kill' or lowered == 'headfling' or lowered == 'head' then
			option:SetValue('Killfling')
			notif('KickExploit', 'Kick method: Killfling', 5)
		else
			notif('KickExploit', 'Invalid method. (normal/killfling)', 5, 'warning')
		end
	end
	
	-- Movement / camera commands
	
	local function handleTP(args)
		if not options.PlayerTP.Enabled then return end
	
		local target = findEntity(args)
		local localRoot = entitylib.character and entitylib.character.RootPart
		if not target or not target.RootPart or not localRoot then
			notif('ChatCommand', 'No living player found.', 5, 'warning')
			return
		end
	
		localRoot.CFrame = target.RootPart.CFrame + Vector3.new(0, 2, 0)
	end
	
	local function handleFollow(args)
		if not options.PlayerFollow.Enabled then return end
	
		local player = findPlayer(args)
		if not player then
			notif('ChatCommand', 'No player found.', 5, 'warning')
			return
		end
	
		startFollow(player)
		if followPlayer then
			notif('ChatCommand', 'Following '..player.DisplayName..'.', 5)
		end
	end
	
	local function handleUnfollow()
		stopFollow()
		notif('ChatCommand', 'Stopped following.', 5)
	end
	
	local danceTrack
	
	local function stopDance()
		if danceTrack then
			pcall(function()
				danceTrack:Stop()
				danceTrack:Destroy()
			end)
			danceTrack = nil
		end
	end
	
	local function handleDance()
		if not options.Dance.Enabled then return end
	
		stopDance()
	
		local humanoid = getLocalHumanoid()
		if not humanoid or not humanoid.Parent then
			notif('ChatCommand', 'No character found.', 5, 'warning')
			return
		end
	
		local r15 = humanoid.RigType == Enum.HumanoidRigType.R15
		local dances = r15
			and {'3333432454', '4555808220', '4049037604', '4555782893', '10214311282', '10714010337', '10713981723', '10714372526', '10714076981', '10714392151', '11444443576'}
			or {'27789359', '30196114', '248263260', '45834924', '33796059', '28488254', '52155728'}
	
		local animation = Instance.new('Animation')
		animation.AnimationId = 'rbxassetid://'..dances[math.random(1, #dances)]
		danceTrack = humanoid:LoadAnimation(animation)
		danceTrack.Looped = true
		danceTrack:Play()
		notif('ChatCommand', 'Dancing.', 5)
	end
	
	local function handleStopDance()
		if not options.Dance.Enabled then return end
	
		stopDance()
		notif('ChatCommand', 'Stopped dancing.', 5)
	end
	
	local function getTargetStrafe()
		local module = vape.Modules and vape.Modules.TargetStrafe
		if module then return module end
	
		local blatant = vape.Categories and vape.Categories.Blatant
		return blatant and blatant.Modules and blatant.Modules.TargetStrafe
	end
	
	local function handleTargetStrafe(args)
		if not options.TargetStrafe.Enabled then return end
	
		local module = getTargetStrafe()
		if not module then
			notif('ChatCommand', 'TargetStrafe is not available in this game.', 5, 'warning')
			return
		end
	
		args = trim(args)
		local lowered = args and args:lower()
		if not args or lowered == 'off' or lowered == 'stop' or lowered == 'none' then
			local targeting = module.Options and module.Options['Targeting']
			if targeting and targeting.Enabled then
				targeting:Toggle()
			end
	
			notif('ChatCommand', 'TargetStrafe targeting disabled.', 5)
			return
		end
	
		local targeting = module.Options and module.Options['Targeting']
		local username = module.Options and module.Options['Target Username']
		if not targeting or not username then
			notif('ChatCommand', 'TargetStrafe targeting options are missing.', 5, 'warning')
			return
		end
	
		if not module.Enabled then
			module:Toggle()
		end
		if not targeting.Enabled then
			targeting:Toggle()
		end
		username:SetValue(args)
		notif('ChatCommand', 'TargetStrafe locked onto '..args..'.', 5)
	end
	
	local function handleStopTargetStrafe()
		handleTargetStrafe('off')
	end
	
	local toggles = {
		{Name = 'PlayerTP', Tooltip = '.tp <plr>'},
		{Name = 'PlayerFollow', Tooltip = '.follow <plr>\n.unfollow', Function = function(enabled)
			if not enabled then
				stopFollow()
			end
		end},
		{Name = 'PlayerView', Tooltip = '.view <plr>\n.unview', Function = function(enabled)
			if not enabled then
				restoreCamera()
			end
		end},
		{Name = 'Rejoin', Tooltip = '.rj\n.rejoin'},
		{Name = 'ServerHop', Tooltip = '.hop\n.serverhop'},
		{Name = 'ReloadVape', Tooltip = '.reload'},
		{Name = 'ChangeTeam', Tooltip = '.team <name>'},
		{Name = 'Whitelist', Tooltip = '.wl/.whitelist <plr>\n.unwl/.unwhitelist <plr>'},
		{Name = 'Blacklist', Tooltip = '.target/.blacklist <plr>\n.untarget/.unblacklist <plr>\n.untarget all/.target all clears every target'},
		{Name = 'Kick', Tooltip = '.kick <plr>\n.kick all\n.kick none\n.kickteam <c/i/g, criminals/inmates/guards>\n.kickmethod <normal/killfling>'},
		{Name = 'Dance', Tooltip = '.dance\n.dundance', Function = function(enabled)
			if not enabled then
				stopDance()
			end
		end},
		{Name = 'TargetStrafe', Tooltip = '.tstrafe <username>\n.tstrafe off / .untstrafe'}
	}
	
	local function handleView(args)
		if not options.PlayerView.Enabled then return end
	
		local player = findPlayer(args)
		local entity = player and entitylib.getEntity(player)
		if not entity then
			notif('ChatCommand', 'No player found.', 5, 'warning')
			return
		end
	
		clearViewConnection()
		viewPlayer = player
		gameCamera.CameraSubject = entity.Humanoid
	end
	
	local function handleHelp()
		local enabled = {}
		for _, toggle in toggles do
			if options[toggle.Name].Enabled then
				table.insert(enabled, toggle.Tooltip:gsub('\n', ' / '))
			end
		end
	
		table.sort(enabled)
		notif('ChatCommand', #enabled > 0 and table.concat(enabled, '\n') or 'No commands enabled.', 8)
	end
	
	local commands = {
		help = handleHelp,
		tp = handleTP,
		follow = handleFollow,
		unfollow = handleUnfollow,
		dance = handleDance,
		dundance = handleStopDance,
		nodance = handleStopDance,
		view = handleView,
		unview = restoreCamera,
		wl = function(args)
			handleWhitelist(args, false)
		end,
		whitelist = function(args)
			handleWhitelist(args, false)
		end,
		unwl = function(args)
			handleWhitelist(args, true)
		end,
		unwhitelist = function(args)
			handleWhitelist(args, true)
		end,
		target = function(args)
			handleTargets(args, false)
		end,
		blacklist = function(args)
			handleTargets(args, false)
		end,
		untarget = function(args)
			handleTargets(args, true)
		end,
		unblacklist = function(args)
			handleTargets(args, true)
		end,
		kick = handleKick,
		kickteam = handleKickTeam,
		kickmethod = handleKickMethod,
		team = handleTeam,
		hop = handleHop,
		serverhop = handleHop,
		rj = handleRejoin,
		rejoin = handleRejoin,
		reload = handleReload,
		tstrafe = handleTargetStrafe,
		targetstrafe = handleTargetStrafe,
		untstrafe = handleStopTargetStrafe
	}
	
	local function onChatted(message)
		message = trim(message)
		if message:sub(1, 1) ~= '.' then return end
	
		local command, args = message:sub(2):match('^(%S+)%s*(.*)$')
		command = command and command:lower()
		if not command then return end
	
		local handler = commands[command]
		if handler then
			handler(args ~= '' and args or nil)
		end
	end
	
	ChatCommand = vape.Categories.Utility:CreateModule({
		Name = 'ChatCommand',
		Function = function(callback)
			if not callback then return end
	
			ChatCommand:Clean(restoreCamera)
			ChatCommand:Clean(stopFollow)
			ChatCommand:Clean(stopDance)
			ChatCommand:Clean(playersService.PlayerRemoving:Connect(function(plr)
				if plr == viewPlayer then
					restoreCamera()
				end
	
				if plr == followPlayer then
					stopFollow()
				end
			end))
			ChatCommand:Clean(entitylib.Events.EntityAdded:Connect(function(entity)
				if not entity.Player then return end
	
				if entity.Player == viewPlayer then
					gameCamera.CameraSubject = entity.Humanoid
				end
	
				addKickTeamMember(entity.Player)
			end))
			ChatCommand:Clean(stopKickTeam)
			ChatCommand:Clean(lplr.Chatted:Connect(onChatted))
		end,
		Tooltip = 'Chat commands, every command is a toggleable option\n.help lists the enabled commands'
	})
	
	for _, toggle in toggles do
		options[toggle.Name] = ChatCommand:CreateToggle({
			Name = toggle.Name,
			Tooltip = toggle.Tooltip,
			Default = true,
			Function = toggle.Function
		})
	end
	
end)

run(function()
	local CheatDetector
	local AddTarget
	local Teleport
	local positions = {}
	local overlap = OverlapParams.new()
	overlap.CollisionGroup = 'Players'
	overlap.FilterDescendantsInstances = {workspace.CarContainer, workspace.Doors}
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	local carOverlap = OverlapParams.new()
	carOverlap.FilterDescendantsInstances = {workspace.CarContainer}
	carOverlap.FilterType = Enum.RaycastFilterType.Include
	carOverlap.MaxParts = 1
	
	local whiteliststates = {
		[Enum.HumanoidStateType.Running] = true,
		[Enum.HumanoidStateType.Jumping] = true,
		[Enum.HumanoidStateType.Freefall] = true,
		[Enum.HumanoidStateType.Landed] = true,
		[Enum.HumanoidStateType.FallingDown] = true,
		[Enum.HumanoidStateType.GettingUp] = true,
		[Enum.HumanoidStateType.Climbing] = true,
		[Enum.HumanoidStateType.Seated] = true,
		[Enum.HumanoidStateType.Ragdoll] = true,
		[Enum.HumanoidStateType.Dead] = true,
		[Enum.HumanoidStateType.None] = true
	}
	
	CheatDetector = vape.Categories.Utility:CreateModule({
		Name = 'CheatDetector',
		Function = function(callback)
			if callback then
				CheatDetector:Clean(vapeEvents.CheatFlagged.Event:Connect(function(plr, flagType)
					notif('CheatDetector', 'This player may be cheating! ('..flagType..'): '..plr.Name, 60, 'warning')
					if AddTarget.Enabled then
						tempTargets[plr.Name] = true
					end
	
					local entity = entitylib.getEntity(plr)
					if entity then
						entitylib.Events.EntityUpdated:Fire(entity)
						if AddTarget.Enabled then
							entity.Target = true
						end
					end
				end))
	
				CheatDetector:Clean(entitylib.Events.EntityRemoved:Connect(function(entity)
					positions[entity] = nil
				end))
	
				repeat
					local clock = os.clock()
	
					for _, entity in entitylib.List do
						if entity.Health > 0 and entity.Player and not Cheats.Flagged[entity.Player.UserId] then
							local root = entity.RootPart
							local humanoid = entity.Humanoid
							local playerPos = root.Position
	
							if not checkPoint(entity.Head.Position, overlap) then
								Cheats:Flag(entity.Player, 'phase/noclip', 20)
							end
	
							local state = humanoid:GetState()
							if not whiteliststates[state] then
								Cheats:Flag(entity.Player, 'invalid state '..state.Name, 1)
							end
	
							local velo = root.AssemblyLinearVelocity
							if not humanoid.SeatPart then
								if (velo * flatMask).Magnitude > 26 and #workspace:GetPartBoundsInRadius(playerPos, 30, carOverlap) <= 0 then
									Cheats:Flag(entity.Player, 'speed', 20)
								end
	
								local last = positions[entity]
								if last then
									if Teleport.Enabled and ((playerPos - last[1]) * flatMask).Magnitude > 50 and #workspace:GetPartBoundsInRadius(playerPos, 30, carOverlap) <= 0 then
										if entity.Player.Team ~= teams.Inmates or (clock - entity.SpawnTime) > 0.1 then
											Cheats:Flag(entity.Player, 'teleport', 1)
										end
									end
								end
	
								if velo.Y > 50 then
									Cheats:Flag(entity.Player, 'highjump', 20)
								end
	
								if not last or (clock - last[2]) > 0.2 then
									positions[entity] = {playerPos, clock}
								end
							else
								positions[entity] = {playerPos, clock}
							end
						end
					end
	
					task.wait(0.05)
				until not CheatDetector.Enabled
			else
				table.clear(positions)
				Cheats:Clear()
			end
		end,
		Tooltip = 'Sends alerts for any possible cheaters.'
	})
	AddTarget = CheatDetector:CreateToggle({
		Name = 'Temporary Target',
		Tooltip = 'Add temporary combat module priority for cheaters.',
		Default = true
	})
	Teleport = CheatDetector:CreateToggle({
		Name = 'Teleport',
		Tooltip = 'Detect people teleporting (EXPERIMENTAL)',
		Default = true
	})
end)

run(function()
	-- we all code for shits lol
	
	local CheaterDetector
	local Users
	
	local cUsernames = {
		['WyRaff'] = 'speedhack,teleporting', -- vc server common
		['PraiseDracc'] = 'known exploiter', -- since he is commonly in vc server
		['jerry_plsnoban7'] = 'known exploiter (kerax)', -- cringe
		['jerry_plsnoban6'] = 'known exploiter (kerax)',
		['jerry_plsnoban5'] = 'known exploiter (kerax)',
		['rudeeis_ab'] = 'phase/noclip ahhh hack', -- saint member, dont they even use the same thing
		['JOJI12416'] = 'known exploiter (kerax owner)', -- kerax if u wonder
		['DawnPulseVoid'] = 'known exploiter',
		['BestCode_BaconThx']= 'known exploiter (kerax)',   -- join .gg/prisonlife if u got flagged by this dude, we wanna laugh at u
		['RazhulanDeveloper'] = 'known exploiter (kerax)', -- join .gg/prisonlife if u got flagged by this dude, we wanna laugh at u
		['SaintSkirr'] = 'known exploiter (vape)', -- not a big deal, why kerax just why
		['centipedeinmyheads'] = 'known exploiter (kerax)', -- NOT another saint member lol, kerax user
		-- skids list
		["veggeta38372737"] = "kerax user, abuser", -- most kerax users are skids abusing so, yeah
		['jbskjbg'] = 'invalid state Platform Stand exp',
		['1267_isevil'] = 'failed fling attempt',
		['1987_isevil'] = 'failed fling attempt',
		['HeyiamTheCooolest'] = 'skid exploiter',
		['Chill_baconr00'] = 'highjump', --  using vape v4 from Night5449791 and cant beat me XD
		['gcfhjfjf4'] = 'highjump, aimbot',
		['dannielll51'] = 'headsit exploit', -- inspired, vape antiheadsit soon.
		['Bonjour394'] = 'skid exploiter', -- hes js a jerk
		['princeofegypt'] = 'gets kicked for fling attempt', -- imagine gets kicked for script that kicks
		['bilinmez4095'] = 'invalid state Platform Stand',
		['djdjdd54321'] = 'phase/noclip into walls',
		['cnmjm222'] = 'invisible',
		['oyeuser67'] = 'speedhack',
		['BetterCallMe788'] = 'fling',
		['Avacad0731'] = 'phase/noclip',
		['C0nquerons'] = 'Platform Stand exploit',
		['goobyzoobytv'] = 'phase/noclip',
		['Joni_8824'] = 'phase/noclip',
		['jaycomputing'] = 'skid using selenium larps and got kicked',
		['tooodarl9'] = 'skid exploiter',
		['Henr45555455'] = 'invalid state Platform Stand',
		['Marssimo_14'] = 'invalid state Platform Stand',
		['boy_cantot2'] = 'invalid state Platform Stand',
		['killerdoy372bro'] = 'invalid animation',
		['trervoTDJ'] = 'aimbotting',
		['Pedro9Henrique2000'] = 'phase/noclip',
		["faizan1111789"] = "speed",
		['juanpro231ew'] = "invalid state Swimming",
		["voidwalker5346"] = "invalid animation (car kick)",
		["mchser3"] = "invalid state Swimming",
		["ang5454"] = "highjump",
		['rackasauras'] = 'speed',
		["dobys149"] = "phase/noclip",
		["SyntaxK3v"] = "speed",
		["Thacosmick_2"] = "invalid state Swimming",
		["Unicornpoop1239508"] = "speed",
		["kind_jack001"] = "invalid animation (invis)",
		["lilyazz0000"] = "invalid state PlatformStanding (fly)",
		["nobby_rules2"] = "speed",
		["duimaxxing"] = "phase/noclip",
		['sauodwuansd212'] = 'fling/kickall'
	}
	
	local function playerAdded(plr)
		local reason = cUsernames[plr.Name]
		if Users then
			reason = table.find(Users.ListEnabled, tostring(plr.UserId)) or reason
		end
	
		if reason then
			notif('CheaterDetector', 'Cheater Detected ('..reason..'): '..plr.Name, 60, 'alert')
			whitelist.customtags[plr.Name] = {{text = 'Exploiter', color = Color3.new(1, 0, 0)}}
			tempTargets[plr.Name] = true
		end
	end
	
	CheaterDetector = vape.Categories.Utility:CreateModule({
		Name = 'CheaterDetector',
		Function = function(callback)
			if callback then
				CheaterDetector:Clean(playersService.PlayerAdded:Connect(playerAdded))
				for _, v in playersService:GetPlayers() do
					task.spawn(playerAdded, v)
				end
			end
		end,
		Tooltip = 'Detects people with history of cheating',
	})
end)

run(function()
	local AntiFling
	local modified = {}
	
	local function LocalAdded(entity)
		for _, prompt in workspace.CarContainer:QueryDescendants('ProximityPrompt') do
			prompt.Enabled = not entity.Humanoid.SeatPart and not prompt.Parent.Occupant
		end
	
		AntiFling:Clean(entity.Humanoid:GetPropertyChangedSignal('SeatPart'):Connect(function()
			for _, prompt in workspace.CarContainer:QueryDescendants('ProximityPrompt') do
				prompt.Enabled = not entity.Humanoid.SeatPart and not prompt.Parent.Occupant
			end
		end))
	end
	
	local function Modify(part)
		if part:IsA('BasePart') and part.CollisionGroup ~= 'Wheels' then
			if not modified[part] then
				modified[part] = {part.CanCollide, part.CanQuery}
			end
	
			if (part:IsA('Seat') or part:IsA('VehicleSeat')) and part.Name == part.ClassName then
				local connection
				local prox = Instance.new('ProximityPrompt')
				prox.ActionText = 'Enter'
				prox.Enabled = not part.Occupant
				prox.MaxActivationDistance = 9
				prox.RequiresLineOfSight = false
				prox.Parent = part
	
				prox.Triggered:Connect(function()
					if entitylib.isAlive then
						part:Sit(entitylib.character.Humanoid)
					end
				end)
	
				prox.Destroying:Connect(function()
					connection:Disconnect()
				end)
	
				connection = part:GetPropertyChangedSignal('Occupant'):Connect(function()
					prox.Enabled = not part.Occupant
				end)
			end
	
			part.CanCollide = false
			part.CanTouch = false
		end
	end
	
	AntiFling = vape.Categories.World:CreateModule({
		Name = 'AntiFling',
		Function = function(callback)
			if callback then
				AntiFling:Clean(workspace.CarContainer.DescendantAdded:Connect(Modify))
				AntiFling:Clean(entitylib.Events.LocalAdded:Connect(LocalAdded))
	
				for _, part in workspace.CarContainer:QueryDescendants('BasePart') do
					Modify(part)
				end
	
				if entitylib.isAlive then
					LocalAdded(entitylib.character)
				end
			else
				for part, value in modified do
					part.CanCollide = value[1]
					part.CanTouch = value[2]
				end
	
				for _, prompt in workspace.CarContainer:QueryDescendants('ProximityPrompt') do
					prompt:Destroy()
				end
	
				table.clear(modified)
			end
		end,
		Tooltip = 'Prevent certain methods of flinging you'
	})
end)

run(function()
	local JoinJobid
	local Place
	local JobId
	
	local places = {
		['Non-VC'] = 155615604,
		VC = 135564683255158
	}
	
	JoinJobid = vape.Categories.World:CreateModule({
		Name = 'JoinJobid',
		Function = function(callback)
			if callback then
				JoinJobid:Toggle()
	
				local id = (JobId.Value or ''):gsub('%s+', '')
				if id == '' then
					notif('JoinJobid', 'Enter a job id first.', 5, 'warning')
					return
				end
	
				if id == game.JobId and (places[Place.Value] or game.PlaceId) == game.PlaceId then
					notif('JoinJobid', 'Already in that server.', 5, 'warning')
					return
				end
	
				notif('JoinJobid', 'Joining '..Place.Value..' server.', 5)
				teleportService:TeleportToPlaceInstance(places[Place.Value] or game.PlaceId, id)
			end
		end,
		Tooltip = 'Teleports into a specific server using its job id\nReinjects after the teleport just like ServerHop does.'
	})
	Place = JoinJobid:CreateDropdown({
		Name = 'Place',
		List = {'Non-VC', 'VC'},
		Tooltip = 'Non-VC - 155615604\nVC - 135564683255158'
	})
	JobId = JoinJobid:CreateTextBox({
		Name = 'JobId',
		Placeholder = 'Job id'
	})
	
end)

run(function()
	local Mode
	local List
	local Movement
	local Equipment
	local AutoRejoin
	local PlayerLimit
	local TimeLimit
	local HopList
	local HeadOffset
	local KickMode
	local ViewTarget
	local seats = {}
	local spawners = {}
	local teamButtons = {}
	local candidateList = {}
	local candidateTime = 0
	local didClick = {}
	local lastFling = {}
	local flingRot = {} -- per-target part rotation for Killfling (Head/HRP/Torso)
	local tempList = setmetatable({}, {
		__mode = 'k'
	})
	local leftCache = {} -- target names remembered after they leave; re-added on rejoin
	table.clear(leftCache)
	local CYAN = BrickColor.new('Cyan')
	local GUN_POSITION = Vector3.new(816, 98, 2233)
	local EQUIP_POSITION = CFrame.new(GUN_POSITION)
	local DRIVE_VELOCITY = Vector3.new(24, 0, 0)
	local NORMAL_VELOCITY = Vector3.new(5000, 0, 0)
	local NORMAL_OFFSET = CFrame.new(-2, -2, -12)
	local HEAD_VELOCITY = Vector3.new(10000, 0, 0)
	
	local seatsDirty = false
	
	local function refreshSeats()
		table.clear(seats)
		for _, seat in workspace.CarContainer:QueryDescendants('VehicleSeat') do
			table.insert(seats, seat)
		end
	
		seatsDirty = false
	end
	
	local function getSpawners()
		if next(spawners) then
			return spawners
		end
	
		for _, button in workspace.Prison_ITEMS.buttons:GetChildren() do
			if button.Name == 'Car Spawner' then
				local part = button['Car Spawner']
				if part then
					table.insert(spawners, part)
				end
			end
		end
	
		return spawners
	end
	
	local function sortTeams(a, b)
		return (a.Name == 'Inmates' and 1 or 2) < (b.Name == 'Inmates' and 1 or 2)
	end
	
	local function getTeamButtons()
		if next(teamButtons) then
			if teamButtons[1].Parent then
				return teamButtons
			end
	
			table.clear(teamButtons)
		end
	
		local gui = lplr.PlayerGui:FindFirstChild('TeamsFrame', true)
		if gui then
			for _, holder in gui:GetChildren() do
				table.insert(teamButtons, holder)
			end
	
			table.sort(teamButtons, sortTeams)
		end
	
		return teamButtons
	end
	
	local function getPlayerCount()
		local count = 0
		for _, plr in playersService:GetPlayers() do
			local team = plr.Team
			if team == teams.Guards or team == teams.Inmates or team == teams.Criminals then
				count += 1
			end
		end
	
		return count
	end
	
	local function interact(spawner)
		replicatedStorage.Remotes.InteractWithItem:InvokeServer(spawner)
	end
	
	local function sortFling(a, b)
		return (lastFling[a.Player.Name] or 0) < (lastFling[b.Player.Name] or 0)
	end
	
	local function getTarget(seat, now)
		local cached = tempList[seat]
		if cached then
			local humanoid = cached.Humanoid
			if cached.RootPart:IsDescendantOf(workspace) and not (humanoid.Sit and humanoid.SeatPart.Anchored) then
				return cached
			end
		end
	
		if not entitylib.isAlive then
			return
		end
	
		if candidateTime ~= now then
			candidateTime = now
			table.clear(candidateList)
	
			local individual = Mode.Value ~= 'All'
			local enabled = List.ListEnabled
			for _, entity in entitylib.List do
				if isFriend(entity.Player) then continue end
				if not select(2, whitelist:get(entity.Player)) then continue end
				if entity.Player.Team == teams.Neutral then continue end
				if individual and not table.find(enabled, entity.Player.Name) then continue end
				local humanoid = entity.Humanoid
				if humanoid.Sit and humanoid.SeatPart.Anchored then continue end
				if not entity.RootPart:IsDescendantOf(workspace) then continue end
				if (now - entity.SpawnTime) <= 2 then continue end
				table.insert(candidateList, entity)
			end
	
			if #candidateList > 1 then
				table.sort(candidateList, sortFling)
			end
		end
	
		local target = candidateList[1]
		if not target then
			return
		end
	
		table.remove(candidateList, 1)
		lastFling[target.Player.Name] = now
		tempList[seat] = target
		notif('KickExploit', 'Attempted fling: '..target.Player.Name, 5)
		return target
	end
	
	local function clearEntity(entity)
		for seat, target in tempList do
			if target == entity then
				tempList[seat] = nil
			end
		end
	end
	
	local function clearPlayer(plr)
		lastFling[plr.Name] = nil
		for seat, target in tempList do
			if target.Player == plr then
				tempList[seat] = nil
			end
		end
	
		if not table.find(List.List, plr.Name) then return end
	
		List:ChangeValue(plr.Name)
		leftCache[plr.Name] = true
		notif('KickExploit', plr.DisplayName..' left, cached for rejoin.', 5)
	
		if KickExploit.Enabled and Mode.Value == 'Individual' and not next(List.ListEnabled) and not next(leftCache) then
			notif('KickExploit', 'No targets left, disabling.', 5)
			KickExploit:Toggle()
		end
	end
	
	local function restoreCamera()
		if entitylib.isAlive then
			gameCamera.CameraSubject = entitylib.character.Humanoid
			gameCamera.CameraType = Enum.CameraType.Custom
		end
	end
	
	KickExploit = vape.Categories.World:CreateModule({
		Name = 'KickExploit',
		Function = function(callback)
			if callback then
				local reqTimer = os.clock()
				local startTime = os.clock()
				local dir = 0
				local backpack
				local antiFling = vape.Modules.AntiFling
				local serverHop = vape.Modules.ServerHop
	
				KickMode.Object.Visible = Equipment.Enabled
				HeadOffset.Object.Visible = Equipment.Enabled and KickMode.Value == 'Killfling'
	
				if not antiFling.Enabled then
					antiFling:Toggle()
				end
	
				if AutoRejoin.Enabled then
					for _, plr in playersService:GetPlayers() do
						if plr.Team ~= teams.Neutral and table.find(HopList.ListEnabled, plr.Name) then
							repeat
								serverHop:Toggle()
								task.wait(1)
							until not KickExploit.Enabled
	
							return
						end
					end
				end
	
				local countTimer = 0
				local teamTimer = 0
				local targetTimer = 0
				local viewing = false
				local playerCount = AutoRejoin.Enabled and getPlayerCount() or 0
	
				refreshSeats()
				KickExploit:Clean(workspace.CarContainer.DescendantAdded:Connect(function(obj)
					if obj:IsA('VehicleSeat') then
						seatsDirty = true
					end
				end))
				KickExploit:Clean(workspace.CarContainer.DescendantRemoving:Connect(function(obj)
					if obj:IsA('VehicleSeat') then
						seatsDirty = true
					end
				end))
				KickExploit:Clean(entitylib.Events.EntityRemoved:Connect(clearEntity))
				KickExploit:Clean(restoreCamera)
	
				KickExploit:Clean(runService.Heartbeat:Connect(function(dt)
					local now = os.clock()
	
					if seatsDirty then
						refreshSeats()
					end
	
					if lplr.Team == teams.Neutral then
						if (now - teamTimer) > 0.25 then
							teamTimer = now
	
							for _, holder in getTeamButtons() do
								if holder.Button.AutoButtonColor then
									firesignal(holder.Button.MouseButton1Click)
									break
								end
							end
						end
	
						return
					end
	
					if AutoRejoin.Enabled then
						if (now - countTimer) > 0.5 then
							countTimer = now
							playerCount = getPlayerCount()
						end
	
						if ((now - startTime) > TimeLimit.Value * 60 or playerCount <= PlayerLimit.Value) then
							if (now - reqTimer) > 1 then
								serverHop:Toggle()
								reqTimer = now
							end
	
							return
						end
					end
	
					if not entitylib.isAlive then
						return
					end
	
					local root = entitylib.character.RootPart
					local rootPos = root.Position
					local didMove
	
					for _, spawner in getSpawners() do
						local offset = spawner.Position - rootPos
						local mag = offset.Magnitude
	
						if mag < 15 and (didClick[spawner] or 0) < now then
							didClick[spawner] = now + 0.2
							seatsDirty = true
							task.spawn(interact, spawner)
						end
	
						if mag < 50 and spawner.BrickColor == CYAN and not didMove then
							dir = math.clamp(dir + (math.clamp(offset.X, -1, 1) * dt * 24), -12, 14)
							didMove = true
						end
					end
	
					if not didMove then
						dir = math.clamp(dir + (math.clamp(-dir, -1, 1) * dt * 24), -12, 14)
					end
	
					if Movement.Enabled then
						local spawnTime = entitylib.character.SpawnTime
	
						if Equipment.Enabled and (now - spawnTime) < 2 then
							backpack = backpack or lplr:FindFirstChildWhichIsA('Backpack')
							local btool = backpack and backpack:FindFirstChildWhichIsA('Tool') or nil
							local ltool = lplr.Character:FindFirstChildWhichIsA('Tool')
	
							if not (btool or ltool) then
								root.CFrame = EQUIP_POSITION
								return
							elseif btool and not ltool then
								entitylib.character.Humanoid:EquipTool(btool)
							end
						end
	
						root.CFrame = CFrame.new(610 + dir, 98, 2494)
						root.AssemblyLinearVelocity = DRIVE_VELOCITY
					end
	
					if Mode.Value == 'Individual' and not next(List.ListEnabled) and not next(leftCache) then
						notif('KickExploit', 'No targets left, disabling.', 5)
						KickExploit:Toggle()
						return
					end
	
					local owned, flung, waiting, flungHumanoid
					local killfling = Equipment.Enabled and KickMode.Value == 'Killfling'
					for _, seat in seats do
						if isnetworkowner(seat) then
							owned = true
							local target = getTarget(seat, now)
							if not target then continue end
	
							if killfling and target.Humanoid.Health > 0 then
								waiting = true
								continue
							end
	
							flung = true
							flungHumanoid = target.Humanoid
							local useHead = killfling or target.Humanoid.Health <= 0
							local character = target.Character
							local torso = character and (character:FindFirstChild('Torso') or character:FindFirstChild('UpperTorso')) or nil
							local parts = {target.Head, target.RootPart, torso}
							local part
							if useHead and not killfling then
								part = target.Head
							else
								local idx = ((flingRot[target.Player.Name] or 0) % #parts) + 1
								flingRot[target.Player.Name] = idx
								part = parts[idx]
							end
							local targetPos = part.Position
							seat.AssemblyLinearVelocity = useHead and HEAD_VELOCITY or NORMAL_VELOCITY
							seat.CFrame = useHead and CFrame.new(targetPos.X - HeadOffset.Value, targetPos.Y, targetPos.Z) or CFrame.new(targetPos) * NORMAL_OFFSET
							sethiddenproperty(seat, 'PhysicsRepRootPart', part)
							sethiddenproperty(seat, 'PhysicsRepRootRef', InstanceHandle.new(part))
	
							local wheels = seat.Parent.Parent:FindFirstChild('Wheels')
							if wheels then
								wheels:Destroy()
							end
						end
					end
	
					if ViewTarget.Enabled and flungHumanoid then
						gameCamera.CameraSubject = flungHumanoid
						viewing = true
					elseif viewing then
						viewing = false
						restoreCamera()
					end
	
					if not flung and not waiting and next(seats) and (now - targetTimer) > 5 then
						targetTimer = now
						notif('KickExploit', owned and 'No flingable target found.' or 'Vehicle seat is not network owned.', 5, 'warning')
					end
				end))
			else
				table.clear(tempList)
				table.clear(flingRot)
				table.clear(teamButtons)
				restoreCamera()
			end
		end,
		Tooltip = 'aesthetical, just remove collisions on vehicles please, this is the worst.'
	})
	Mode = KickExploit:CreateDropdown({
		Name = 'Mode',
		List = {'All', 'Individual'},
		Function = function(value)
			List.Object.Visible = value ~= 'All'
		end
	})
	List = KickExploit:CreateTextList({
		Name = 'Targets',
		Placeholder = 'Roblox username',
		Player = true,
		Visible = false,
		Darker = true
	})
	Movement = KickExploit:CreateToggle({
		Name = 'Movement',
		Default = true,
		Tooltip = 'Drives a car around the prison while flinging.'
	})
	Equipment = KickExploit:CreateToggle({
		Name = 'Equipment',
		Function = function(callback)
			KickMode.Object.Visible = callback
			HeadOffset.Object.Visible = callback and KickMode.Value == 'Killfling'
		end,
		Tooltip = 'Grab a gun before kicking to kill seated players.'
	})
	KickMode = KickExploit:CreateDropdown({
		Name = 'Kick Mode',
		List = {'Normal', 'Killfling'},
		Function = function(val)
			HeadOffset.Object.Visible = val == 'Killfling'
		end,
		Visible = false,
		Darker = true
	})
	HeadOffset = KickExploit:CreateSlider({
		Name = 'Head Offset',
		Min = 0,
		Max = 12,
		Default = 1,
		Visible = false,
		Darker = true,
		Suffix = function(value)
			return value == 1 and 'stud' or 'studs'
		end
	})
	DebugNet = KickExploit:CreateToggle({
		Name = 'DebugNetworkOwner',
		Function = function(callback)
			if callback then
				local module = vape.Modules.ShowNetworkOwner
				local KickExploit = vape.Modules.KickExploit
				if KickExploit and KickExploit.Enabled and not module.Enabled then
					module:Toggle()
				end
	
				notif('KickExploit', 'Debugging network owners', 5)
			end
		end,
		Tooltip = 'Enable debug network output.'
	})
	
	ViewTarget = KickExploit:CreateToggle({
		Name = 'ViewTarget',
		Function = function(callback)
			if not callback then
				restoreCamera()
			end
		end,
		Tooltip = 'Automatically view the target being flung.'
	})
	AutoRejoin = KickExploit:CreateToggle({
		Name = 'AutoRejoin',
		Function = function(callback)
			PlayerLimit.Object.Visible = callback
			TimeLimit.Object.Visible = callback
			HopList.Object.Visible = callback
		end,
		Tooltip = 'Automatically server hop after certain conditions are met.'
	})
	PlayerLimit = KickExploit:CreateSlider({
		Name = 'Player Limit',
		Min = 1,
		Max = 24,
		Default = 10,
		Visible = false,
		Darker = true,
		Suffix = function(value)
			return value == 1 and 'player' or 'players'
		end
	})
	TimeLimit = KickExploit:CreateSlider({
		Name = 'Time Limit',
		Min = 1,
		Max = 20,
		Default = 6,
		Visible = false,
		Darker = true,
		Suffix = function(value)
			return value == 1 and 'minute' or 'minutes'
		end
	})
	HopList = KickExploit:CreateTextList({
		Name = 'Hop List',
		Placeholder = 'Roblox username',
		Tooltip = 'Automatically hop if the player is spawned in and in the server, good for multiboxing.',
		Player = true,
		Visible = false,
		Darker = true
	})
	vape:Clean(playersService.PlayerRemoving:Connect(clearPlayer))
	
	local function rejoinPlayer(plr)
		if not leftCache[plr.Name] then return end
	
		leftCache[plr.Name] = nil
		if not table.find(List.List, plr.Name) then
			List:ChangeValue(plr.Name)
		end
		notif('KickExploit', plr.DisplayName..' rejoined, re-added to targets.', 5)
	end
	
	vape:Clean(playersService.PlayerAdded:Connect(rejoinPlayer))
end)

run(function()
	local AutoArmor
	local pickups = {}
	
	AutoArmor = vape.Categories.Inventory:CreateModule({
		Name = 'AutoArmor',
		Function = function(callback)
			if callback then
				pickups = workspace.Prison_ITEMS.clothes:GetChildren()
	
				AutoArmor:Clean(workspace.Prison_ITEMS.clothes.ChildAdded:Connect(function(pickup)
					table.insert(pickups, pickup)
				end))
	
				AutoArmor:Clean(workspace.Prison_ITEMS.clothes.ChildRemoved:Connect(function(pickup)
					local index = table.find(pickups, pickup)
					if index then
						table.remove(pickups, index)
					end
				end))
	
				repeat
					if entitylib.isAlive and entitylib.character.Humanoid.MaxHealth <= 100 then
						local localpos = entitylib.character.RootPart.Position
	
						for _, pickup in pickups do
							if (pickup:GetPivot().Position - localpos).Magnitude < 10 and gamepasses[pickup:GetAttribute('RequiredGamepass')] and AutoArmor.Enabled then
								if pickup.Name == 'Light Vest' and gamepasses[lplr.Team == teams.Criminals and 'Mafia' or 'Riot Police'] then
									continue
								end
	
								replicatedStorage.Remotes.InteractWithItem:InvokeServer(pickup:FindFirstChildWhichIsA('BasePart'))
							end
						end
					end
	
					task.wait(0.05)
				until not AutoArmor.Enabled
			else
				table.clear(pickups)
			end
		end,
		Tooltip = 'Automatically equip armor from the wall.'
	})
end)

run(function()
	local AutoHeal
	local healItems = {
		Breakfast = true,
		Lunch = true,
		Dinner = true
	}
	
	AutoHeal = vape.Categories.Inventory:CreateModule({
		Name = 'AutoHeal',
		Function = function(callback)
			if callback then
				repeat
					local entity = entitylib.isAlive and entitylib.character
					if entity and entity.Humanoid.Health <= 85 then
						local healTool
						local backpack = lplr:FindFirstChildWhichIsA('Backpack')
						if backpack then
							for _, tool in backpack:GetChildren() do
								if healItems[tool.Name] then
									healTool = tool
								end
							end
	
							if healTool and (os.clock() - (healTool:GetAttribute('Client_LastConsumedAt') or 0)) >= 3 then
								local lastEquip = entity.Character:FindFirstChildWhichIsA('Tool')
								entity.Humanoid:EquipTool(healTool)
								healTool:SetAttribute('Quantity', healTool:GetAttribute('Quantity') - 1)
								healTool:SetAttribute('Client_LastConsumedAt', os.clock())
								notif('AutoHeal', 'Quantity: '..healTool:GetAttribute('Quantity'), 3)
								replicatedStorage.Remotes.EatFood:FireServer()
	
								if lastEquip then
									entity.Humanoid:EquipTool(lastEquip)
								else
									entity.Humanoid:UnequipTools()
								end
							end
						end
					end
	
					task.wait(0.05)
				until not AutoHeal.Enabled
			end
		end,
		Tooltip = 'Automatically heal damage with consumables.'
	})
end)

run(function()
	local AutoHotbar
	local SortList = {}
	
	local function DoSorting()
		table.sort(pl.SwitchTable, function(a, b)
			return (SortList[a.Tool.name] or 999 + a.Slot) < (SortList[b.Tool.name] or 999 + b.Slot)
		end)
	
		task.spawn(pl.SwitchUpdate)
	end
	
	local function EntityAdded()
		local backpack = lplr:FindFirstChildWhichIsA('Backpack')
		if backpack then
			AutoHotbar:Clean(backpack.ChildAdded:Connect(function(tool)
				if SortList[tool.Name] then
					task.defer(DoSorting)
				end
			end))
		end
	
		DoSorting()
	end
	
	AutoHotbar = vape.Categories.Inventory:CreateModule({
		Name = 'AutoHotbar',
		Function = function(callback)
			if callback then
				AutoHotbar:Clean(entitylib.Events.LocalAdded:Connect(EntityAdded))
				if entitylib.isAlive then
					task.spawn(EntityAdded)
				end
			end
		end,
		Tooltip = 'Automatically sort hotbar entries'
	})
	AutoHotbar:CreateTextList({
		Name = 'Sort Order',
		Default = {'1/AK-47', '1/MP5', '1/M4A1', '2/Remington 870', '2/M700', '3/M9', '3/Revolver', '4/Taser'},
		Function = function(list)
			table.clear(SortList)
			for _, entry in list do
				local data = entry:split('/')
				local priority = tonumber(data[1]) or 999
				SortList[data[2] or ''] = priority
			end
		end
	})
end)

run(function()
	local AutoPickup
	local items = {}
	local PickupList = {}
	
	local function AddPickup(pickup)
		if pickup:IsA('Model') and pickup.Name ~= 'Model' and pickup:GetAttribute('ToolName') then
			table.insert(items, {
				pickup,
				pickup.Name == 'TouchGiver'
			})
		end
	end
	
	local function hasTool(name, backpack)
		local tool = lplr.Character:FindFirstChildWhichIsA('Tool')
		return backpack:FindFirstChild(name) or tool and tool.Name == name and tool
	end
	
	AutoPickup = vape.Categories.Inventory:CreateModule({
		Name = 'AutoPickup',
		Function = function(callback)
			if callback then
				for _, pickup in workspace:GetChildren() do
					task.spawn(AddPickup, pickup)
				end
	
				for _, pickup in workspace:QueryDescendants('Model > .TouchGiver') do
					task.spawn(AddPickup, pickup)
				end
	
				AutoPickup:Clean(workspace.ChildAdded:Connect(AddPickup))
				AutoPickup:Clean(workspace.ChildRemoved:Connect(function(pickup)
					for index, data in items do
						if data[1] == pickup then
							table.remove(items, index)
							break
						end
					end
				end))
	
				repeat
					if entitylib.isAlive then
						local localpos = entitylib.character.RootPart.Position
						local backpack = lplr:FindFirstChildWhichIsA('Backpack')
	
						if backpack then
							for _, pickup in items do
								if pickup[1].PrimaryPart and (pickup[1].PrimaryPart.Position - localpos).Magnitude < 12 then
									local tool = pickup[1]:GetAttribute('ToolName')
									if hasTool(tool, backpack) then
										continue
									end
	
									if pickup[2] and not table.find(PickupList[lplr.Team == teams.Guards and 'Guard' or (lplr.Team == teams.Criminals and 'Criminal' or 'Prisoner')].ListEnabled, tool) then
										continue
									end
	
									replicatedStorage.Remotes.GiverPressed:FireServer(pickup[1])
								end
							end
						end
					end
	
					task.wait(0.05)
				until not AutoPickup.Enabled
			else
				table.clear(items)
			end
		end,
		Tooltip = 'Automatically grab item pickups'
	})
	
	for _, team in {'Prisoner', 'Guard', 'Criminal'} do
		PickupList[team] = AutoPickup:CreateTextList({
			Name = team,
			Default = {team == 'Criminal' and 'AK-47' or 'MP5', 'Remington 870'},
			Placeholder = 'item'
		})
	end
end)

run(function()
	local BulletTracers
	local Material
	local Color
	local Lifetime
	local Fade
	local DrawingToggle
	local drawingobjs = {}
	
	BulletTracers = vape.Legit:CreateModule({
		Name = 'BulletTracers',
		Function = function(callback)
			if callback then
				TracerHook:Add('BulletTracers', function(...)
					local origin, dir = ...
					if vtool then
						origin = vtool.Muzzle.Position
					end
	
					local velocity = CFrame.lookAt(origin, dir).LookVector * 1000
					if DrawingToggle.Enabled then
						local obj = Drawing.new('Line')
						obj.Thickness = 2
						obj.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
						drawingobjs[obj] = {origin, origin + velocity, os.clock()}
						task.delay(Lifetime.Value, function()
							drawingobjs[obj] = nil
							obj.Visible = false
							obj:Remove()
						end)
					else
						local obj = Instance.new('Part')
						obj.Size = Vector3.new(0.1, 0.1, velocity.Magnitude)
						obj.CFrame = CFrame.lookAt(origin + (velocity / 2), origin + velocity)
						obj.CanCollide = false
						obj.CanQuery = false
						obj.Anchored = true
						obj.Material = Enum.Material[Material.Value]
						obj.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
						obj.Transparency = 1 - Color.Opacity
						obj.Parent = workspace
						if Fade.Enabled then
							local tween = tweenService:Create(obj, TweenInfo.new(Lifetime.Value), {
								Transparency = 1
							})
							tween.Completed:Connect(function()
								tween:Destroy()
							end)
							tween:Play()
						end
	
						task.delay(Lifetime.Value, obj.Destroy, obj)
					end
	
					return true
				end, 1)
	
				if DrawingToggle.Enabled then
					BulletTracers:Clean(runService.RenderStepped:Connect(function()
						local clock = os.clock()
						local lifetime = Lifetime.Value
	
						for obj, data in drawingobjs do
							local from, vis = gameCamera:WorldToViewportPoint(data[1])
							local to, vis2 = gameCamera:WorldToViewportPoint(data[2])
							if vis and vis2 then
								obj.Visible = true
								obj.From = Vector2.new(from.X, from.Y)
								obj.To = Vector2.new(to.X, to.Y)
								if Fade.Enabled then
									obj.Transparency = Color.Opacity * (1 - math.clamp((clock - data[3]) / lifetime, 0, 1))
								end
							else
								obj.Visible = false
							end
						end
					end))
				end
			else
				TracerHook:Remove('BulletTracers')
			end
		end,
		Tooltip = 'Allow you to customize bullet tracers.'
	})
	local materials = {'SmoothPlastic'}
	for _, v in Enum.Material:GetEnumItems() do
		if v.Name ~= 'SmoothPlastic' then
			table.insert(materials, v.Name)
		end
	end
	Material = BulletTracers:CreateDropdown({
		Name = 'Material',
		List = materials
	})
	Color = BulletTracers:CreateColorSlider({
		Name = 'Tracer Color',
		DefaultOpacity = 0.5
	})
	Lifetime = BulletTracers:CreateSlider({
		Name = 'Lifetime',
		Min = 0,
		Max = 0.5,
		Default = 0.2,
		Decimal = 10
	})
	Fade = BulletTracers:CreateToggle({
		Name = 'Fade',
		Default = true
	})
	DrawingToggle = BulletTracers:CreateToggle({
		Name = 'Drawing',
		Function = function()
			if BulletTracers.Enabled then
				BulletTracers:Toggle()
				BulletTracers:Toggle()
			end
		end
	})
end)

run(function()
	local Crosshair
	local Image
	local old
	
	Crosshair = vape.Legit:CreateModule({
		Name = 'Crosshair',
		Function = function(callback)
			if callback then
				debug.setconstant(oldequip or pl.Equip, 30, Image.Value:find('rbxasset') and Image.Value or isfile(Image.Value) and getcustomasset(Image.Value) or '')
			else
				debug.setconstant(oldequip or pl.Equip, 30, 'rbxassetid://98794608762931')
			end
		end,
		Tooltip = 'Change the crosshair icon'
	})
	Image = Crosshair:CreateTextBox({
		Name = 'Image',
		Placeholder = 'assetid',
		Function = function()
			if Crosshair.Enabled then
				debug.setconstant(oldequip or pl.Equip, 30, Image.Value:find('rbxasset') and Image.Value or isfile(Image.Value) and getcustomasset(Image.Value) or '')
			end
		end
	})
end)

run(function()
	local DamageIndicator
	local FontOption
	local ColorV
	local Size
	local tent, lent
	local thealth, ttimer = 0, 0
	local indi, indipart, indithread
	
	-- completely skidded from RIVALS
	local function renderStepForLoop(startVal, endVal, increment, callback)
		while true do
			if endVal >= startVal then
				if callback(startVal) then
					return
				else
					local diff = tick()
					runService.RenderStepped:Wait()
					startVal = startVal + increment * (tick() - diff) * 60
				end
			else
				callback(endVal)
				return
			end
		end
	end
	
	local function createIndicator(damage, pos)
		if indithread then
			task.cancel(indithread)
			indi.Text = math.ceil(tonumber(indi.Text) + damage)
			indipart.Position = pos
		else
			indipart = Instance.new('Part')
			indipart.Size = Vector3.zero
			indipart.Position = pos
			indipart.CanCollide = false
			indipart.CanQuery = false
			indipart.Anchored = true
			indipart.Parent = workspace
			local billboard = Instance.new('BillboardGui')
			billboard.Adornee = indipart
			billboard.Size = UDim2.new(15, 250, 15, 250)
			billboard.AlwaysOnTop = true
			billboard.Parent = indipart
			indi = Instance.new('TextLabel')
			indi.BackgroundTransparency = 1
			indi.TextStrokeTransparency = 0
			indi.Size = UDim2.fromScale(1, 0.075)
			indi.Position = UDim2.fromScale(0.5, 0.5)
			indi.AnchorPoint = Vector2.new(0.5, 0.5)
			indi.Text = math.ceil(damage)
			indi.TextColor3 = Color3.fromHSV(ColorV.Hue, ColorV.Sat, ColorV.Value)
			indi.TextScaled = true
			indi.Font = Enum.Font[FontOption.Value]
			indi.Parent = billboard
		end
	
		if indithread then
			task.cancel(indithread)
			indithread = nil
		end
	
		-- completely skidded from RIVALS
		indithread = task.spawn(function()
			local sign = math.sign(math.random() - 0.5)
			renderStepForLoop(0, 100, 3, function(value)
				local percent = value / 100
				local val0 = tweenService:GetValue(percent, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
				local val1 = tweenService:GetValue(percent, Enum.EasingStyle.Back, Enum.EasingDirection.In)
				local scale = 1 - 0.5 * val1
				indi.Position = UDim2.new(0.5 + 0.125 * val0 * sign, 0, 0.5 + 0.125 * val1, 0)
				indi.Size = UDim2.new(1 * scale, 0, 0.075 * scale * (v197 and 1 or 0.75), 0)
				indi.Rotation = percent ^ 4 * 260 * sign
			end)
	
			indipart:Destroy()
			indipart = nil
			indithread = nil
		end)
	end
	
	DamageIndicator = vape.Legit:CreateModule({
		Name = 'DamageIndicator',
		Function = function(callback)
			if callback then
				TracerHook:Add('DamageIndicator', function(...)
					local part = debug.getstack(4, 17)
					if typeof(part) == 'Instance' then
						for _, v in entitylib.List do
							if part:IsDescendantOf(v.Character) and entitylib.isVulnerable(v, true) then
								if ttimer <= os.clock() or v ~= tent then
									thealth = v.Health
								end
	
								tent = v
								ttimer = os.clock() + 0.5
								break
							end
						end
					end
				end)
	
				DamageIndicator:Clean(entitylib.Events.EntityUpdated:Connect(function(ent)
					if ent == tent and ttimer > os.clock() then
						if ent ~= lent then
							if indi then
								indi.Text = '0'
							end
	
							lent = ent
						end
	
						if thealth > ent.Health then
							createIndicator(thealth - ent.Health, ent.Head.Position + Vector3.new(0, 2, 0))
							thealth = ent.Health
						end
					end
				end))
			else
				TracerHook:Remove('DamageIndicator')
			end
		end,
		Tooltip = 'Add custom damage indicators for gun damage.'
	})
	local fontitems = {'GothamBlack'}
	for _, v in Enum.Font:GetEnumItems() do
		if v.Name ~= 'GothamBlack' then
			table.insert(fontitems, v.Name)
		end
	end
	FontOption = DamageIndicator:CreateDropdown({
		Name = 'Font',
		List = fontitems,
		Function = function(val)
			if indi then
				indi.Font = Enum.Font[val]
			end
		end
	})
	ColorV = DamageIndicator:CreateColorSlider({
		Name = 'Color',
		DefaultHue = 0,
		Function = function(hue, sat, val)
			if indi then
				indi.Color = Color3.fromHSV(hue, sat, val)
			end
		end
	})
end)

run(function()
	local HitSound
	local Value
	local Volume
	local PitchShift
	local old, sounds = nil, {}
	
	HitSound = vape.Legit:CreateModule({
		Name = 'HitSound',
		Function = function(callback)
			if callback then
				local played
				TracerHook:Add('HitSound', function(...)
					local part = debug.getstack(4, 17)
					if typeof(part) == 'Instance' then
						for _, v in entitylib.List do
							if part:IsDescendantOf(v.Character) and entitylib.isVulnerable(v, true) then
								if #sounds > 0 and not played then
									local sound = Instance.new('Sound')
									sound.SoundId = sounds[math.random(1, #sounds)]
									sound.PlayOnRemove = true
									sound.PlaybackSpeed = PitchShift.Enabled and 1 + ((0.5 - math.random()) / 10) or 1
									sound.Volume = Volume.Value
									sound.Parent = workspace
									sound:Destroy()
	
									played = task.defer(function()
										played = nil
									end)
								end
	
								break
							end
						end
					end
				end)
			else
				TracerHook:Remove('HitSound')
			end
		end,
		Tooltip = 'Custom hit sound'
	})
	Value = HitSound:CreateTextList({
		Name = 'Sounds',
		Placeholder = 'sound id (roblox or file path)',
		Function = function(list)
			table.clear(sounds)
			for index, sound in list or {} do
				sounds[index] = sound:find('rbxasset') and sound or isfile(sound) and getcustomasset(sound) or nil
			end
		end
	})
	Volume = HitSound:CreateSlider({
		Name = 'Volume',
		Min = 0,
		Max = 2,
		Default = 1,
		Decimal = 10
	})
	PitchShift = HitSound:CreateToggle({
		Name = 'Pitch Shift'
	})
end)

run(function()
	local KillSound
	local Value
	local Volume
	local PitchShift
	local old, sounds = nil, {}
	
	KillSound = vape.Legit:CreateModule({
		Name = 'KillSound',
		Function = function(callback)
			if callback then
				KillSound:Clean(vapeEvents.PlayerKill.Event:Connect(function(plr)
					if plr == lplr.Name and #sounds > 0 then
						local sound = Instance.new('Sound')
						sound.SoundId = sounds[math.random(1, #sounds)]
						sound.PlayOnRemove = true
						sound.PlaybackSpeed = PitchShift.Enabled and 1 + ((0.5 - math.random()) / 10) or 1
						sound.Volume = Volume.Value
						sound.Parent = workspace
						sound:Destroy()
					end
				end))
			end
		end,
		Tooltip = 'Custom kill sound'
	})
	Value = KillSound:CreateTextList({
		Name = 'Sounds',
		Placeholder = 'sound id (roblox or file path)',
		Function = function(list)
			table.clear(sounds)
			for index, sound in list or {} do
				sounds[index] = sound:find('rbxasset') and sound or isfile(sound) and getcustomasset(sound) or nil
			end
		end
	})
	Volume = KillSound:CreateSlider({
		Name = 'Volume',
		Min = 0,
		Max = 2,
		Default = 1,
		Decimal = 10
	})
	PitchShift = KillSound:CreateToggle({
		Name = 'Pitch Shift'
	})
end)

run(function()
	local Viewmodel
	local Depth
	local Horizontal
	local Vertical
	local Sway
	local ForceField
	local ColorSl
	local handle
	local old
	local moveSpring = Spring.new()
	local aimSpring = Spring.new({Speed = 15})
	
	local function ToolAdded(tool)
		if tool and tool:IsA('Tool') then
			if old then
				for _, inst in old:QueryDescendants('BasePart, Texture, Decal') do
					inst.LocalTransparencyModifier = 0
				end
			end
	
			if vtool then
				vtool:Destroy()
			end
	
			old = tool
			vtool = tool:Clone()
			handle = vtool:FindFirstChild('Handle')
			vtool.Parent = gameCamera
	
			for _, part in vtool:QueryDescendants('BasePart') do
				part.Material = ForceField.Enabled and Enum.Material.ForceField or part.Material
				part.Color = ForceField.Enabled and Color3.fromHSV(ColorSl.Hue, ColorSl.Sat, ColorSl.Value) or part.Color
			end
	
			for _, inst in old:QueryDescendants('BasePart, Texture, Decal') do
				inst.LocalTransparencyModifier = 1
			end
		end
	end
	
	local function EntityAdded(entity)
		if vtool then
			vtool:Destroy()
			vtool = nil
			handle = nil
		end
	
		Viewmodel:Clean(entity.Character.ChildAdded:Connect(ToolAdded))
		Viewmodel:Clean(entity.Character.ChildRemoved:Connect(function(tool)
			if tool == old then
				if vtool then
					vtool:Destroy()
					vtool = nil
				end
	
				for _, inst in old:QueryDescendants('BasePart, Texture, Decal') do
					inst.LocalTransparencyModifier = 0
				end
	
				old = nil
			end
		end))
	
		ToolAdded(entity.Character:FindFirstChildWhichIsA('Tool'))
	end
	
	Viewmodel = vape.Legit:CreateModule({
		Name = 'Viewmodel',
		Function = function(callback)
			if callback then
				TracerHook:Add('Viewmodel', function(...)
					shootTimer = os.clock() + 0.3
				end, 0)
	
				Viewmodel:Clean(entitylib.Events.LocalAdded:Connect(EntityAdded))
				if entitylib.isAlive then
					task.spawn(EntityAdded, entitylib.character)
				end
	
				Viewmodel:Clean(runService.RenderStepped:Connect(function(dt)
					if handle then
						local camCF = gameCamera.CFrame
						local clock = os.clock()
						local root = entitylib.isAlive and entitylib.character.RootPart
						moveSpring.Target = root and root.AssemblyLinearVelocity * 0.005 or Vector3.zero
	
						if Sway.Enabled then
							local swayTime = tick()
	
							if moveSpring.Target.Magnitude > 0.1 then
								moveSpring.Target += (camCF * CFrame.new(math.sin(swayTime * 10) * 0.06, 0, 0)).Position - camCF.Position
							else
								moveSpring.Target += (camCF * CFrame.new(0, math.sin(swayTime) * 0.04, 0)).Position - camCF.Position
							end
						end
	
						local cf = (camCF * CFrame.new(Horizontal.Value, Vertical.Value, -Depth.Value)) + moveSpring:Update(dt)
						local recoil = math.max(shootTimer - clock, 0)
						aimSpring.Target = aimTimer > clock and CFrame.lookAt(cf.Position, aimVec).LookVector or camCF.LookVector
						handle.CFrame = CFrame.lookAlong(cf.Position, aimSpring:Update(dt)) * (CFrame.Angles(math.rad(recoil * 10), 0, 0) * CFrame.new(0, 0, recoil))
						handle.AssemblyLinearVelocity = Vector3.zero
					end
				end))
			else
				TracerHook:Remove('Viewmodel')
	
				if old then
					for _, inst in old:QueryDescendants('BasePart, Texture, Decal') do
						inst.LocalTransparencyModifier = 0
					end
	
					old = nil
				end
	
				if vtool then
					vtool:Destroy()
					vtool = nil
					handle = nil
				end
			end
		end,
		Tooltip = 'Custom viewmodel for guns'
	})
	Depth = Viewmodel:CreateSlider({
		Name = 'Depth',
		Min = 0,
		Max = 3,
		Default = 3,
		Decimal = 10
	})
	Horizontal = Viewmodel:CreateSlider({
		Name = 'Horizontal',
		Min = 0,
		Max = 2,
		Default = 2,
		Decimal = 10
	})
	Vertical = Viewmodel:CreateSlider({
		Name = 'Vertical',
		Min = -1.5,
		Max = 2,
		Default = -1.5,
		Decimal = 10
	})
	Sway = Viewmodel:CreateToggle({
		Name = 'Sway Effect',
		Default = true
	})
	ForceField = Viewmodel:CreateToggle({
		Name = 'ForceField Effect',
		Function = function(callback)
			ColorSl.Object.Visible = callback
			if callback and Viewmodel.Enabled then
				Viewmodel:Toggle()
				Viewmodel:Toggle()
			end
		end
	})
	ColorSl = Viewmodel:CreateColorSlider({
		Name = 'Color',
		Function = function(hue, sat, val)
			if vtool then
				for _, part in vtool:QueryDescendants('BasePart') do
					part.Color = Color3.fromHSV(hue, sat, val)
				end
			end
		end,
		Visible = false
	})
end)