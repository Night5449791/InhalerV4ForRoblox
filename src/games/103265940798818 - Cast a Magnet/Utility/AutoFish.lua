local AutoFish
local HoldOffset
local RecastDelay

AutoFish = vape.Categories.Utility:CreateModule({
	Name = 'AutoFish',
	Function = function(callback)
		if callback then
			repeat
				if canCast() then
					castAndHold(HoldOffset.Value)

					local deadline = os.clock() + 10
					repeat task.wait(0.05) until FishingController:GetState() == 'Reeling' or os.clock() > deadline

					local reelStart = os.clock()
					while FishingController:GetState() == 'Reeling' and os.clock() - reelStart < 15 do
						FishingAction:FireServer('Tap', currentCastId())
						task.wait(0.1)
					end

					local settle = os.clock() + 5
					repeat task.wait(0.1) until FishingController:GetState() == 'Idle' or os.clock() > settle
					task.wait(RecastDelay.Value)
				end

				task.wait(0.1)
			until not AutoFish.Enabled
		end
	end,
	Tooltip = 'Casts, holds for a perfect meter and reels the magnet back in.'
})
HoldOffset = AutoFish:CreateSlider({
	Name = 'Hold Offset',
	Min = -20,
	Max = 20,
	Default = 0,
	Decimal = 1,
	Suffix = 'ms',
	Tooltip = 'Shifts the perfect hold timing when casts get rejected.'
})
RecastDelay = AutoFish:CreateSlider({
	Name = 'Recast Delay',
	Min = 0.1,
	Max = 3,
	Default = 0.8,
	Decimal = 10,
	Suffix = 's',
	Tooltip = 'Time to wait before casting again.'
})
