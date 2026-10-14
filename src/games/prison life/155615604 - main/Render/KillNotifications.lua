local KillNotifications
local KNHeight

local MAX_STACK = 4
local LIFETIME = 2.5
local ENTRY_W = 460
local ENTRY_H = 22
local ENTRY_GAP = 3
local ENTRY_STEP = ENTRY_H + ENTRY_GAP
local BASE_OFFSET

local killfeedGui, stack

-- the listener runs for every killfeed line in the server, so the two colour
-- lookups are memoized: team colours repeat endlessly and health only ever
-- lands on 0-100, which keeps fromHSV/string.format off the hot path
local KNHexCache = {}
local function knHex(color)
	local r = math.floor(color.R * 255 + 0.5)
	local g = math.floor(color.G * 255 + 0.5)
	local b = math.floor(color.B * 255 + 0.5)
	local key = r * 65536 + g * 256 + b
	local hex = KNHexCache[key]
	if not hex then
		hex = string.format('#%02x%02x%02x', r, g, b)
		KNHexCache[key] = hex
	end
	return hex
end

local KNHealthCache = {}
local function knHealthHex(health)
	local hex = KNHealthCache[health]
	if not hex then
		hex = knHex(Color3.fromHSV(math.clamp(health / 100, 0, 1) / 2.5, 0.89, 0.75))
		KNHealthCache[health] = hex
	end
	return hex
end

KillNotifications = vape.Categories.Render:CreateModule({
	Name = 'KillNotifications',
	Function = function(callback)
		if callback then
			stack = {}

			killfeedGui = Instance.new('ScreenGui')
			killfeedGui.Name = 'KillNotifications'
			killfeedGui.ResetOnSpawn = false
			killfeedGui.IgnoreGuiInset = true
			killfeedGui.DisplayOrder = 10
			killfeedGui.Parent = coreGui

			-- every kill clones this instead of writing a dozen properties, so the
			-- per-kill instance cost is one Clone plus the Text
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

			-- listen to the killfeed directly instead of relying on the
			-- vapeEvents.PlayerKill BindableEvent, so a missed delivery (cross-file
			-- BindableEvent plumbing) can't silently drop the notification. The
			-- parsing matches base.lua / upstream, which drives the kills/deaths
			-- counters off the same ChildAdded signal.
			KillNotifications:Clean(replicatedStorage.Killfeed.ChildAdded:Connect(function(obj)
				-- "DisplayName (@UserName)  killed DisplayName2 (@UserName2) with Weapon"
				local name = obj.Name

				local killedAt = name:find('killed ')
				if not killedAt then return end

				-- killer UserName, from the (@...) before "killed"
				local killerAt = name:find('@')
				local killerClose = killerAt and name:find(')', killerAt)
				if not (killerAt and killerClose and killerClose < killedAt) then return end
				local killerName = name:sub(killerAt + 1, killerClose - 1)

				-- victim UserName, from the (@...) after "killed", else the first token
				local victimAt = name:find('@', killedAt)
				local victimClose = victimAt and name:find(')', victimAt)
				local victimName, victimEnd
				if victimAt and victimClose then
					victimName = name:sub(victimAt + 1, victimClose - 1)
					victimEnd = victimClose
				else
					local vStart = killedAt + 7
					local space = name:find(' ', vStart)
					victimName = space and name:sub(vStart, space - 1) or name:sub(vStart)
					victimEnd = space
				end

				-- your own death, lets the victim resolve to the local player below
				local mine = victimName == myName and killerName ~= myName

				-- killer player: UserName first, DisplayName only as a fallback since
				-- FindFirstChild matches Name; the victim is yourself on your own death
				local kplr = playersService:FindFirstChild(killerName)
				local vplr = mine and lplr or playersService:FindFirstChild(victimName)

				-- one GetPlayers() pass fills both gaps instead of two separate scans
				if not (kplr and vplr) then
					for _, p in playersService:GetPlayers() do
						if not kplr and p.DisplayName == killerName then kplr = p end
						if not vplr and p.DisplayName == victimName then vplr = p end
						if kplr and vplr then break end
					end
				end

				-- display names, the raw slices still end with " (" from "(@...)"
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
					-- no (@...) on the victim, the token we parsed is the whole name
					vDisp = victimName
				end

				-- team colors straight off Player.TeamColor, hex strings memoized
				local killerTeam = kplr and kplr.TeamColor
				local victimTeam = vplr and vplr.TeamColor
				local kHex = killerTeam and knHex(killerTeam.Color)
				local vHex = victimTeam and knHex(victimTeam.Color)

				-- killer health at kill time, shown as [health%] after their name
				local kHealth, kHealthHex
				if kplr then
					local character = kplr.Character
					local humanoid = character and character:FindFirstChildOfClass('Humanoid')
					if humanoid and humanoid.Health > 0 and humanoid.MaxHealth > 0 then
						kHealth = math.floor(humanoid.Health / humanoid.MaxHealth * 100 + 0.5)
						kHealthHex = knHealthHex(kHealth)
					end
				end

				-- weapon, taken from "with Weapon" and trimmed of any " (distance)"
				local weapon
				if victimEnd then
					local wstart = name:find('with ', victimEnd)
					if wstart then
						weapon = name:match('with%s+(.-)%s*%(', wstart) or name:match('with%s+(.-)%s*$', wstart)
					end
				end

				-- newest goes to the bottom of the stack, older ones get pushed up
				local entry = prototype:Clone()
				entry.Text = (kHex and '<font color="'..kHex..'">'..kDisp..'</font>' or kDisp)
					..(kHealth and ' [<font color="'..kHealthHex..'">'..kHealth..'%</font>]' or '')..' killed '
					..(vHex and '<font color="'..vHex..'">'..vDisp..'</font>' or vDisp)
					..(weapon and ' ['..weapon..']' or '')
				entry.Parent = killfeedGui

				table.insert(stack, 1, entry)
				if #stack > MAX_STACK then
					stack[#stack]:Destroy()
					table.remove(stack)
				end
				for i = 1, #stack do
					stack[i].Position = UDim2.new(0.5, 0, 1, -BASE_OFFSET - (i - 1) * ENTRY_STEP)
				end

				task.delay(LIFETIME, function()
					local idx = table.find(stack, entry)
					if not idx then return end
					table.remove(stack, idx)
					entry:Destroy()
					-- only the entries above the hole shift down, the rest keep their slot
					for i = idx, #stack do
						stack[i].Position = UDim2.new(0.5, 0, 1, -BASE_OFFSET - (i - 1) * ENTRY_STEP)
					end
				end)
			end))

			KillNotifications:Clean(function()
				if killfeedGui then
					killfeedGui:Destroy()
					killfeedGui = nil
				end
				table.clear(stack)
			end)
		end
	end,
	Tooltip = 'Shows a killfeed of who killed who at the bottom of the screen.'
})

KNHeight = KillNotifications:CreateSlider({
	Name = 'Height',
	Min = 0,
	Max = 300,
	Default = 100,
	Suffix = 'px',
	Tooltip = 'killfeed gui y axis',
	Function = function(value)
		BASE_OFFSET = value
	end
})
BASE_OFFSET = KNHeight.Value