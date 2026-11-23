local GunModifications
local FireRate
local Bloom
local MaxBloom
local Accuracy
local Range
local Recoil
local modified = {}

local function applyModule(scriptObj)
	if modified[scriptObj] then return end

	local suc, stats = pcall(require, scriptObj)
	if not suc or type(stats) ~= 'table' then return end

	local original = {
		FireRate = stats.FireRate,
		BloomPerShot = stats.BloomPerShot,
		MaxBloom = stats.MaxBloom,
		BaseAccuracy = stats.BaseAccuracy,
		Range = stats.Range
	}
	modified[scriptObj] = original

	stats.FireRate = FireRate.Value
	stats.BloomPerShot = Bloom.Value
	stats.MaxBloom = MaxBloom.Value
	stats.BaseAccuracy = Accuracy.Value
	stats.Range = Range.Value

	if type(stats.RecoilData) == 'table' then
		original.RecoilData = table.clone(stats.RecoilData)
		if Recoil.Enabled then
			for key, value in stats.RecoilData do
				if type(value) == 'number' then
					stats.RecoilData[key] = value * Recoil.Value
				end
			end
		end
	end
end

local function restore()
	for scriptObj, original in modified do
		local suc, stats = pcall(require, scriptObj)
		if suc and type(stats) == 'table' then
			for key, value in original do
				if key ~= 'RecoilData' then
					stats[key] = value
				end
			end

			if original.RecoilData and type(stats.RecoilData) == 'table' then
				table.clear(stats.RecoilData)
				for key, value in original.RecoilData do
					stats.RecoilData[key] = value
				end
			end
		end
	end
	table.clear(modified)
end

GunModifications = vape.Categories.Blatant:CreateModule({
	Name = 'GunModifications',
	Function = function(callback)
		if callback then
			local weapons = replicatedStorage and replicatedStorage:FindFirstChild('Weapons')
			if weapons then
				for _, folder in weapons:GetChildren() do
					if folder:IsA('Folder') then
						for _, scriptObj in folder:GetChildren() do
							if scriptObj:IsA('ModuleScript') then
								applyModule(scriptObj)
							end
						end
					end
				end
			end
		else
			restore()
		end
	end,
	Tooltip = 'Modifies local weapon handling; damage is server-side'
})
FireRate = GunModifications:CreateSlider({
	Name = 'Fire Rate',
	Min = 0.01,
	Max = 1,
	Default = 0.18,
	Decimal = 100
})
Bloom = GunModifications:CreateSlider({
	Name = 'Bloom Per Shot',
	Min = 0,
	Max = 5,
	Default = 0.52,
	Decimal = 100
})
MaxBloom = GunModifications:CreateSlider({
	Name = 'Max Bloom',
	Min = 0,
	Max = 10,
	Default = 1.6,
	Decimal = 10
})
Accuracy = GunModifications:CreateSlider({
	Name = 'Base Accuracy',
	Min = 0,
	Max = 10,
	Default = 0,
	Decimal = 10
})
Range = GunModifications:CreateSlider({
	Name = 'Range',
	Min = 100,
	Max = 3000,
	Default = 1000
})
Recoil = GunModifications:CreateSlider({
	Name = 'Recoil',
	Min = 0,
	Max = 3,
	Default = 1,
	Decimal = 10
})
