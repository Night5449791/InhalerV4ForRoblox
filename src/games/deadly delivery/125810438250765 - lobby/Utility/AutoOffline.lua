local AutoOffline
local Delay
local MinHours
local ShowClaim

run(function()
	-- the lobby fridge (Workspace.Func.Fridge) is an interactable: touching it fires
	-- TEvent.FireRemote("OfflineReward", tick()) and the server rolls the reward from
	-- Value.OfflineTime.Value, then zeroes the timer. Nothing in that call is tied to the
	-- player standing at the fridge, so the remote can be fired directly.
	local function offlineTime()
		local value = deadlydelivery.Value and deadlydelivery.Value.OfflineTime
		return value and value.Value
	end

	AutoOffline = vape.Categories.Utility:CreateModule({
		Name = 'AutoOffline',
		Function = function(callback)
			if not callback then return end

			local lastClaim = 0

			repeat
				local time = offlineTime()
				local minimum = MinHours.Value * 3600
				if typeof(time) == 'number' and time > 0 and time >= minimum and os.clock() - lastClaim >= Delay.Value then
					lastClaim = os.clock()
					deadlydelivery.fire('OfflineReward', tick())

					if ShowClaim.Enabled then
						vape:CreateNotification('AutoOffline', 'Claimed ' .. string.format('%.1f', time / 3600) .. 'h of offline rewards', 5, 'info')
					end
				end

				task.wait(1)
			until not AutoOffline.Enabled or vape.Loaded == nil
		end,
		Tooltip = 'Claims the fridge offline reward in the lobby once it reaches the minimum hours'
	})

	Delay = AutoOffline:CreateSlider({
		Name = 'Delay',
		Min = 1,
		Max = 30,
		Default = 3,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end
	})
	MinHours = AutoOffline:CreateSlider({
		Name = 'Min hours',
		Min = 0,
		Max = 12,
		Decimal = 10,
		Default = 0,
		Suffix = function(val)
			return val == 1 and 'hour' or 'hours'
		end,
		Tooltip = 'Only claims once the fridge holds at least this much offline time'
	})
	ShowClaim = AutoOffline:CreateToggle({
		Name = 'Notify',
		Default = true
	})
end)
