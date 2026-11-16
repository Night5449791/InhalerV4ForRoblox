local AutoUpgrade
local Priority
local UpgradeRequest
local UpgradeConfig

local levelKeys = {
	BaseLuck = 'BaseLuckLevel',
	Rope = 'RopeLevel',
	ReelPower = 'ReelPowerLevel'
}

local function getLevel(upgrade)
	local data = PlayerData.Data
	return data and data[levelKeys[upgrade]] or 1
end

local function tryUpgrade(upgrade)
	local level = getLevel(upgrade)
	local nextLevel = UpgradeConfig.GetLevel(upgrade, level + 1)
	if not nextLevel then return false end

	local cash = PlayerData.Data and PlayerData.Data.Cash or 0
	if cash < nextLevel.Price then return false end

	local ok, result = pcall(function()
		return UpgradeRequest:InvokeServer({Key = upgrade})
	end)

	if ok and type(result) == 'table' and result.Ok then
		notif('AutoUpgrade', upgrade..' upgraded to '..tostring(level + 1), 3)
		return true
	end

	return false
end

AutoUpgrade = vape.Categories.Utility:CreateModule({
	Name = 'AutoUpgrade',
	Function = function(callback)
		if callback then
			UpgradeRequest = UpgradeRequest or Remotes:WaitForChild('UpgradeRequest')
			UpgradeConfig = UpgradeConfig or require(replicatedStorage.Shared.Config.UpgradeConfig)

			repeat
				if PlayerData.Loaded then
					local order = Priority.Value == 'Cash Value' and {'ReelPower', 'Rope', 'BaseLuck'} or UpgradeConfig.Order

					for _, upgrade in order do
						if tryUpgrade(upgrade) then break end
					end
				end

				task.wait(1)
			until not AutoUpgrade.Enabled
		end
	end,
	Tooltip = 'Buys the next upgrade whenever you can afford it.'
})
Priority = AutoUpgrade:CreateDropdown({
	Name = 'Priority',
	List = {'Default', 'Cash Value'},
	Function = function(val)
		if AutoUpgrade.Enabled then
			AutoUpgrade:Toggle()
			AutoUpgrade:Toggle()
		end
	end
})
