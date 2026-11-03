local DamageIndicator
local FontOption
local ColorV
local tentity, lentity
local thealth, ttimer = 0, 0
local indi, indipart, indithread

local function renderStepForLoop(startVal, endVal, increment, callback)
	while true do
		if startVal >= endVal then
			callback(endVal)
			return
		end

		if callback(startVal) then
			return
		end

		startVal += increment * runService.RenderStepped:Wait() * 60
	end
end

local function clearIndicator()
	if indithread then
		task.cancel(indithread)
		indithread = nil
	end

	if indipart then
		indipart:Destroy()
		indipart = nil
	end

	indi = nil
end

local function createIndicator(damage, pos)
	if indi and indipart then
		if indithread then
			task.cancel(indithread)
			indithread = nil
		end

		indi.Text = math.ceil((tonumber(indi.Text) or 0) + damage)
		indipart.Position = pos
	else
		clearIndicator()

		indipart = Instance.new('Part')
		indipart.Size = Vector3.zero
		indipart.Position = pos
		indipart.CanCollide = false
		indipart.CanQuery = false
		indipart.Anchored = true
		indipart.Parent = workspace

		local billboard = Instance.new('BillboardGui')
		billboard.Adornee = indipart
		billboard.Size = UDim2.new(15, 250, 15, 250)
		billboard.AlwaysOnTop = true
		billboard.Parent = indipart

		indi = Instance.new('TextLabel')
		indi.BackgroundTransparency = 1
		indi.TextStrokeTransparency = 0
		indi.Size = UDim2.fromScale(1, 0.075)
		indi.Position = UDim2.fromScale(0.5, 0.5)
		indi.AnchorPoint = Vector2.new(0.5, 0.5)
		indi.Text = math.ceil(damage)
		indi.TextColor3 = Color3.fromHSV(ColorV.Hue, ColorV.Sat, ColorV.Value)
		indi.TextScaled = true
		indi.Font = Enum.Font[FontOption.Value]
		indi.Parent = billboard
	end

	indithread = task.spawn(function()
		local sign = math.random() < 0.5 and -1 or 1
		renderStepForLoop(0, 100, 3, function(value)
			local percent = value / 100
			local val0 = tweenService:GetValue(percent, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
			local val1 = tweenService:GetValue(percent, Enum.EasingStyle.Back, Enum.EasingDirection.In)
			local scale = 1 - 0.5 * val1
			indi.Position = UDim2.new(0.5 + 0.125 * val0 * sign, 0, 0.5 + 0.125 * val1, 0)
			indi.Size = UDim2.new(scale, 0, 0.075 * scale * 0.75, 0)
			indi.Rotation = percent ^ 4 * 260 * sign
		end)

		indipart:Destroy()
		indipart = nil
		indi = nil
		indithread = nil
	end)
end

DamageIndicator = vape.Legit:CreateModule({
	Name = 'DamageIndicator',
	Function = function(callback)
		if callback then
			TracerHook:Add('DamageIndicator', function()
				local part = debug.getstack(4, 13)
				if typeof(part) ~= 'Instance' then
					return
				end

				local clock = os.clock()

				for _, v in entitylib.List do
					if part:IsDescendantOf(v.Character) and entitylib.isVulnerable(v, true) then
						if ttimer <= clock or v ~= tentity then
							thealth = v.Health
						end

						tentity = v
						ttimer = clock + 0.5
						break
					end
				end
			end)

			DamageIndicator:Clean(entitylib.Events.EntityUpdated:Connect(function(entity)
				if entity ~= tentity or ttimer <= os.clock() then
					return
				end

				if entity ~= lentity then
					if indi then
						indi.Text = '0'
					end

					lentity = entity
				end

				local head = entity.Head
				if head and thealth > entity.Health then
					createIndicator(thealth - entity.Health, head.Position + Vector3.new(0, 2, 0))
					thealth = entity.Health
				end
			end))
		else
			TracerHook:Remove('DamageIndicator')
			clearIndicator()

			tentity, lentity = nil, nil
			thealth, ttimer = 0, 0
		end
	end,
	Tooltip = 'Add custom damage indicators for gun damage.'
})
local fontitems = {'GothamBlack'}
for _, v in Enum.Font:GetEnumItems() do
	if v.Name ~= 'GothamBlack' then
		table.insert(fontitems, v.Name)
	end
end
FontOption = DamageIndicator:CreateDropdown({
	Name = 'Font',
	List = fontitems,
	Function = function(val)
		if indi then
			indi.Font = Enum.Font[val]
		end
	end
})
ColorV = DamageIndicator:CreateColorSlider({
	Name = 'Color',
	DefaultHue = 0,
	Function = function(hue, sat, val)
		if indi then
			indi.TextColor3 = Color3.fromHSV(hue, sat, val)
		end
	end
})
