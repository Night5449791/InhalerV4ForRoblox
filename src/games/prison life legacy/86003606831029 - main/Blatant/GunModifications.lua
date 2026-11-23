local GunModifications
local FireRate
local Spread
local Range
local MaxAmmo
local ReloadTime
local Bullets
local AutoFire
local modified = {}

local function apply(tool)
	if modified[tool] then return end

	local module = tool:FindFirstChild('GunStates')
	if not module then return end

	local suc, states = pcall(require, module)
	if not suc or type(states) ~= 'table' then return end

	modified[tool] = {
		FireRate = states.FireRate,
		Spread = states.Spread,
		Range = states.Range,
		MaxAmmo = states.MaxAmmo,
		ReloadTime = states.ReloadTime,
		Bullets = states.Bullets,
		AutoFire = states.AutoFire
	}

	states.FireRate = FireRate.Value
	states.Spread = Spread.Value
	states.Range = Range.Value
	states.MaxAmmo = MaxAmmo.Value
	states.ReloadTime = ReloadTime.Value
	states.Bullets = Bullets.Value
	states.AutoFire = AutoFire.Enabled
end

local function restore()
	for tool, values in modified do
		local module = tool and tool.Parent and tool:FindFirstChild('GunStates')
		if module then
			local suc, states = pcall(require, module)
			if suc and type(states) == 'table' then
				for key, value in values do
					states[key] = value
				end
			end
		end
	end
	table.clear(modified)
end

local function scan()
	local backpack = lplr:FindFirstChildWhichIsA('Backpack')
	if backpack then
		for _, tool in backpack:GetChildren() do
			if tool:IsA('Tool') then apply(tool) end
		end
	end

	local char = lplr.Character
	if char then
		for _, tool in char:GetChildren() do
			if tool:IsA('Tool') then apply(tool) end
		end
	end
end

GunModifications = vape.Categories.Blatant:CreateModule({
	Name = 'GunModifications',
	Function = function(callback)
		if callback then
			scan()

			local backpack = lplr:FindFirstChildWhichIsA('Backpack')
			GunModifications:Clean(backpack and backpack.ChildAdded:Connect(function(tool)
				if tool:IsA('Tool') then apply(tool) end
			end) or function() end)

			local char = lplr.Character
			GunModifications:Clean(char and char.ChildAdded:Connect(function(tool)
				if tool:IsA('Tool') then apply(tool) end
			end) or function() end)
		else
			restore()
		end
	end,
	Tooltip = 'Modifies local gun handling; damage is server-side'
})
FireRate = GunModifications:CreateSlider({
	Name = 'Fire Rate',
	Min = 0.01,
	Max = 0.5,
	Default = 0.08,
	Decimal = 100
})
Spread = GunModifications:CreateSlider({
	Name = 'Spread',
	Min = 0,
	Max = 50,
	Default = 11
})
Range = GunModifications:CreateSlider({
	Name = 'Range',
	Min = 100,
	Max = 2000,
	Default = 800
})
MaxAmmo = GunModifications:CreateSlider({
	Name = 'Max Ammo',
	Min = 1,
	Max = 200,
	Default = 30
})
ReloadTime = GunModifications:CreateSlider({
	Name = 'Reload Time',
	Min = 0.1,
	Max = 5,
	Default = 2,
	Decimal = 10
})
Bullets = GunModifications:CreateSlider({
	Name = 'Bullets',
	Min = 1,
	Max = 10,
	Default = 1
})
AutoFire = GunModifications:CreateToggle({
	Name = 'Auto Fire',
	Default = true
})
