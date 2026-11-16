local AutoSell
local Threshold

local SellRequest
local TravelRequest

local function isBagFull()
	local capacity = StoreController:BagCapacity()
	return PlayerData:InventoryCount() >= math.floor(capacity * (Threshold.Value / 100))
end

local function travel(where)
	local ok, result = pcall(function()
		return TravelRequest:InvokeServer(where)
	end)
	return ok and type(result) == 'table' and result.Ok
end

local function sellAll()
	local ok, result = pcall(function()
		return SellRequest:InvokeServer({Action = 'SellAll'})
	end)
	return ok and type(result) == 'table' and result.Ok and result.Payout or 0
end

AutoSell = vape.Categories.Utility:CreateModule({
	Name = 'AutoSell',
	Function = function(callback)
		if callback then
			SellRequest = SellRequest or Remotes:WaitForChild('SellRequest')
			TravelRequest = TravelRequest or Remotes:WaitForChild('TravelRequest')

			repeat
				if isBagFull() and FishingController:GetState() == 'Idle' then
					travel('Sell')
					task.wait(0.6)
					local payout = sellAll()

					if payout > 0 then
						notif('AutoSell', 'Sold for $'..tostring(math.floor(payout)), 3)
					end

					task.wait(0.4)
					travel('Base')
					task.wait(1)
				end

				task.wait(0.5)
			until not AutoSell.Enabled
		end
	end,
	Tooltip = 'Travels to the sell station and sells everything when the bag is full.'
})
Threshold = AutoSell:CreateSlider({
	Name = 'Bag Threshold',
	Min = 50,
	Max = 100,
	Default = 100,
	Decimal = 1,
	Suffix = '%',
	Tooltip = 'Bag fullness at which AutoSell triggers.'
})
