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
local pathfindingService = cloneref(game:GetService('PathfindingService'))
local tick = 0.05
local startPosition, timer, pathFinder, processor = nil, 0, nil, nil
local waypoints, predictions = {}, {}
local lineObjects, nodeObjects, predictionObjects = {}, {}, {}
local rayCheck = RaycastParams.new()
local controlsModule, oldMoveFunction, currentWaypoint

local function newPathFinder(goal)
	return {Goal = goal, Done = false, Failed = false, Path = nil, Waypoints = {}}
end

local function getRoot()
	if not entitylib.isAlive then return end
	return entitylib.character.RootPart
end

local function randomize(base, range)
	if not base then return end
	return base + Vector3.new(math.random(0, range * 2) - range, math.random(0, range * 2) - range, math.random(0, range * 2) - range)
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

local function nextGoal()
	pathFinder = newPathFinder(snapToGround(randomize(startPosition, Range.Value)))
	processor = nil
	timer = 0

	if not pathFinder.Goal then return end
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
	if ShowPrediction.Enabled and #waypoints > 1 then
		local last, previous = waypoints[#waypoints].Position, waypoints[#waypoints - 1].Position
		local direction = last - previous
		if direction.Magnitude > 0.01 then
			for index = 1, math.clamp(PredictionLength.Value, 1, 12) do
				predictions[index] = last + direction.Unit * (index * 3)
			end
		end
	end

	for index = 1, #predictions do
		local dot = ensureDrawing(predictionObjects, index, 'Circle')
		local position, visible = gameCamera:WorldToViewportPoint(predictions[index])
		dot.Position = Vector2.new(position.X, position.Y)
		dot.Radius = 3
		dot.Color = pathColor
		dot.Transparency = math.clamp(1 - index / #predictions, 0.15, 1)
		dot.Visible = visible
	end

	for index = #predictions + 1, #predictionObjects do
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
		if PredictionLength then
			PredictionLength.Object.Visible = callback
		end
	end,
	Tooltip = 'Continue the last heading forward to preview where the next path will go.'
})
PredictionLength = AntiAFK:CreateSlider({
	Name = 'Prediction Length',
	Min = 1,
	Max = 12,
	Default = 6,
	Darker = true,
	Visible = false,
	Tooltip = 'How many future steps the prediction extends.'
})
PredictionLength.Object.Visible = ShowPrediction.Enabled
