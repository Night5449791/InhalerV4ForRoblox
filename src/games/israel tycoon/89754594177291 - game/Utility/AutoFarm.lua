local AutoFarm
local Collect
local Buy
local BuyDelay

local fireTouchInterest = (getgenv and getgenv().firetouchinterest) or _G.firetouchinterest
local itemMap
local itemMapConfig

local function touch(part)
	local hrp = lplr.Character and lplr.Character:FindFirstChild('HumanoidRootPart')
	if not hrp then return end
	if typeof(fireTouchInterest) ~= 'function' then return end

	pcall(fireTouchInterest, hrp, part, 0)
	pcall(fireTouchInterest, hrp, part, 1)
end

local function collectPad(plot)
	if (plot:GetAttribute('PendingCash') or 0) <= 0 then return end

	local cashPad = plot:FindFirstChild('CashPad')
	local pad = cashPad and cashPad:FindFirstChild('Pad')
	if pad then
		touch(pad)
	end
end

local function cheapestAffordable(plot)
	local config = israel.Config
	local buttons = plot:FindFirstChild('Buttons')
	if not config or not buttons then return end

	if itemMapConfig ~= config then
		itemMapConfig = config
		itemMap = {}

		for _, item in config.Items do
			if item.Id and itemMap[item.Id] == nil then
				itemMap[item.Id] = item
			end
		end
	end

	local cash = israel.cash()
	local best, bestPrice

	for _, button in buttons:GetChildren() do
		local id = button.Name:match('^Button_(.+)$')
		local item = id and itemMap[id]
		local price = item and (item.Price or 0)

		if price and price <= cash and (not bestPrice or price < bestPrice) then
			local pad = button:FindFirstChild('Pad')
			if pad then
				best, bestPrice = pad, price
			end
		end
	end

	return best
end

AutoFarm = vape.Categories.Utility:CreateModule({
	Name = 'AutoFarm',
	Function = function(callback)
		if not callback then return end

		local nextBuy = 0

		repeat
			local plot = israel.plot(lplr)
			if plot then
				if Collect.Enabled then
					collectPad(plot)
				end

				if Buy.Enabled and os.clock() >= nextBuy then
					local pad = cheapestAffordable(plot)
					if pad then
						touch(pad)
						nextBuy = os.clock() + (BuyDelay.Value / 60)
					end
				end
			end

			task.wait()
		until not AutoFarm.Enabled
	end,
	Tooltip = 'Collects the cash pad and buys the cheapest upgrade it can afford'
})
Collect = AutoFarm:CreateToggle({
	Name = 'Collect',
	Default = true,
	Tooltip = 'Fires the cash pad touch whenever there is something to collect'
})
Buy = AutoFarm:CreateToggle({
	Name = 'Buy Upgrades',
	Default = true,
	Tooltip = 'Buys the cheapest button you can currently afford'
})
BuyDelay = AutoFarm:CreateSlider({
	Name = 'Buy Delay',
	Min = 1,
	Max = 60,
	Default = 6,
	Tooltip = 'Frames between purchases so the server does not drop them'
})
