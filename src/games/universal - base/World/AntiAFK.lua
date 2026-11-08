local AntiAFK
local Options
local Range
local WaitTime
local WaitRandom
local Visuals
local PathColor
local NodeColor
local ShowWaypoints
local ShowPrediction
local PredictionLength
local PredictionBranches
local pathfindingService = cloneref(game:GetService('PathfindingService'))
local tick = 0.05
-- drawing is the expensive half of this module and nothing on screen changes faster
-- than a walking character, so the render loop runs at a fixed low rate instead of
-- once per frame and the animation branch skips entirely while it is idle
local renderInterval = 1 / 30
local startPosition, timer, pathFinder, processor, currentWaypoint = nil, 0, nil, nil, nil
local controlsModule, oldMoveFunction, goalsSinceAnchor = nil, nil, 0
local waypoints, predictions, candidates = {}, {}, {}
local lineObjects, nodeObjects, predictionObjects = {}, {}, {}
local rayCheck = RaycastParams.new()

-- colours are a setting, not a per-frame value: resolved when one changes and reused
-- by every dot and line until then, so the loop does no HSV conversion at all
local pathColor, nodeColor = Color3.new(1, 1, 1), Color3.new(1, 1, 1)
local predictionColor = Color3.fromRGB(255, 40, 40)
local agentParams = {AgentRadius = 2, AgentHeight = 5, AgentCanJump = true, AgentCanClimb = true, WaypointSpacing = 4}
local downVector, upVector = Vector3.new(0, -60, 0), Vector3.new(0, 20, 0)

local function getRoot()
	if entitylib.isAlive then
		return entitylib.character.RootPart
	end
end

local function randomize(base, range)
	if not base then return end

	local angle, distance = math.random() * math.pi * 2, range * math.sqrt(0.15 + math.random() * 0.85)
	return base + Vector3.new(math.cos(angle) * distance, math.random(0, range * 2) - range, math.sin(angle) * distance)
end

local function snapToGround(position)
	if not position then return end
	rayCheck.FilterDescendantsInstances = {lplr.Character}
	rayCheck.IgnoreWater = true

	local hit = workspace:Raycast(position + upVector, downVector, rayCheck)
	if hit and not workspace:Raycast(hit.Position + Vector3.new(0, 3, 0), Vector3.new(0, 5, 0), rayCheck) then
		return hit.Position
	end
end

local function think(finder)
	local root = getRoot()
	if root and finder.Goal then
		local path = pathfindingService:CreatePath(agentParams)
		if pcall(path.ComputeAsync, path, root.Position, finder.Goal) and path.Status == Enum.PathStatus.Success then
			finder.Path = path
			finder.Done = true
			return
		end
	end

	finder.Failed = true
end

local function formatPath(finder)
	table.clear(finder.Waypoints)
	table.clear(waypoints)

	if not finder.Path then return end
	for index, waypoint in finder.Path:GetWaypoints() do
		finder.Waypoints[index] = {Position = waypoint.Position, Action = waypoint.Action}
		waypoints[index] = finder.Waypoints[index]
	end
end

local function buildCandidates()
	table.clear(candidates)

	local root = getRoot()
	if not root then return end

	local branches, baseAngle = math.clamp(PredictionBranches.Value, 1, 4), math.random() * math.pi * 2
	for branch = 1, branches do
		local angle = baseAngle + (branch - 1) / branches * math.pi * 2
		local goal = snapToGround(root.Position + Vector3.new(math.cos(angle) * Range.Value, 0, math.sin(angle) * Range.Value))
		candidates[branch] = {Angle = angle, Origin = root.Position, Goal = goal, Chosen = false}
	end
end

local function startPath(finder)
	if finder.Done then
		formatPath(finder)
		pathFinder, processor, timer = finder, {Index = 1, OffPath = 0}, 0
		return true
	end
end

