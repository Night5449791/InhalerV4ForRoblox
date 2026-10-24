local BulletTracers
local Material
local Color
local Lifetime
local Fade
local DrawingToggle
local drawingobjs = {}
local drawingpool = {}
local POOL_LIMIT = 64

local function acquireLine()
	local line = table.remove(drawingpool)
	if line then
		return line
	end

	line = Drawing.new('Line')
	line.Thickness = 2
	return line
end

local function releaseLine(line)
	line.Visible = false

	if #drawingpool < POOL_LIMIT then
		table.insert(drawingpool, line)
	else
		line:Remove()
	end
end

BulletTracers = vape.Legit:CreateModule({
	Name = 'BulletTracers',
	Function = function(callback)
		if callback then
			TracerHook:Add('BulletTracers', function(...)
				local origin, dir = ...
				local muzzle = vtool and vtool:FindFirstChild('Muzzle')
				if muzzle then
					origin = muzzle.Position
				end

				local velocity = CFrame.lookAt(origin, dir).LookVector * 1000
				local color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
				local endPoint = origin + velocity

				if DrawingToggle.Enabled then
					local line = acquireLine()
					local from, visibleFrom = gameCamera:WorldToViewportPoint(origin)
					local to, visibleTo = gameCamera:WorldToViewportPoint(endPoint)

					line.Color = color
					line.Transparency = 1 - Color.Opacity
					line.From = Vector2.new(from.X, from.Y)
					line.To = Vector2.new(to.X, to.Y)
					line.Visible = visibleFrom and visibleTo
					drawingobjs[line] = {origin, endPoint, os.clock()}

					task.delay(Lifetime.Value, function()
						if not drawingobjs[line] then
							return
						end

						drawingobjs[line] = nil
						releaseLine(line)
					end)
				else
					local obj = Instance.new('Part')
					obj.Size = Vector3.new(0.1, 0.1, velocity.Magnitude)
					obj.CFrame = CFrame.lookAt(origin + (velocity / 2), endPoint)
					obj.CanCollide = false
					obj.CanQuery = false
					obj.Anchored = true
					obj.Material = Enum.Material[Material.Value]
					obj.Color = color
					obj.Transparency = 1 - Color.Opacity
					obj.Parent = workspace

					if Fade.Enabled then
						local tween = tweenService:Create(obj, TweenInfo.new(Lifetime.Value), {
							Transparency = 1
						})

						tween.Completed:Connect(function()
							tween:Destroy()
						end)

						tween:Play()
					end

					task.delay(Lifetime.Value, obj.Destroy, obj)
				end

				return true
			end, 1)

			if DrawingToggle.Enabled then
				BulletTracers:Clean(runService.RenderStepped:Connect(function()
					local clock = os.clock()
					local lifetime = Lifetime.Value
					local opacity = Color.Opacity
					local fade = Fade.Enabled

					for line, data in drawingobjs do
						local from, visibleFrom = gameCamera:WorldToViewportPoint(data[1])
						local to, visibleTo = gameCamera:WorldToViewportPoint(data[2])

						if visibleFrom and visibleTo then
							line.From = Vector2.new(from.X, from.Y)
							line.To = Vector2.new(to.X, to.Y)
							line.Visible = true

							if fade then
								local progress = lifetime > 0 and math.clamp((clock - data[3]) / lifetime, 0, 1) or 1
								line.Transparency = 1 - opacity * (1 - progress)
							end
						else
							line.Visible = false
						end
					end
				end))
			end
		else
			TracerHook:Remove('BulletTracers')
		end
	end,
	Tooltip = 'Allow you to customize bullet tracers.'
})
local materials = {'SmoothPlastic'}
for _, v in Enum.Material:GetEnumItems() do
	if v.Name ~= 'SmoothPlastic' then
		table.insert(materials, v.Name)
	end
end
Material = BulletTracers:CreateDropdown({
	Name = 'Material',
	List = materials
})
Color = BulletTracers:CreateColorSlider({
	Name = 'Tracer Color',
	DefaultOpacity = 0.5
})
Lifetime = BulletTracers:CreateSlider({
	Name = 'Lifetime',
	Min = 0,
	Max = 0.5,
	Default = 0.2,
	Decimal = 10
})
Fade = BulletTracers:CreateToggle({
	Name = 'Fade',
	Default = true
})
DrawingToggle = BulletTracers:CreateToggle({
	Name = 'Drawing',
	Function = function()
		if BulletTracers.Enabled then
			BulletTracers:Toggle()
			BulletTracers:Toggle()
		end
	end
})
