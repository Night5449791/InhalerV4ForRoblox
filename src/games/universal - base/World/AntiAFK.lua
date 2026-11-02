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
local startPosition, timer, pathFinder, processor, currentWaypoint = nil, 0, nil, nil, nil
local controlsModule, oldMoveFunction, goalsSinceAnchor = nil, nil, 0
local waypoints, predictions, candidates = {}, {}, {}
local lineObjects, nodeObjects, predictionObjects = {}, {}, {}
local rayCheck = RaycastParams.new()

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

	local hit = workspace:Raycast(position + Vector3.new(0, 20, 0), Vector3.new(0, -60, 0), rayCheck)
	if hit and not workspace:Raycast(hit.Position + Vector3.new(0, 3, 0), Vector3.new(0, 5, 0), rayCheck) then
		return hit.Position
	end
end

local function think(finder)
	local root = getRoot()
	if root and finder.Goal then
		local path = pathfindingService:CreatePath({AgentRadius = 2, AgentHeight = 5, AgentCanJump = true, AgentCanClimb = true, WaypointSpacing = 4})
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

local function renderVisuals()
	local pathColor = Color3.fromHSV(PathColor.Hue, PathColor.Sat, PathColor.Value)
	local nodeColor = Color3.fromHSV(NodeColor.Hue, NodeColor.Sat, NodeColor.Value)
	local total = 0

	for index = 1, #waypoints - 1 do
		local line = ensureDrawing(lineObjects, index, 'Line')
		local from, fromVis = gameCamera:WorldToViewportPoint(waypoints[index].Position)
		local to, toVis = gameCamera:WorldToViewportPoint(waypoints[index + 1].Position)
		line.Thickness, line.From, line.To, line.Color = 2, Vector2.new(from.X, from.Y), Vector2.new(to.X, to.Y), pathColor
		line.Visible = (fromVis or toVis) and Visuals.Enabled
	end

	for index = #waypoints, #lineObjects do
		lineObjects[index].Visible = false
	end

	for index = 1, #waypoints do
		local dot = ensureDrawing(nodeObjects, index, 'Circle')
		local position, visible = gameCamera:WorldToViewportPoint(waypoints[index].Position)
		dot.Position, dot.Radius, dot.Color = Vector2.new(position.X, position.Y), 4, nodeColor
		dot.Visible = visible and Visuals.Enabled and ShowWaypoints.Enabled
	end

	for index = #waypoints + 1, #nodeObjects do
		nodeObjects[index].Visible = false
	end

	table.clear(predictions)

	if Visuals.Enabled and ShowPrediction.Enabled then
		local length = math.clamp(PredictionLength.Value, 1, 12)

		for branch, candidate in candidates do
			for index = 1, length do
				predictions[branch] = predictions[branch] or {}
				predictions[branch][index] = candidate.Origin + Vector3.new(math.cos(candidate.Angle), 0, math.sin(candidate.Angle)) * (index * 3)
			end
		end
	end

	for branch = 1, #predictions do
		local highlighted = candidates[branch] and candidates[branch].Chosen
		for index = 1, #predictions[branch] do
			total += 1
			local dot = ensureDrawing(predictionObjects, total, 'Circle')
			local position, visible = gameCamera:WorldToViewportPoint(predictions[branch][index])
			dot.Position, dot.Color = Vector2.new(position.X, position.Y), Color3.fromRGB(255, 40, 40)
			dot.Radius = highlighted and 3 or 2
			dot.Transparency = highlighted and math.clamp(1 - index / #predictions[branch], 0.15, 1) or 0.55
			dot.Visible = visible
		end
	end

	for index = total + 1, #predictionObjects do
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

local function cleanup()
	if controlsModule and oldMoveFunction then
		controlsModule.moveFunction = oldMoveFunction
	end

	controlsModule, oldMoveFunction, currentWaypoint = nil, nil, nil

	startPosition, pathFinder, processor, timer = nil, nil, nil, 0
	table.clear(waypoints)
	table.clear(predictions)
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
