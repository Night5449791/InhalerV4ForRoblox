local KillNotifications
local KNMode

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
				-- killer
				local start = obj.Name:find('@')
				local endchar = obj.Name:find(')')
				local killer = (start and endchar and endchar > start) and obj.Name:sub(start + 1, endchar - 1) or nil

				-- victim
				start = obj.Name:find('killed ')
				local victim
				if start then
					start += 7
					endchar = obj.Name:find(' ', start)
					victim = endchar and obj.Name:sub(start, endchar - 1) or obj.Name:sub(start)
				end

				if not (killer and victim) then return end

				if victim == lplr.Name and killer ~= lplr.Name then
					-- your own death lingers longer so it isn't missed
					notif('KillNotifications', killer..' killed you!', 2.5)
				elseif KNMode.Value == 'All killfeeds' then
					-- every other kill in the server stays brief
					notif('KillNotifications', killer..' killed '..victim..'!', 1)
				end
			end))
		end
	end,
	Tooltip = 'Sends a notification of who killed you. Set Mode to All killfeeds to see every kill in the server.'
})

KNMode = KillNotifications:CreateDropdown({
	Name = 'Mode',
	List = {'Self', 'All killfeeds'},
	Tooltip = 'Self = only notify when you are killed. All killfeeds = notify for every kill in the server.'
})