local function nextGoal()
	local root = getRoot()

	goalsSinceAnchor += 1
	if root and goalsSinceAnchor >= 4 then
		startPosition, goalsSinceAnchor = root.Position, 0
	end

	buildCandidates()

	local order = {}
	for index = 1, #candidates do
		order[index] = index
	end

	for index = #order, 2, -1 do
		local swap = math.random(1, index)
		order[index], order[swap] = order[swap], order[index]
	end

	for _, index in order do
		local candidate = candidates[index]
		if candidate.Goal then
			local finder = {Goal = candidate.Goal, Waypoints = {}}
			think(finder)

			if startPath(finder) then
				for other, entry in candidates do
					entry.Chosen = other == index
				end
				return
			end
		end
	end

	local finder = {Goal = snapToGround(randomize(startPosition, Range.Value)), Waypoints = {}}
	processor = nil
	think(finder)
	startPath(finder)
end

local function isPathValid(finder, index)
	local root, waypoint = getRoot(), finder.Waypoints[index]
	if not root or not waypoint then return false end
	return (waypoint.Position - Vector3.new(root.Position.X, waypoint.Position.Y, root.Position.Z)).Magnitude < 40
end

local function walkPath(finder, proc)
	local root, waypoint = getRoot(), finder.Waypoints[proc.Index]
	if not root or not waypoint then return true end

	if waypoint.Action == Enum.PathWaypointAction.Jump then
		entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		entitylib.character.Humanoid.Jump = true
	end

	currentWaypoint = waypoint.Position
	local offset = waypoint.Position - root.Position
	if Vector3.new(offset.X, 0, offset.Z).Magnitude < 5 then
		proc.Index += 1
		proc.OffPath = 0
	end

	return proc.Index > #finder.Waypoints
end

local function ensureDrawing(list, index, class)
	local object = list[index]
	if not object then
		if vape.ThreadFix then
			setthreadidentity(8)
		end

		object = Drawing.new(class)
		object.Thickness, object.Transparency, object.Filled = 1, 1, true
		list[index] = object
	end

	return object
end

local function clearDrawings(list)
	for index = #list, 1, -1 do
		pcall(function()
			list[index].Visible = false
			list[index]:Remove()
		end)

		list[index] = nil
	end
end

-- Reuses the `predictions` rows instead of rebuilding them: the old version cleared
-- the table and allocated a fresh array per branch per frame, which was the largest
-- source of garbage in the module. Rows are written in place and trimmed by length.
local function drawVisuals()
	local lineCount, nodeCount, dotCount = 0, 0, 0
	local totalWaypoints = #waypoints
	local enabled = Visuals.Enabled

	if enabled then
		for index = 1, totalWaypoints - 1 do
			local from, fromVisible = gameCamera:WorldToViewportPoint(waypoints[index].Position)
			local to, toVisible = gameCamera:WorldToViewportPoint(waypoints[index + 1].Position)

			lineCount += 1
			local line = ensureDrawing(lineObjects, lineCount, 'Line')
			line.From, line.To = Vector2.new(from.X, from.Y), Vector2.new(to.X, to.Y)
			line.Color = pathColor
			line.Visible = fromVisible or toVisible
		end

		local showNodes = ShowWaypoints.Enabled
		for index = 1, totalWaypoints do
			local position, visible = gameCamera:WorldToViewportPoint(waypoints[index].Position)

			nodeCount += 1
			local dot = ensureDrawing(nodeObjects, nodeCount, 'Circle')
			dot.Position, dot.Radius, dot.Color = Vector2.new(position.X, position.Y), 4, nodeColor
			dot.Visible = visible and showNodes
		end
	end

	for index = lineCount + 1, #lineObjects do
		lineObjects[index].Visible = false
	end

	for index = nodeCount + 1, #nodeObjects do
		nodeObjects[index].Visible = false
	end

	if enabled and ShowPrediction.Enabled and next(candidates) then
		local length = math.clamp(PredictionLength.Value, 1, 12)

		for branch, candidate in candidates do
			local row = predictions[branch]
			if not row then
				row = {}
				predictions[branch] = row
			end

			local origin, angle = candidate.Origin, candidate.Angle
			local step = Vector3.new(math.cos(angle), 0, math.sin(angle))

			for index = 1, length do
				row[index] = origin + step * (index * 3)
			end

			-- a shorter length than last time must not leave stale points behind
			for index = length + 1, #row do
				row[index] = nil
			end
		end

		-- a branch that stopped being used keeps its row; drop the rows past the
		-- highest live branch. An explicit bound is used because `#predictions` on a
		-- table with holes is undefined in Lua and a wrong answer here would leave
		-- stale dots on screen.
		local highest = 0
		for branch = 1, 4 do
			if candidates[branch] then highest = branch end
		end

		for branch = highest + 1, #predictions do
			predictions[branch] = nil
		end

		for branch = 1, highest do
			local row = predictions[branch]
			if row then
				local highlighted = candidates[branch] and candidates[branch].Chosen
				local count = #row

				for index = 1, count do
					local position, visible = gameCamera:WorldToViewportPoint(row[index])

					dotCount += 1
					local dot = ensureDrawing(predictionObjects, dotCount, 'Circle')
					dot.Position, dot.Color = Vector2.new(position.X, position.Y), predictionColor
					dot.Radius = highlighted and 3 or 2
					dot.Transparency = highlighted and math.clamp(1 - index / count, 0.15, 1) or 0.55
					dot.Visible = visible
				end
			end
		end
	else
		table.clear(predictions)
	end

	for index = dotCount + 1, #predictionObjects do
		predictionObjects[index].Visible = false
	end
