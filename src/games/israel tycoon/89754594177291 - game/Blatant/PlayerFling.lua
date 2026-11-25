local PlayerFling
local Targets
local Range
local Speed
local Step

local function rootOf(entity)
	if entity.RootPart then return entity.RootPart end
	return entity.Character and entity.Character:FindFirstChild('HumanoidRootPart')
end

-- A single big CFrame jump gets rolled back, but nudging the root a few studs each frame
-- stays inside the server's replication tolerance and accumulates into a real lift.
PlayerFling = vape.Categories.Blatant:CreateModule({
	Name = 'Player Fling',
	Function = function(callback)
		if callback then
			repeat
				local character = lplr.Character
				local myRoot = character and character:FindFirstChild('HumanoidRootPart')
				if myRoot then
					local entity = entitylib.EntityPosition({
						Part = 'RootPart',
						Range = Range.Value,
						Origin = myRoot.Position,
						Players = Targets.Players.Enabled,
						NPCs = Targets.NPCs.Enabled
					})

					local root = entity and rootOf(entity)
					if root then
						root.CFrame = CFrame.new(root.Position + Vector3.new(0, Speed.Value, 0)) * root.CFrame.Rotation
					end
				end

				for _ = 1, Step.Value do
					task.wait()
				end
			until not PlayerFling.Enabled
		end
	end,
	Tooltip = 'Lifts the closest player in small CFrame steps the server treats as movement instead of a teleport'
})
Targets = PlayerFling:CreateTargets({
	Players = true,
	NPCs = false
})
Range = PlayerFling:CreateSlider({
	Name = 'Range',
	Min = 1,
	Max = 500,
	Default = 200,
	Suffix = 'studs'
})
Speed = PlayerFling:CreateSlider({
	Name = 'Step',
	Min = 0.5,
	Max = 20,
	Default = 1,
	Decimal = 10,
	Tooltip = 'Studs added per push; about 1 per frame survives, larger values get rolled back'
})
Step = PlayerFling:CreateSlider({
	Name = 'Delay Frames',
	Min = 1,
	Max = 30,
	Default = 1,
	Tooltip = 'Frames to wait between pushes'
})
