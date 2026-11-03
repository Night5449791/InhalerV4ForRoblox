local KillNotifications
local height

local MAX_STACK = 4
local LIFETIME = 2.5
local FADE = 0.3
local FADE_INFO = TweenInfo.new(FADE)
local ENTRY_W, ENTRY_H, ENTRY_STEP = 460, 22, 25
local offset
local positions = {}

local feed, stack
local byDisp = {}
local hexCache, healthCache = {}, {}

local function hex(color)
	local r = math.floor(color.R * 255 + 0.5)
	local g = math.floor(color.G * 255 + 0.5)
	local b = math.floor(color.B * 255 + 0.5)
	local key = r * 65536 + g * 256 + b
	local value = hexCache[key]
	if not value then
		value = string.format('#%02x%02x%02x', r, g, b)
		hexCache[key] = value
	end
	return value
end

local function healthHex(health)
	local value = healthCache[health]
	if not value then
		value = hex(Color3.fromHSV(math.clamp(health / 100, 0, 1) / 2.5, 0.89, 0.75))
		healthCache[health] = value
	end
	return value
end

for _, player in playersService:GetPlayers() do
	byDisp[player.DisplayName] = byDisp[player.DisplayName] or player
end
vape:Clean(playersService.PlayerAdded:Connect(function(player)
	byDisp[player.DisplayName] = byDisp[player.DisplayName] or player
end))
vape:Clean(playersService.PlayerRemoving:Connect(function(player)
	if player == lplr then
		table.clear(byDisp)
	elseif byDisp[player.DisplayName] == player then
		byDisp[player.DisplayName] = nil
		for _, other in playersService:GetPlayers() do
			if other ~= player and other.DisplayName == player.DisplayName then
				byDisp[player.DisplayName] = other
				break
			end
		end
	end
end))

