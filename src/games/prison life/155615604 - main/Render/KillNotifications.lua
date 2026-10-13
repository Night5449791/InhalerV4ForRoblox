local KillNotifications
local KNMode
local KNHeight

local MAX_STACK = 4
local LIFETIME = 2.5
local ENTRY_W = 460
local ENTRY_H = 22
local ENTRY_GAP = 3
local BASE_OFFSET

local killfeedGui, stack

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

				-- decide relevance first so irrelevant kills do no extra string work
				local mine = victimName == myName and killerName ~= myName
				if not mine and KNMode.Value ~= 'All killfeeds' then return end

				-- killer player: UserName first, DisplayName only as a fallback since
				-- FindFirstChild matches Name
				local kplr = playersService:FindFirstChild(killerName)
				if not kplr then
					for _, p in playersService:GetPlayers() do
						if p.DisplayName == killerName then kplr = p break end
					end
				end

				-- victim player, yourself on your own death
				local vplr = mine and lplr or playersService:FindFirstChild(victimName)
				if not mine and not vplr then
					for _, p in playersService:GetPlayers() do
						if p.DisplayName == victimName then vplr = p break end
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

				-- team colors straight off Player.TeamColor
				local kHex
				do
					local teamColor = kplr and kplr.TeamColor
					if teamColor then
						local c = teamColor.Color
						kHex = string.format('#%02x%02x%02x', math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
					end
				end

				local vHex
				do
					local teamColor = vplr and vplr.TeamColor
					if teamColor then
						local c = teamColor.Color
						vHex = string.format('#%02x%02x%02x', math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
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
				local entry = Instance.new('TextLabel')
				entry.Name = 'Killfeed'
				entry.AnchorPoint = Vector2.new(0.5, 1)
				entry.BackgroundTransparency = 1
				entry.BorderSizePixel = 0
				entry.Font = Enum.Font.GothamBold
				entry.RichText = true
				entry.Text = (kHex and '<font color="'..kHex..'">'..kDisp..'</font>' or kDisp)..' killed '
					..(vHex and '<font color="'..vHex..'">'..vDisp..'</font>' or vDisp)
					..(weapon and ' ['..weapon..']' or '')
				entry.TextColor3 = Color3.new(1, 1, 1)
				entry.TextSize = 15
				entry.TextStrokeColor3 = Color3.new()
				entry.TextStrokeTransparency = 0.7
				entry.TextXAlignment = Enum.TextXAlignment.Center
				entry.Size = UDim2.new(0, ENTRY_W, 0, ENTRY_H)
				entry.Parent = killfeedGui

				table.insert(stack, 1, entry)
				if #stack > MAX_STACK then
					stack[#stack]:Destroy()
					table.remove(stack)
				end
				for i, other in stack do
					other.Position = UDim2.new(0.5, 0, 1, -BASE_OFFSET - (i - 1) * (ENTRY_H + ENTRY_GAP))
				end

				task.delay(LIFETIME, function()
					local idx = table.find(stack, entry)
					if not idx then return end
					table.remove(stack, idx)
					entry:Destroy()
					for i, other in stack do
						other.Position = UDim2.new(0.5, 0, 1, -BASE_OFFSET - (i - 1) * (ENTRY_H + ENTRY_GAP))
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

KNMode = KillNotifications:CreateDropdown({
	Name = 'Mode',
	List = {'Self', 'All killfeeds'},
	Tooltip = 'Self = only show kills involving you. All killfeeds = show every kill in the server.'
})

KNHeight = KillNotifications:CreateSlider({
	Name = 'Height',
	Min = 0,
	Max = 300,
	Default = 100,
	Suffix = 'px',
	Tooltip = 'How far above the bottom of the screen the killfeed sits.',
	Function = function(value)
		BASE_OFFSET = value
	end
})
BASE_OFFSET = KNHeight.Value