end

local function installMove()
	if controlsModule then return end
	if not pcall(function()
		controlsModule = require(lplr.PlayerScripts.PlayerModule).controls
	end) or not controlsModule.moveFunction then
		controlsModule = nil
		return
	end

	oldMoveFunction = controlsModule.moveFunction
	controlsModule.moveFunction = function(self, vec, face)
		local root = currentWaypoint and getRoot()
		if root then
			local flat = Vector3.new(currentWaypoint.X - root.Position.X, 0, currentWaypoint.Z - root.Position.Z)
			if flat.Magnitude > 0.05 then
				vec = flat.Unit
			end
		end

		return oldMoveFunction(self, vec, face)
	end
end

-- Sitting is the one state that silently stops the walk: a Seated humanoid ignores
-- MoveTo, so the loop would keep computing paths while the character never moved.
-- `Seated` fires the moment the humanoid is put on a seat, which covers a chair, a
-- vehicle seat and a script that forces it, and standing up immediately is the only
-- reliable answer — a guard that only polls would leave the character sitting for up
-- to one tick, which on a forced sit is already too long.
local function standUp(humanoid)
	if humanoid and humanoid.Sit then
		humanoid.Sit = false
	end
end

local function installNoSit(humanoid)
	if not humanoid then return end

	AntiAFK:Clean(humanoid.Seated:Connect(function(_, seat)
		-- an occupied seat is the only reason to be Seated; releasing it is what the
		-- client itself does when the player presses jump
		if seat then
			standUp(humanoid)
		end
	end))
end

local function cleanup()
	if controlsModule and oldMoveFunction then
		controlsModule.moveFunction = oldMoveFunction
	end

	controlsModule, oldMoveFunction, currentWaypoint = nil, nil, nil

	startPosition, pathFinder, processor, timer = nil, nil, nil, 0
	table.clear(waypoints)
	table.clear(predictions)
	table.clear(candidates)
	clearDrawings(lineObjects)
	clearDrawings(nodeObjects)
	clearDrawings(predictionObjects)