KillNotifications = vape.Categories.Render:CreateModule({
	Name = 'KillNotifications',
	Function = function(callback)
		if callback then
			stack = {}
			for i = 1, MAX_STACK do
				positions[i] = UDim2.new(0.5, 0, 1, -offset - (i - 1) * ENTRY_STEP)
			end

			feed = Instance.new('ScreenGui')
			feed.Name = 'KillNotifications'
			feed.ResetOnSpawn = false
			feed.IgnoreGuiInset = true
			feed.DisplayOrder = 10
			feed.Parent = coreGui

			local prototype = Instance.new('TextLabel')
			prototype.Name = 'Killfeed'
			prototype.AnchorPoint = Vector2.new(0.5, 1)
			prototype.BackgroundTransparency = 1
			prototype.BorderSizePixel = 0
			prototype.Font = Enum.Font.GothamBold
			prototype.RichText = true
			prototype.TextColor3 = Color3.new(1, 1, 1)
			prototype.TextSize = 15
			prototype.TextStrokeColor3 = Color3.new()
			prototype.TextStrokeTransparency = 0.7
			prototype.TextXAlignment = Enum.TextXAlignment.Center
			prototype.Size = UDim2.new(0, ENTRY_W, 0, ENTRY_H)

			local myName = lplr.Name
			local myDisp = lplr.DisplayName

			KillNotifications:Clean(replicatedStorage.Killfeed.ChildAdded:Connect(function(obj)
				local name = obj.Name

				local killedAt = name:find('killed ', 1, true)
				if not killedAt then return end

				local killerAt = name:find('@', 1, true)
				local killerClose = killerAt and name:find(')', killerAt, true)
				if not (killerAt and killerClose and killerClose < killedAt) then return end
				local killerName = name:sub(killerAt + 1, killerClose - 1)

				local victimAt = name:find('@', killedAt, true)
				local victimClose = victimAt and name:find(')', victimAt, true)
				local victimName, victimEnd
				if victimAt and victimClose then
					victimName = name:sub(victimAt + 1, victimClose - 1)
					victimEnd = victimClose
				else
					local vStart = killedAt + 7
					local _, _, withAt = name:find('.*() with ', vStart)
					victimName = withAt and name:sub(vStart, withAt - 1) or name:sub(vStart)
					victimName = victimName:match('^%s*(.-)%s*$')
					victimEnd = withAt
				end

				local mine = (victimName == myName or victimName == myDisp) and killerName ~= myName

				local kplr = playersService:FindFirstChild(killerName) or byDisp[killerName]
				local vplr = mine and lplr or playersService:FindFirstChild(victimName) or byDisp[victimName]

				local kDisp = name:sub(1, killerAt - 1)
				kDisp = kDisp:match('^(.-)%s*%(%s*$') or kDisp:match('^%s*(.-)%s*$')
				if kDisp == '' then kDisp = killerName end

				local vDisp
				if mine then
					vDisp = myDisp
				elseif victimAt then
					vDisp = name:sub(killedAt + 7, victimAt - 1)
					vDisp = vDisp:match('^(.-)%s*%(%s*$') or vDisp:match('^%s*(.-)%s*$')
					if vDisp == '' then vDisp = victimName end
				else
					vDisp = victimName
				end

				local killerTeam = kplr and kplr.TeamColor
				local victimTeam = vplr and vplr.TeamColor
				local kHex = killerTeam and hex(killerTeam.Color)
				local vHex = victimTeam and hex(victimTeam.Color)

				local kHealth, kHealthHex
				if kplr then
					local character = kplr.Character
					local humanoid = character and character:FindFirstChildOfClass('Humanoid')
					if humanoid and humanoid.Health > 0 and humanoid.MaxHealth > 0 then
						kHealth = math.floor(humanoid.Health / humanoid.MaxHealth * 100 + 0.5)
						kHealthHex = healthHex(kHealth)
					end
				end

				local weapon
				if victimEnd then
					local wstart = name:find('with ', victimEnd, true)
					if wstart then
						weapon = name:match('with%s+(.-)%s*%(', wstart) or name:match('with%s+(.-)%s*$', wstart)
					end
				end

				local entry = prototype:Clone()
				entry.Text = (kHex and '<font color="'..kHex..'">'..kDisp..'</font>' or kDisp)
					..(kHealth and ' [<font color="'..kHealthHex..'">'..kHealth..'%</font>]' or '')..' killed '
					..(vHex and '<font color="'..vHex..'">'..vDisp..'</font>' or vDisp)
					..(weapon and ' ['..weapon..']' or '')
				entry.TextTransparency = 1
				entry.TextStrokeTransparency = 1
				entry.Parent = feed
				tweenService:Create(entry, FADE_INFO, {
					TextTransparency = 0,
					TextStrokeTransparency = 0.7
				}):Play()

				table.insert(stack, 1, entry)
				if #stack > MAX_STACK then
					stack[#stack]:Destroy()
					table.remove(stack)
				end
				for i = 1, #stack do
					stack[i].Position = positions[i]
				end

				task.delay(LIFETIME - FADE, function()
					local idx = table.find(stack, entry)
					if not idx then return end

					tweenService:Create(entry, FADE_INFO, {
						TextTransparency = 1,
						TextStrokeTransparency = 1
					}):Play()
					task.wait(FADE)

					idx = table.find(stack, entry)
					if not idx then return end
					table.remove(stack, idx)
					entry:Destroy()
					for i = idx, #stack do
						stack[i].Position = positions[i]
					end
				end)
			end))

			KillNotifications:Clean(function()
				if feed then
					feed:Destroy()
					feed = nil
				end
				table.clear(stack)
			end)
		end
	end,
	Tooltip = 'Shows a killfeed of who killed who at the bottom of the screen.'
})

height = KillNotifications:CreateSlider({
	Name = 'Height',
	Min = 0,
	Max = 300,
	Default = 100,
	Suffix = 'px',
	Tooltip = 'killfeed gui y axis',
	Function = function(value)
		offset = value
		for i = 1, MAX_STACK do
			positions[i] = UDim2.new(0.5, 0, 1, -value - (i - 1) * ENTRY_STEP)
		end
	end
})
offset = height.Value