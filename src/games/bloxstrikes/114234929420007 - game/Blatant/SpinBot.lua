local SpinBot
local Value
local XToggle
local YToggle
local ZToggle

local runService = game:GetService('RunService')

SpinBot = vape.Categories.Blatant:CreateModule({
	Name = 'SpinBot',
	Function = function(callback)
		if callback then
			-- the local rig is an anchored presentation model, so spin it by re-writing its root
			-- CFrame orientation every frame instead of rotating it through physics
			SpinBot:Clean(runService.RenderStepped:Connect(function()
				if not entitylib.isAlive then return end
				local root = entitylib.character.RootPart
				if not root then return end

				local val = math.rad((os.clock() * (20 * Value.Value)) % 360)
				local x, y, z = root.CFrame:ToOrientation()
				root.CFrame = CFrame.new(root.Position) * CFrame.Angles(
					XToggle.Enabled and val or x,
					YToggle.Enabled and val or y,
					ZToggle.Enabled and val or z
				)
			end))
		end
	end,
	Tooltip = 'Makes your character spin around in circles (does not work in first person)'
})
Value = SpinBot:CreateSlider({
	Name = 'Speed',
	Min = 1,
	Max = 100,
	Default = 40
})
XToggle = SpinBot:CreateToggle({
	Name = 'Spin X'
})
YToggle = SpinBot:CreateToggle({
	Name = 'Spin Y',
	Default = true
})
ZToggle = SpinBot:CreateToggle({
	Name = 'Spin Z'
})
