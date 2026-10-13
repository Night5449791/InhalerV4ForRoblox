local KillNotifications
local KNMode

local ALL_MODE = 'All killfeeds'

-- the notification label is RichText, so a name can be tinted with its team
-- color (inmate orange / guard blue / neutral grey).
local function hexOf(color)
	if not color then return nil end
	return string.format('#%02x%02x%02x', math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
end

-- Prison Life blanks a player's Team the moment they die, so the killfeed fires
-- while the victim already has no team. Keep the last color we saw for each
-- player and fall back to it, otherwise the dead victim would render uncolored.
local lastHex = {}

local function colorHex(plr)
	if not plr then return nil end
	local color = plr.Team and plr.TeamColor and plr.TeamColor.Color
	if color then
		lastHex[plr.Name] = hexOf(color)
	end
	return lastHex[plr.Name]
end

local function wrap(text, hex)
	return hex and ('<font color="'..hex..'">'..text..'</font>') or text
end

KillNotifications = vape.Categories.Render:CreateModule({
	Name = 'KillNotifications',
	Function = function(callback)
		if callback then
			-- seed the cache so players who die before we ever resolved them
			-- still carry their team color into the notification
			for _, plr in playersService:GetPlayers() do
				colorHex(plr)
			end
			local myName = lplr.Name

			-- listen to the killfeed directly instead of relying on the
			-- vapeEvents.PlayerKill BindableEvent, so a missed delivery (cross-file
			-- BindableEvent plumbing) can't silently drop the notification. The
			-- parsing matches base.lua / upstream, which drives the kills/deaths
			-- counters off the same ChildAdded signal.
			KillNotifications:Clean(replicatedStorage.Killfeed.ChildAdded:Connect(function(obj)
				local name = obj.Name

				-- killer: DisplayName (@UserName) -> UserName
				local start = name:find('@')
				local endchar = start and name:find(')', start)
				local killer = (start and endchar) and name:sub(start + 1, endchar - 1) or nil
				if not killer then return end

				-- victim
				start = name:find('killed ')
				if not start then return end
				start += 7
				endchar = name:find(' ', start)
				local victim = endchar and name:sub(start, endchar - 1) or name:sub(start)

				-- decide relevance first so irrelevant kills do no extra string work
				local mine = victim == myName and killer ~= myName
				if not mine and KNMode.Value ~= ALL_MODE then return end

				-- weapon, taken from "with Weapon" and trimmed of any " (distance)"
				local weapon
				if endchar then
					local wstart = name:find('with ', endchar)
					if wstart then
						weapon = name:match('with%s+(.-)%s*%(', wstart) or name:match('with%s+(.-)%s*$', wstart)
					end
				end

				local killerHex = colorHex(playersService:FindFirstChild(killer))

				if mine then
					-- your own death lingers longer so it isn't missed
					notif('KillNotifications', wrap(killer, killerHex)..' killed '..wrap('you', colorHex(lplr))..(weapon and ' ['..weapon..']' or ''), 2.5)
				else
					-- every other kill in the server stays brief
					local victimHex = colorHex(playersService:FindFirstChild(victim))
					notif('KillNotifications', wrap(killer, killerHex)..' killed '..wrap(victim, victimHex)..(weapon and ' ['..weapon..']' or ''), 1)
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
