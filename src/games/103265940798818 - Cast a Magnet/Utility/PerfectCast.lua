local PerfectCast
local Notify

PerfectCast = vape.Categories.Utility:CreateModule({
	Name = 'PerfectCast',
	Function = function(callback)
		if callback then
			PerfectCast:Clean(inputService.InputBegan:Connect(function(input, processed)
				if processed then return end
				if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Gamepad1 then return end
				if not canCast() then return end

				castAndHold(0)

				if Notify.Enabled then
					notif('PerfectCast', 'Released at '..string.format('%.2f', perfectHold(0))..'s', 1)
				end
			end))
		end
	end,
	Tooltip = 'Releases your cast at the perfect meter position every time.'
})
Notify = PerfectCast:CreateToggle({
	Name = 'Notifications',
	Default = true
})
