local KillNotifications
local KNMode

-- the notification label is RichText, so a name can be tinted with its team
-- color (inmate orange / guard blue / neutral grey). Falls back to plain text
-- when the player or their team can't be resolved.
local function teamHex(plrName)
	local plr = plrName and playersService:FindFirstChild(plrName)
	local color = plr and plr.Team and plr.TeamColor and plr.TeamColor.Color
	if not color then return nil end
	return string.format('#%02x%02x%02x', math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
end

local function colored(text, hex)
	return hex and ('<font color="'..hex..'">'..text..'</font>') or text
end

KillNotifications = vape.Categories.Render:CreateModule({
	Name = 'KillNotifications',
	Function = function(callback)
		if callback then
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
				local selfDeath = victim == lplr.Name and killer ~= lplr.Name
				local allKills = KNMode.Value == 'All killfeeds'
				if not (selfDeath or allKills) then return end

				-- only now pull the weapon out of the "with Weapon" trailer
				local weapon
				if endchar then
					local wstart = name:find('with ', endchar)
					if wstart then
						weapon = name:sub(wstart + 5):match('^%s*(.-)%s*$')
						weapon = weapon:match('^(.-)%s*%([^()]*%)$') or weapon
					end
				end
				local extra = weapon and weapon ~= '' and (' ['..weapon..']') or ''

				if selfDeath then
					-- your own death lingers longer so it isn't missed
					notif('KillNotifications', colored(killer, teamHex(killer))..' killed '..colored('you', teamHex(lplr.Name))..'!'..extra, 2.5)
				else
					-- every other kill in the server stays brief
					notif('KillNotifications', colored(killer, teamHex(killer))..' killed '..colored(victim, teamHex(victim))..'!'..extra, 1)
				end
			end))
		end
	end,
	Tooltip = 'Sends a notification of who killed you.'
})

KNMode = KillNotifications:CreateDropdown({
	Name = 'Mode',
	List = {'Self', 'All killfeeds'},
	Tooltip = 'Self = only notify when you are killed. All killfeeds = notify for every kill in the server.'
})
