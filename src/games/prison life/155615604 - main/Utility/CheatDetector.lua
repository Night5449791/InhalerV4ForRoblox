local CheatDetector
local AddTarget
local Teleport
local PingLimit
local positions = {}
local overlap = OverlapParams.new()
overlap.CollisionGroup = 'Players'
overlap.FilterDescendantsInstances = {workspace.CarContainer, workspace.Doors}
overlap.FilterType = Enum.RaycastFilterType.Exclude
local carOverlap = OverlapParams.new()
carOverlap.FilterDescendantsInstances = {workspace.CarContainer}
carOverlap.FilterType = Enum.RaycastFilterType.Include
carOverlap.MaxParts = 1

local whitelist = vape.Libraries.whitelist
local stats = cloneref(game:GetService('Stats'))
local pingItem = stats.Network.ServerStatsItem['Data Ping']

-- the movement checks compare positions the client only sees fresh while the connection
-- keeps up; the Data Ping stat itself only moves about once a second, so the value is
-- cached instead of pcall'ing it twenty times a second, and an unreadable ping counts as
-- fine so detection never silently stops
local pingValue, pingTime = 0, 0
local function getPing()
	local now = os.clock()
	if now - pingTime < 1 then
		return pingValue
	end

	pingTime = now
	local success, value = pcall(pingItem.GetValue, pingItem)
	pingValue = success and tonumber(value) or 0
	return pingValue
end

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
				if not select(2, whitelist:get(plr)) then return end

				notif('CheatDetector', 'This player may be cheating! ('..flagType..'): '..plr.Name, 15, 'warning')
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
				-- over the ping limit the client's view of everyone else is stale enough
				-- that movement would be flagged on innocent players, so only the humanoid
				-- state check keeps running (invalid animations are flagged elsewhere)
				local movement = getPing() <= PingLimit.Value

				for _, entity in entitylib.List do
					if entity.Health > 0 and entity.Player and select(2, whitelist:get(entity.Player)) and not Cheats.Flagged[entity.Player.UserId] then
						local root = entity.RootPart
						local humanoid = entity.Humanoid
						local playerPos = root.Position

						local state = humanoid:GetState()
						if not whiteliststates[state] then
							Cheats:Flag(entity.Player, 'invalid state '..state.Name, 1)
						end

						if not humanoid.SeatPart then
							local last = positions[entity]

							if movement then
								if not checkPoint(entity.Head.Position, overlap) then
									Cheats:Flag(entity.Player, 'phase/noclip', 20)
								end

								local velo = root.AssemblyLinearVelocity
								if (velo * flatMask).Magnitude > 26 and #workspace:GetPartBoundsInRadius(playerPos, 30, carOverlap) <= 0 then
									Cheats:Flag(entity.Player, 'speed', 20)
								end

								if last and Teleport.Enabled and ((playerPos - last[1]) * flatMask).Magnitude > 50 and #workspace:GetPartBoundsInRadius(playerPos, 30, carOverlap) <= 0 then
									if entity.Player.Team ~= teams.Inmates or (clock - entity.SpawnTime) > 0.1 then
										Cheats:Flag(entity.Player, 'teleport', 1)
									end
								end

								if velo.Y > 50 then
									Cheats:Flag(entity.Player, 'highjump', 20)
								end
							end

							-- the recorded position keeps updating while the movement checks
							-- are paused, comparing against a stale entry on the next frame
							-- would flag a teleport
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
PingLimit = CheatDetector:CreateSlider({
	Name = 'Ping Limit',
	Min = 100,
	Max = 500,
	Default = 100,
	Suffix = 'ms',
	Tooltip = 'Stops the movement checks (speed, teleport, highjump, noclip) while your ping is over this, high ping makes them flag innocent players.\nHumanoid state and invalid animation detection keep running.'
})