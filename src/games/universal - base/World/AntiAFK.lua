local AntiAFK
local Options
local Range
local WaitTime
local WaitRandom
local ShowWaitTime
local Visuals
local PathColor
local NodeColor
local ShowWaypoints
local ShowPrediction
local PredictionLength
local PredictionBranches
local pathfindingService = cloneref(game:GetService('PathfindingService'))
local tick = 0.05
local startPosition, timer, pathFinder, processor = nil, 0, nil, nil
local waypoints, predictions = {}, {}
local lineObjects, nodeObjects, predictionObjects = {}, {}, {}
local rayCheck = RaycastParams.new()
local controlsModule, oldMoveFunction, currentWaypoint
local candidates = {}
local chosenBranch = 1

local function newPathFinder(goal)
	return {Goal = goal, Done = false, Failed = false, Path = nil, Waypoints = {}}
end

local function getRoot()
	if not entitylib.isAlive then return end
	return entitylib.character.RootPart
end

-- Polar instead of a square: a cube distribution clusters near the centre, so most goals landed close to the
-- anchor and the character kept pacing the same spot. The minimum radius also skips goals we are already on.
local function randomize(base, range)
	if not base then return end

	local angle = math.random() * math.pi * 2
	local distance = range * math.sqrt(0.15 + math.random() * 0.85)
	local height = math.random(0, range * 2) - range

	return base + Vector3.new(math.cos(angle) * distance, height, math.sin(angle) * distance)
end

local function snapToGround(position)
	if not position then return end
	rayCheck.FilterDescendantsInstances = {lplr.Character}
	rayCheck.IgnoreWater = true

	local hit = workspace:Raycast(position + Vector3.new(0, 20, 0), Vector3.new(0, -60, 0), rayCheck)
	if not hit or workspace:Raycast(hit.Position + Vector3.new(0, 3, 0), Vector3.new(0, 5, 0), rayCheck) then return end
	return hit.Position
end

local function setTimer()
	local baseTime = math.floor(WaitTime.Value / tick)
	timer = baseTime + math.max(math.floor((math.random() + math.random() + math.random() - 1.5) * 2 * (WaitRandom.Value / tick)), -baseTime)
end

local function think(finder)
	local root = getRoot()
	if not root or not finder.Goal then finder.Failed = true return end

	local path = pathfindingService:CreatePath({AgentRadius = 2, AgentHeight = 5, AgentCanJump = true, AgentCanClimb = true, WaypointSpacing = 4})
	if not pcall(path.ComputeAsync, path, root.Position, finder.Goal) or path.Status ~= Enum.PathStatus.Success then finder.Failed = true return end

	finder.Path = path
	finder.Done = true
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

local function isPathValid(finder, index)
	local root = getRoot()
	if not root or not finder.Waypoints[index] then return false end
	local waypoint = finder.Waypoints[index].Position
	return (waypoint - Vector3.new(root.Position.X, waypoint.Y, root.Position.Z)).Magnitude < 40
end

local function walkPath(finder, proc)
	local waypoint = finder.Waypoints[proc.Index]
	if not waypoint then return true end
	local root, humanoid = getRoot(), entitylib.character.Humanoid
	if not root then return true end

	if waypoint.Action == Enum.PathWaypointAction.Jump then
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		humanoid.Jump = true
	end

	currentWaypoint = waypoint.Position
	local offset = waypoint.Position - root.Position
	if Vector3.new(offset.X, 0, offset.Z).Magnitude < 5 then
		proc.Index = proc.Index + 1
		proc.OffPath = 0
	end

	return proc.Index > #finder.Waypoints
end

local function trackOffPath(finder, proc)
	local root, waypoint = getRoot(), finder.Waypoints[proc.Index]
	if not root or not waypoint then return end
	local offset = waypoint.Position - root.Position
	proc.OffPath = Vector3.new(offset.X, 0, offset.Z).Magnitude > 25 and proc.OffPath + 1 or 0
end

-- Build the candidate headings the prediction draws AND the walk actually follows. A full 360 spread means the
-- arms cover every direction, so the highlighted arm is a real route rather than a line drawn next to one.
local function buildCandidates()
	table.clear(candidates)

	local root = getRoot()
	if not root then return end

	local branches = math.clamp(PredictionBranches.Value, 1, 4)
	local baseAngle = math.random() * math.pi * 2
	local radius = Range.Value

	-- Full circle: the arms ring the character so the next goal can be in any direction, not only ahead.
	for branch = 1, branches do
		local angle = baseAngle + (branch - 1) / branches * math.pi * 2
		local guess = root.Position + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local goal = snapToGround(guess)

		candidates[branch] = {Angle = angle, Origin = root.Position, Goal = goal, Chosen = false}
	end
