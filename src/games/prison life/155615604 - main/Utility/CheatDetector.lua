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