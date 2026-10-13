local KillNotifications
local KNMode

local ALL_MODE = 'All killfeeds'

-- the notification label is RichText, so a name can be tinted with its team
-- color (inmate orange / guard blue / neutral grey).
local function hexOf(plr)
	local teamColor = plr and plr.TeamColor
	if not teamColor then return nil end
	local color = teamColor.Color
	return string.format('#%02x%02x%02x', math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
end

-- the killfeed may show either the UserName or the DisplayName, so fall back to
-- a DisplayName scan when FindFirstChild (which matches Name) comes up empty.
local function findPlayer(who)
	if not who then return nil end
	local plr = playersService:FindFirstChild(who)
	if plr then return plr end
	for _, p in playersService:GetPlayers() do
		if p.DisplayName == who then return p end
	end
	return nil
end

local function wrap(text, hex)
	return hex and ('<font color="'..hex..'">'..text..'</font>') or text
end

KillNotifications = vape.Categories.Render:CreateModule({
	Name = 'KillNotifications',
	Function = function(callback)
		if callback then
			local myName = lplr.Name
			local myDisp = lplr.DisplayName

			-- listen to the killfeed directly instead of relying on the
			-- vapeEvents.PlayerKill BindableEvent, so a missed delivery (cross-file
			-- BindableEvent plumbing) can't silently drop the notification. The
			-- parsing matches base.lua / upstream, which drives the kills/deaths
			-- counters off the same ChildAdded signal.
			KillNotifications:Clean(replicatedStorage.Killfeed.ChildAdded:Connect(function(obj)
				local name = obj.Name

				-- "DisplayName (@UserName)  killed DisplayName2 (@UserName2) with Weapon"
				local killedAt = name:find('killed ')
				if not killedAt then return end

				local killerAt = name:find('@')
				local killerClose = killerAt and name:find(')', killerAt)
				if not (killerAt and killerClose and killerClose < killedAt) then return end
				local killerName = name:sub(killerAt + 1, killerClose - 1)

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
				if not mine and KNMode.Value ~= ALL_MODE then return end

				-- DisplayNames are only needed once we know we will notify
				local killerDisp = name:sub(1, killerAt - 1):match('^%s*(.-)%s*$')
				if killerDisp == '' then killerDisp = killerName end
				local victimDisp
				if victimAt and victimClose then
					victimDisp = name:sub(killedAt + 7, victimAt - 1):match('^%s*(.-)%s*$')
					if victimDisp == '' then victimDisp = victimName end
				else
					victimDisp = victimName
				end

				-- weapon, taken from "with Weapon" and trimmed of any " (distance)"
				local weapon
				if victimEnd then
					local wstart = name:find('with ', victimEnd)
					if wstart then
						weapon = name:match('with%s+(.-)%s*%(', wstart) or name:match('with%s+(.-)%s*$', wstart)
					end
				end

				local killerHex = hexOf(findPlayer(killerName))

				if mine then
					-- your own death lingers longer so it isn't missed
					notif('KillNotifications', wrap(killerDisp, killerHex)..' killed '..wrap(myDisp, hexOf(lplr))..(weapon and ' ['..weapon..']' or ''), 2.5)
				else
					-- every other kill in the server stays brief
					local victimHex = hexOf(findPlayer(victimName))
					notif('KillNotifications', wrap(killerDisp, killerHex)..' killed '..wrap(victimDisp, victimHex)..(weapon and ' ['..weapon..']' or ''), 1)
				end
			end))
		end
	end,
	Tooltip = 'Sends a notification of who killed you.'
})

KNMode = KillNotifications:CreateDropdown({
	Name = 'Mode',
	List = {'Self', ALL_MODE},
	Tooltip = 'Self = only notify when you are killed. All killfeeds = notify for every kill in the server.'
})