end

-- Re-anchor every few goals. With a single fixed anchor the random ring never moves, so after a while every
-- goal is somewhere the character has already been; drifting the centre keeps the walk covering new ground.
local goalsSinceAnchor = 0

local function nextGoal()
	local root = getRoot()

	goalsSinceAnchor = goalsSinceAnchor + 1
	if root and goalsSinceAnchor >= 4 then
		startPosition = root.Position
		goalsSinceAnchor = 0
	end

	-- Pick one of the previewed arms so the walk follows a line the player can actually see. A failed arm falls
	-- through to the next one instead of throwing the whole pick away.
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
		if candidate and candidate.Goal then
			local finder = newPathFinder(candidate.Goal)
			think(finder)

			if finder.Done then
				chosenBranch = index
				for other, entry in candidates do
					entry.Chosen = other == index
				end

				pathFinder = finder
				processor = {Index = 1, OffPath = 0}
				timer = 0
				formatPath(finder)
				return
			end
		end
	end

	-- every arm failed, so fall back to a plain ring sample
	local goal = snapToGround(randomize(startPosition, Range.Value))
	pathFinder = newPathFinder(goal)
	processor = nil
	timer = 0

	if not goal then return end
	think(pathFinder)

	if pathFinder.Done then
		formatPath(pathFinder)
		processor = {Index = 1, OffPath = 0}
	end
end

local function ensureDrawing(list, index, class)
	local object = list[index]
	if object then return object end

	if vape.ThreadFix then
		setthreadidentity(8)
	end

	object = Drawing.new(class)
	object.Thickness = 1
	object.Transparency = 1
	object.Filled = true
	list[index] = object
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

