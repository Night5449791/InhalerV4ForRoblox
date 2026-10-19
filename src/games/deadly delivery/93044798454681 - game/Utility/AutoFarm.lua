local AutoFarm
local FarmRange
local FarmDelay
local DeliverAt
local OpenContainers

run(function()
	-- One loop for the whole run: grab loot (or open a container when the floor is empty), then
	-- walk the carried piece(s) to the elevator. Carried loot is a tool under
	-- GameSystem.Loots.Player, and the elevator is the only hand over spot in the run, so the
	-- loop waits there and pokes the elevator model if the loot did not leave by itself. After a
	-- few failed hand overs it stops standing at the lift and keeps farming instead of hanging.
	local elevatorCenter
	local elevatorModel

	local function elevator()
		if elevatorCenter and elevatorCenter.Parent then return elevatorCenter end

		local folder = workspace:FindFirstChild('电梯')
		if not folder then return end

		for _, descendant in folder:GetDescendants() do
			if descendant:IsA('BasePart') and descendant.Name == 'ElevatorCenter' then
				elevatorCenter = descendant
				return descendant
			end
		end
	end

	local function lift()
		if elevatorModel and elevatorModel.Parent then return elevatorModel end

		local folder = workspace:FindFirstChild('电梯')
		if not folder then return end

		for _, descendant in folder:GetDescendants() do
			if descendant:IsA('Model') and descendant.Name == 'Elevator' then
				elevatorModel = descendant
				return descendant
			end
		end
	end

	local function nearest(entries, origin, range)
		local best, bestDistance
		for _, entry in entries do
			local distance = (entry.Part.Position - origin).Magnitude
			if distance <= range and (not bestDistance or distance < bestDistance) then
				best, bestDistance = entry, distance
			end
		end

		return best
	end

	local function deliver(home)
		local center = elevator()
		local target = home or (center and center.Position)
		if not target then return false end

		-- the lift sits on another floor of the maze, so the spot the character started on is
		-- tried first and the lift center is only the fallback
		if not dungeon.walkTo(target, 25) and center then
			dungeon.walkTo(center.Position, 20)
		end

		for _ = 1, 16 do
			if dungeon.itemCount() == 0 then return true end
			task.wait(0.3)
		end

		local model = lift()
		if model then
			dungeon.interact(model)
			for _ = 1, 10 do
				if dungeon.itemCount() == 0 then return true end
				task.wait(0.3)
			end
		end

		return dungeon.itemCount() == 0
	end

	local blocked = {}

	AutoFarm = vape.Categories.Utility:CreateModule({
		Name = 'AutoFarm',
		Function = function(callback)
			if not callback then return end

			local home = dungeon.position()
			local failures = 0

			repeat
				local carried = dungeon.itemCount()

				if carried >= DeliverAt.Value and failures < 3 then
					if deliver(home) then
						failures = 0
					else
						failures = failures + 1
					end
				else
					local origin = dungeon.position()
					if origin then
						local now = os.clock()
						local target = nearest(dungeon.loot(), origin, FarmRange.Value)

						if not target and OpenContainers.Enabled then
							local entries = {}
							for _, entry in dungeon.containers() do
								local unlock = blocked[entry.Model]
								if not (unlock and unlock > now) then
									table.insert(entries, entry)
								end
							end

							target = nearest(entries, origin, FarmRange.Value)
						end

						if target and not (blocked[target.Model] and blocked[target.Model] > now) then
							if dungeon.walkTo(target.Part.Position, 20) then
								dungeon.interact(target.Model)
								task.wait(0.6)
							else
								blocked[target.Model] = now + 5
							end
						end
					end
				end

				task.wait(FarmDelay.Value)
			until not AutoFarm.Enabled or vape.Loaded == nil
		end,
		Tooltip = 'Grabs loot, carries it to the elevator and starts over'
	})

	FarmRange = AutoFarm:CreateSlider({
		Name = 'Range',
		Min = 20,
		Max = 500,
		Default = 300,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	FarmDelay = AutoFarm:CreateSlider({
		Name = 'Delay',
		Min = 0.1,
		Max = 2,
		Decimal = 10,
		Default = 0.3,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end
	})
	DeliverAt = AutoFarm:CreateSlider({
		Name = 'Deliver at',
		Min = 1,
		Max = 10,
		Default = 3,
		Tooltip = 'Walks back to the elevator once this many pieces are carried'
	})
	OpenContainers = AutoFarm:CreateToggle({
		Name = 'Open containers',
		Default = true,
		Tooltip = 'Also opens crates, cabinets and soil mounds when there is no loot on the floor'
	})
end)