end
AntiAFK = vape.Categories.World:CreateModule({
	Name = 'AntiAFK',
	Function = function(callback)
		if not callback then
			cleanup()
			return
		end

		pathColor = Color3.fromHSV(PathColor.Hue, PathColor.Sat, PathColor.Value)
		nodeColor = Color3.fromHSV(NodeColor.Hue, NodeColor.Sat, NodeColor.Value)

		startPosition = getRoot() and getRoot().Position
		timer = 0
		nextGoal()
		installMove()
		installNoSit(entitylib.isAlive and entitylib.character.Humanoid)

		-- The walk loop and the draw loop are separate: movement needs the 0.05s step,
		-- drawing does not. The draw loop is throttled and both are cleaned on disable.
		local renderAccumulator = 0
		-- set once after a redraw that hid everything, so the loop does not call
		-- drawVisuals every frame while the overlay is switched off
		local hiddenOnce = false

		AntiAFK:Clean(runService.RenderStepped:Connect(function(delta)
			-- with the overlay off there is nothing to draw, so the loop costs one
			-- comparison per frame instead of a full redraw
			if not Visuals.Enabled then
				if hiddenOnce then return end
				hiddenOnce = true
				drawVisuals()
				return
			end

			hiddenOnce = false
			renderAccumulator += delta
			if renderAccumulator < renderInterval then return end
			-- keep the remainder instead of resetting to zero: at 60fps a reset would
			-- round every frame up to the next whole tick and drift under 30
			renderAccumulator -= renderInterval
			drawVisuals()
		end))

		repeat
			local root, humanoid = getRoot(), entitylib.isAlive and entitylib.character.Humanoid
			if humanoid and root then
				if humanoid.Health <= 0 then
					AntiAFK:Toggle()
				elseif humanoid:GetState() == Enum.HumanoidStateType.Swimming then
					humanoid.Jump = true
				elseif humanoid.Sit then
					-- the Seated connection is the fast path; this is the backstop for a
					-- game that swaps the character (which drops the connection) or
					-- re-seats without firing the event
					standUp(humanoid)
					timer = 0
				elseif timer > 0 then
					timer -= 1
				elseif pathFinder.Failed or not processor or not isPathValid(pathFinder, processor.Index) or processor.OffPath > 20 then
					nextGoal()
				elseif walkPath(pathFinder, processor) then
					nextGoal()
				else
					local waypoint = pathFinder.Waypoints[processor.Index]
					local offset = waypoint.Position - root.Position
					processor.OffPath = Vector3.new(offset.X, 0, offset.Z).Magnitude > 25 and processor.OffPath + 1 or 0
				end
			end

			task.wait(tick)
		until not AntiAFK.Enabled

		cleanup()

		if entitylib.isAlive then
			entitylib.character.Humanoid:MoveTo(entitylib.character.RootPart.Position)
		end
	end,
	Tooltip = 'Walks around with the pathfinder so the game never registers you as idle.'
})
Options = {
	Range = AntiAFK:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 64,
		Default = 16,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	}),
	WaitTime = AntiAFK:CreateSlider({
		Name = 'Wait Time',
		Min = 0,
		Max = 60,
		Default = 2.5,
		Decimal = 20,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end
	}),
	WaitRandom = AntiAFK:CreateSlider({
		Name = 'Wait Random',
		Min = 0,
		Max = 60,
		Default = 0.5,
		Decimal = 20,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end
	})
}
Range, WaitTime, WaitRandom = Options.Range, Options.WaitTime, Options.WaitRandom
Visuals = AntiAFK:CreateToggle({
	Name = 'Visuals',
	Default = true,
	Tooltip = 'Draw the path, its waypoints and the forward prediction.'
})
PathColor = AntiAFK:CreateColorSlider({
	Name = 'Path Color',
	Function = function()
		pathColor = Color3.fromHSV(PathColor.Hue, PathColor.Sat, PathColor.Value)
	end
})
NodeColor = AntiAFK:CreateColorSlider({
	Name = 'Node Color',
	Function = function()
		nodeColor = Color3.fromHSV(NodeColor.Hue, NodeColor.Sat, NodeColor.Value)
	end
})
ShowWaypoints = AntiAFK:CreateToggle({
	Name = 'Waypoints',
	Default = true,
	Tooltip = 'Draw a dot on every path waypoint.'
})
ShowPrediction = AntiAFK:CreateToggle({
	Name = 'Prediction',
	Default = true,
	Function = function(callback)
		if not PredictionLength then return end
		PredictionLength.Object.Visible = callback
		PredictionBranches.Object.Visible = callback
	end,
	Tooltip = 'Preview the routes the next goal could come from.'
})
PredictionLength = AntiAFK:CreateSlider({
	Name = 'Prediction Length',
	Min = 1,
	Max = 12,
	Default = 6,
	Darker = true,
	Visible = false,
	Tooltip = 'How many future steps each prediction extends.'
})
PredictionBranches = AntiAFK:CreateSlider({
	Name = 'Prediction Lines',
	Min = 1,
	Max = 4,
	Default = 3,
	Darker = true,
	Visible = false,
	Tooltip = 'How many routes are drawn around you at once.\nOne of them is picked at random as the next goal.'
})
PredictionLength.Object.Visible = ShowPrediction.Enabled
PredictionBranches.Object.Visible = ShowPrediction.Enabled
