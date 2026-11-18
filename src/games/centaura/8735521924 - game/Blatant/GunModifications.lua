local GunModifications
local MaxDamage
local MinDamage
local AmmoCount
local HeadshotMultiplier
local ReloadSpeed
local FireRate
local Spread
local CrouchSpread
local Recoil
local Penetration
local Range
local ShellsPerShot
local Teamkill
local Weight
local Suppression

local fields = {'MaxDamage', 'MinDamage', 'AmmoCount', 'HeadshotMultiplier', 'ReloadSpeed', 'firerate', 'spread', 'crouchSpread', 'Recoil', 'Penetration', 'Range', 'ShellsPerShot', 'teamkill', 'Weight', 'Suppression'}
local originals = {}

local function modify(settings)
	if not originals[settings] then
		originals[settings] = table.clone(settings)
	end

	settings.MaxDamage = MaxDamage.Value
	settings.MinDamage = MinDamage.Value
	settings.AmmoCount = AmmoCount.Value
	settings.HeadshotMultiplier = HeadshotMultiplier.Value
	settings.ReloadSpeed = ReloadSpeed.Value
	settings.firerate = FireRate.Value
	settings.spread = Spread.Value
	settings.crouchSpread = CrouchSpread.Value
	settings.Recoil = Recoil.Value
	settings.Penetration = Penetration.Value
	settings.Range = Range.Value
	settings.ShellsPerShot = ShellsPerShot.Value
	settings.teamkill = Teamkill.Enabled
	settings.Weight = Weight.Value
	settings.Suppression = Suppression.Value
end

local function apply()
	if not GunModifications.Enabled or not GunSettings then return end
	for _, gunModule in GunSettings:GetChildren() do
		if gunModule:IsA('ModuleScript') then
			local suc, settings = pcall(require, gunModule)
			if suc and type(settings) == 'table' then
				modify(settings)
			end
		end
	end
end

local function restore()
	for settings, data in originals do
		for _, field in fields do
			settings[field] = data[field]
		end
	end
	table.clear(originals)
end

GunModifications = vape.Categories.Blatant:CreateModule({
	Name = 'GunModifications',
	Function = function(callback)
		if callback then
			apply()
			if GunSettings then
				GunModifications:Clean(GunSettings.ChildAdded:Connect(function(gunModule)
					if gunModule:IsA('ModuleScript') then
						local suc, settings = pcall(require, gunModule)
						if suc and type(settings) == 'table' then
							modify(settings)
						end
					end
				end))
			end
		else
			restore()
		end
	end,
	Tooltip = 'Modify the stats of every weapon'
})
MaxDamage = GunModifications:CreateSlider({
	Name = 'Max Damage',
	Min = 0,
	Max = 1000,
	Default = 200,
	Function = apply
})
MinDamage = GunModifications:CreateSlider({
	Name = 'Min Damage',
	Min = 0,
	Max = 1000,
	Default = 200,
	Function = apply
})
AmmoCount = GunModifications:CreateSlider({
	Name = 'Ammo Count',
	Min = 0,
	Max = 500,
	Default = 100,
	Function = apply
})
HeadshotMultiplier = GunModifications:CreateSlider({
	Name = 'Headshot Multiplier',
	Min = 0,
	Max = 10,
	Default = 2,
	Function = apply
})
ReloadSpeed = GunModifications:CreateSlider({
	Name = 'Reload Speed',
	Min = 0,
	Max = 10,
	Default = 0,
	Function = apply
})
FireRate = GunModifications:CreateSlider({
	Name = 'Fire Rate',
	Min = 0,
	Max = 5000,
	Default = 100,
	Function = apply
})
Spread = GunModifications:CreateSlider({
	Name = 'Spread',
	Min = 0,
	Max = 20,
	Default = 0,
	Function = apply
})
CrouchSpread = GunModifications:CreateSlider({
	Name = 'Crouch Spread',
	Min = 0,
	Max = 20,
	Default = 0,
	Function = apply
})
Recoil = GunModifications:CreateSlider({
	Name = 'Recoil',
	Min = 0,
	Max = 50,
	Default = 0,
	Function = apply
})
Penetration = GunModifications:CreateSlider({
	Name = 'Penetration',
	Min = 0,
	Max = 20,
	Default = 5,
	Function = apply
})
Range = GunModifications:CreateSlider({
	Name = 'Range',
	Min = 0,
	Max = 20000,
	Default = 6000,
	Function = apply
})
ShellsPerShot = GunModifications:CreateSlider({
	Name = 'Shells Per Shot',
	Min = 0,
	Max = 50,
	Default = 1,
	Function = apply
})
Teamkill = GunModifications:CreateToggle({
	Name = 'Teamkill',
	Function = apply
})
Weight = GunModifications:CreateSlider({
	Name = 'Weight',
	Min = 0,
	Max = 10,
	Default = 0,
	Function = apply
})
Suppression = GunModifications:CreateSlider({
	Name = 'Suppression',
	Min = 0,
	Max = 50,
	Default = 0,
	Function = apply
})