local function renderVisuals()
	if not Visuals.Enabled then
		for _, line in lineObjects do line.Visible = false end
		for _, dot in nodeObjects do dot.Visible = false end
		for _, dot in predictionObjects do dot.Visible = false end
		return
	end

	local pathColor = Color3.fromHSV(PathColor.Hue, PathColor.Sat, PathColor.Value)
	local nodeColor = Color3.fromHSV(NodeColor.Hue, NodeColor.Sat, NodeColor.Value)

	for index = 1, #waypoints - 1 do
		local line = ensureDrawing(lineObjects, index, 'Line')
		local from, fromVis = gameCamera:WorldToViewportPoint(waypoints[index].Position)
		local to, toVis = gameCamera:WorldToViewportPoint(waypoints[index + 1].Position)
		line.Thickness = 2
		line.From = Vector2.new(from.X, from.Y)
		line.To = Vector2.new(to.X, to.Y)
		line.Color = pathColor
		line.Visible = fromVis or toVis
	end

	for index = #waypoints, #lineObjects do
		lineObjects[index].Visible = false
	end

	for index = 1, #waypoints do
		local dot = ensureDrawing(nodeObjects, index, 'Circle')
		local position, visible = gameCamera:WorldToViewportPoint(waypoints[index].Position)
		dot.Position = Vector2.new(position.X, position.Y)
		dot.Radius = 4
		dot.Color = nodeColor
		dot.Visible = visible and ShowWaypoints.Enabled
	end

	for index = #waypoints + 1, #nodeObjects do
		nodeObjects[index].Visible = false
	end

	table.clear(predictions)

	if ShowPrediction.Enabled then
		local root = getRoot()

		-- A branch is marked Chosen once nextGoal() has committed to it, so the highlighted line is the route
		-- being walked. Uncommitted arms are still shown as previews of where the next pick could land.
		if root and #candidates > 0 then
			local length = math.clamp(PredictionLength.Value, 1, 12)

			for branch, candidate in candidates do
				for index = 1, length do
					predictions[branch] = predictions[branch] or {}
					predictions[branch][index] = candidate.Origin + Vector3.new(math.cos(candidate.Angle), 0, math.sin(candidate.Angle)) * (index * 3)
				end
			end
		end
	end

	local pathColor = Color3.fromHSV(PathColor.Hue, PathColor.Sat, PathColor.Value)
	local total = 0

	for branch = 1, #predictions do
		local highlighted = candidates[branch] and candidates[branch].Chosen
		for index = 1, #predictions[branch] do
			total = total + 1
			local dot = ensureDrawing(predictionObjects, total, 'Circle')
			local position, visible = gameCamera:WorldToViewportPoint(predictions[branch][index])
			dot.Position = Vector2.new(position.X, position.Y)
			dot.Radius = highlighted and 3 or 2
			dot.Color = pathColor
			dot.Transparency = highlighted and math.clamp(1 - index / #predictions[branch], 0.15, 1) or 0.55
			dot.Visible = visible
		end
	end

	for index = total + 1, #predictionObjects do
		predictionObjects[index].Visible = false
	end
end

local function releaseMove()
	if controlsModule and oldMoveFunction then
		controlsModule.moveFunction = oldMoveFunction
	end

	controlsModule, oldMoveFunction, currentWaypoint = nil, nil, nil
end

local function installMove()
	if controlsModule then return end
	if not pcall(function()
		controlsModule = require(lplr.PlayerScripts.PlayerModule).controls
	end) or not controlsModule or not controlsModule.moveFunction then
		controlsModule = nil
		return
	end

	oldMoveFunction = controlsModule.moveFunction
	controlsModule.moveFunction = function(self, vec, face)
		local root = currentWaypoint and getRoot()
		if root then
			local direction = currentWaypoint - root.Position
			local flat = Vector3.new(direction.X, 0, direction.Z)
			if flat.Magnitude > 0.05 then
				vec = flat.Unit
			end
		end

		return oldMoveFunction(self, vec, face)
	end
end

AntiAFK = vape.Categories.World:CreateModule({
	Name = 'AntiAFK',
	Function = function(callback)
		if callback then
			startPosition = getRoot() and getRoot().Position
			timer = 0
			nextGoal()
			installMove()
			AntiAFK:Clean(runService.RenderStepped:Connect(renderVisuals))

			repeat
				local root, humanoid = getRoot(), entitylib.isAlive and entitylib.character.Humanoid
				if humanoid and root then
					if humanoid.Health <= 0 then
						AntiAFK:Toggle()
					elseif humanoid:GetState() == Enum.HumanoidStateType.Swimming then
						humanoid.Jump = true
					elseif timer > 0 then
						timer -= 1
					elseif pathFinder.Failed then
						nextGoal()
					elseif processor and (not isPathValid(pathFinder, processor.Index) or processor.OffPath > 20) then
						nextGoal()
					elseif processor then
						if walkPath(pathFinder, processor) then
							nextGoal()
						else
							trackOffPath(pathFinder, processor)
						end
					else
						nextGoal()
					end
				end

				task.wait(tick)
			until not AntiAFK.Enabled

			releaseMove()
			startPosition, pathFinder, processor, timer = nil, nil, nil, 0

			if entitylib.isAlive then
				entitylib.character.Humanoid:MoveTo(entitylib.character.RootPart.Position)
			end

			table.clear(waypoints)
			table.clear(predictions)
			clearDrawings(lineObjects)
			clearDrawings(nodeObjects)
			clearDrawings(predictionObjects)
		else
			releaseMove()
			startPosition, pathFinder, processor, timer = nil, nil, nil, 0
			table.clear(waypoints)
			table.clear(predictions)
			clearDrawings(lineObjects)
			clearDrawings(nodeObjects)
			clearDrawings(predictionObjects)
		end
	end,
	ExtraText = function()
		if not ShowWaitTime.Enabled or timer <= 0 then return '' end
		return '[' .. math.floor(timer * tick * 1000) .. 'ms]'
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
ShowWaitTime = AntiAFK:CreateToggle({
	Name = 'Show Wait Time',
	Default = true,
	Tooltip = 'Show the remaining wait on the module itself.'
})
Visuals = AntiAFK:CreateToggle({
	Name = 'Visuals',
	Default = true,
	Tooltip = 'Draw the path, its waypoints and the forward prediction.'
})
PathColor = AntiAFK:CreateColorSlider({
	Name = 'Path Color',
	Function = function()
		if not AntiAFK.Enabled or not Visuals.Enabled then return end
		local color = Color3.fromHSV(PathColor.Hue, PathColor.Sat, PathColor.Value)
		for _, line in lineObjects do
			line.Color = color
		end
	end
})
NodeColor = AntiAFK:CreateColorSlider({
	Name = 'Node Color',
	Function = function()
		if not AntiAFK.Enabled or not Visuals.Enabled then return end
		local color = Color3.fromHSV(NodeColor.Hue, NodeColor.Sat, NodeColor.Value)
		for _, dot in nodeObjects do
			dot.Color = color
		end
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
