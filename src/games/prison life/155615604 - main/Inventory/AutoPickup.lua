local AutoPickup
local AutoPickOnDied
local items = {}
local PickupList = {}
local died = false
local PICKUP_GUN_CFRAME = CFrame.new(816, 98, 2225)

local function AddPickup(pickup)
	if pickup:IsA('Model') and pickup.Name ~= 'Model' and pickup:GetAttribute('ToolName') then
		table.insert(items, {
			pickup,
			pickup.Name == 'TouchGiver'
		})
	end
end

local function hasTool(name, backpack)
	local tool = lplr.Character:FindFirstChildWhichIsA('Tool')
	return backpack:FindFirstChild(name) or tool and tool.Name == name and tool
end

local function grabEquipment(destination)
	local character = entitylib.character
	local humanoid = character.Humanoid
	local backpack = lplr:FindFirstChildWhichIsA('Backpack')
	local held = lplr.Character:FindFirstChildWhichIsA('Tool')
	local stash = backpack and backpack:FindFirstChildWhichIsA('Tool')
	local root = character.RootPart

	if held or stash then
		if destination then
			root.CFrame = destination
			root.AssemblyLinearVelocity = Vector3.zero
		end

		if stash and not held then
			humanoid:EquipTool(stash)
		end

		return
	end

	local origin = destination or root.CFrame
	local deadline = os.clock() + 2

	repeat
		root.CFrame = PICKUP_GUN_CFRAME
		root.AssemblyLinearVelocity = Vector3.zero
		task.wait(0.05)

		local char = lplr.Character
		backpack = lplr:FindFirstChildWhichIsA('Backpack')
		held = char and char:FindFirstChildWhichIsA('Tool')
		stash = backpack and backpack:FindFirstChildWhichIsA('Tool')
	until held or stash or os.clock() > deadline or not entitylib.isAlive or not AutoPickup.Enabled

	if root.Parent and lplr.Character == character.Character then
		root.CFrame = origin
		root.AssemblyLinearVelocity = Vector3.zero
	end

	if AutoPickup.Enabled and entitylib.isAlive and entitylib.character == character and stash and not held then
		humanoid:EquipTool(stash)
	end
end

local function pickupAfterRespawn(char, destination)
	task.spawn(function()
		if not char or not char:WaitForChild('Humanoid', 5) then return end
		task.wait(1)

		repeat
			task.wait()
		until not AutoPickup.Enabled
			or not AutoPickOnDied.Enabled
			or lplr.Character ~= char
			or (entitylib.isAlive and entitylib.character.Character == char)

		if AutoPickup.Enabled and AutoPickOnDied.Enabled and lplr.Character == char
			and entitylib.isAlive and entitylib.character.Character == char then
			died = false
			grabEquipment(destination)
		end
	end)
end

AutoPickup = vape.Categories.Inventory:CreateModule({
	Name = 'AutoPickup',
	Function = function(callback)
		local diedConnection

		local function connectDeath(entity)
			local humanoid = entity and entity.Humanoid
			if not humanoid then return end

			if diedConnection then
				diedConnection:Disconnect()
			end

			diedConnection = humanoid.Died:Connect(function()
				if AutoPickOnDied.Enabled then
					died = true
				end
			end)
		end

		local function onRespawn(entity)
			connectDeath(entity)

			if died then
				died = false

				if AutoPickOnDied.Enabled then
					pickupAfterRespawn(entity and entity.Character)
				end
			end
		end

		if callback then
			for _, pickup in workspace:GetChildren() do
				task.spawn(AddPickup, pickup)
			end

			for _, pickup in workspace:QueryDescendants('Model > .TouchGiver') do
				task.spawn(AddPickup, pickup)
			end

			AutoPickup:Clean(workspace.ChildAdded:Connect(AddPickup))
			AutoPickup:Clean(workspace.ChildRemoved:Connect(function(pickup)
				for index, data in items do
					if data[1] == pickup then
						table.remove(items, index)
						break
					end
				end
			end))

			AutoPickup:Clean(entitylib.Events.LocalAdded:Connect(onRespawn))
			if entitylib.isAlive then
				connectDeath(entitylib.character)
			end

			repeat
				if entitylib.isAlive then
					local localpos = entitylib.character.RootPart.Position
					local backpack = lplr:FindFirstChildWhichIsA('Backpack')

					if backpack then
						for _, pickup in items do
							if pickup[1].PrimaryPart and (pickup[1].PrimaryPart.Position - localpos).Magnitude < 12 then
								local tool = pickup[1]:GetAttribute('ToolName')
								if hasTool(tool, backpack) then
									continue
								end

								if pickup[2] and not table.find(PickupList[lplr.Team == teams.Guards and 'Guard' or (lplr.Team == teams.Criminals and 'Criminal' or 'Prisoner')].ListEnabled, tool) then
									continue
								end

								replicatedStorage.Remotes.GiverPressed:FireServer(pickup[1])
							end
						end
					end
				end

				task.wait(0.05)
			until not AutoPickup.Enabled
		else
			if diedConnection then
				diedConnection:Disconnect()
				diedConnection = nil
			end

			died = false
			table.clear(items)
		end
	end,
	Tooltip = 'Automatically grab item pickups'
})

AutoPickOnDied = AutoPickup:CreateToggle({
	Name = 'OnDied',
	Default = false,
	Tooltip = 'Teleport to the gun spawner after respawning, grab a gun and return.'
})

for _, team in {'Prisoner', 'Guard', 'Criminal'} do
	PickupList[team] = AutoPickup:CreateTextList({
		Name = team,
		Default = {team == 'Criminal' and 'AK-47' or 'MP5', 'Remington 870'},
		Placeholder = 'item'
	})
end