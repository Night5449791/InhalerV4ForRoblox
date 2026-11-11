local AntiFog
local Fog
local Smoke
local lightingService = cloneref(game:GetService('Lighting'))

local fogProperties = {
	FogStart = 100000,
	FogEnd = 100000
}

local atmosphereProperties = {
	Density = 0,
	Haze = 0
}

local connections = {}
local saved = setmetatable({}, {__mode = 'k'})
local locked = setmetatable({}, {__mode = 'k'})
local smokeSaved = setmetatable({}, {__mode = 'k'})

local function lock(instance, prop, value)
	local props = saved[instance]
	if not props then
		props = {}
		saved[instance] = props
	end

	if props[prop] == nil then
		props[prop] = instance[prop]
	end

	local active = locked[instance]
	if not active then
		active = {}
		locked[instance] = active
	end

	if active[prop] then return end

	active[prop] = true

	if instance[prop] ~= value then
		instance[prop] = value
	end

	table.insert(connections, instance:GetPropertyChangedSignal(prop):Connect(function()
		if instance[prop] ~= value then
			instance[prop] = value
		end
	end))
end

local function lockAtmosphere(atmosphere)
	for prop, value in atmosphereProperties do
		lock(atmosphere, prop, value)
	end
end

local function startFog()
	for prop, value in fogProperties do
		lock(lightingService, prop, value)
	end

	for _, instance in lightingService:GetChildren() do
		if instance:IsA('Atmosphere') then
			lockAtmosphere(instance)
		end
	end

	table.insert(connections, lightingService.ChildAdded:Connect(function(instance)
		if instance:IsA('Atmosphere') then
			lockAtmosphere(instance)
		end
	end))
end

local function hideSmoke(instance)
	-- named first: Debris churns with pooled ragdolls, so this runs for far more parts than the
	-- clouds it is after and the name is the cheapest thing to reject on. A plain find keeps the
	-- prefix test allocation free, where sub would build a string per part it rejects.
	if instance.Name ~= 'SmokeVoxel' or smokeSaved[instance] or not instance:IsA('BasePart') then return end

	local parent = instance.Parent
	if not parent or parent.Name:find('VoxelSmoke_', 1, true) ~= 1 then return end

	smokeSaved[instance] = {
		CanCollide = instance.CanCollide,
		CanQuery = instance.CanQuery,
		LocalTransparencyModifier = instance.LocalTransparencyModifier
	}

	instance.CanCollide = false
	instance.CanQuery = false
	instance.LocalTransparencyModifier = 1
end

local function watchDebris(debris)
	for _, instance in debris:GetDescendants() do
		hideSmoke(instance)
	end

	table.insert(connections, debris.DescendantAdded:Connect(hideSmoke))
end

local function startSmoke()
	local debris = workspace:FindFirstChild('Debris')
	if debris then
		watchDebris(debris)
	end

	-- the folder goes away and comes back with the map, so a fresh one has to be picked up again
	table.insert(connections, workspace.ChildAdded:Connect(function(instance)
		if instance.Name == 'Debris' then
			watchDebris(instance)
		end
	end))
end

local function stop()
	for _, connection in connections do
		connection:Disconnect()
	end

	table.clear(connections)
	table.clear(locked)

	for instance, props in saved do
		if instance.Parent then
			for prop, value in props do
				if instance[prop] ~= value then
					instance[prop] = value
				end
			end
		end
	end

	for instance, props in smokeSaved do
		if instance.Parent then
			instance.CanCollide = props.CanCollide
			instance.CanQuery = props.CanQuery
			instance.LocalTransparencyModifier = props.LocalTransparencyModifier
		end
	end

	table.clear(smokeSaved)
end

local function refresh()
	stop()

	if Fog.Enabled then
		startFog()
	end

	if Smoke.Enabled then
		startSmoke()
	end
end

AntiFog = vape.Categories.Render:CreateModule({
	Name = 'AntiFog',
	Function = function(callback)
		if callback then
			refresh()
		else
			stop()
		end
	end,
	Tooltip = 'Remove fog and smoke clouds'
})
Fog = AntiFog:CreateToggle({
	Name = 'Fog',
	Default = true,
	Function = function()
		if AntiFog.Enabled then
			refresh()
		end
	end
})
Smoke = AntiFog:CreateToggle({
	Name = 'Smoke',
	Default = true,
	Function = function()
		if AntiFog.Enabled then
			refresh()
		end
	end
})
