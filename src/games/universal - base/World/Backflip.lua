local Backflip
local Flips

local flip = {
	Active = false,
	Elapsed = 0,
	Duration = 0,
	Start = CFrame.identity,
	Gyro = nil,
	Humanoid = nil,
	Root = nil
}

local function endFlip()
	if flip.Gyro then
		flip.Gyro:Destroy()
	end

	if flip.Humanoid then
		flip.Humanoid.AutoRotate = true
		pcall(flip.Humanoid.SetStateEnabled, flip.Humanoid, Enum.HumanoidStateType.FallingDown, true)
	end

	flip.Active = false
	flip.Gyro, flip.Humanoid, flip.Root = nil, nil, nil
end

local function startFlip()
	if flip.Active or not entitylib.isAlive then return end

	local humanoid = entitylib.character.Humanoid
	-- how long the jump lasts, the rotation is spread across it
	local duration = workspace.Gravity > 0 and ((2 * humanoid.JumpPower) / workspace.Gravity) - 0.05 or 0
	if duration <= 0 then return end

	local root = entitylib.character.RootPart
	flip.Active = true
	flip.Elapsed = 0
	flip.Duration = duration
	flip.Start = root.CFrame
	flip.Humanoid = humanoid
	flip.Root = root
	pcall(humanoid.SetStateEnabled, humanoid, Enum.HumanoidStateType.FallingDown, false)

	local gyro = Instance.new('BodyGyro')
	gyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
	gyro.P = 1000000
	gyro.D = 500
	gyro.CFrame = root.CFrame
	gyro.Parent = root
	flip.Gyro = gyro
end

-- turns the module back off so the bind can be spammed for more flips
local function finishFlip()
	endFlip()

	if Backflip.Enabled then
		task.defer(Backflip.Toggle, Backflip)
	end
end

Backflip = vape.Categories.World:CreateModule({
	Name = 'Backflip',
	Function = function(callback)
		if callback then
			Backflip:Clean(endFlip)
			Backflip:Clean(inputService.JumpRequest:Connect(startFlip))
			Backflip:Clean(runService.Heartbeat:Connect(function(dt)
				if not flip.Active then return end

				local root, humanoid, gyro = flip.Root, flip.Humanoid, flip.Gyro
				if not entitylib.isAlive or not root.Parent or not gyro.Parent then
					finishFlip()
					return
				end

				humanoid.AutoRotate = false
				flip.Elapsed += dt

				if flip.Elapsed >= flip.Duration then
					finishFlip()
					return
				end

				gyro.CFrame = flip.Start * CFrame.Angles(-math.rad(360 * Flips.Value * (flip.Elapsed / flip.Duration)), 0, 0)
			end))

			-- flipping needs air time, so jump right away instead of waiting for spacebar
			if entitylib.isAlive then
				entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			end
			startFlip()
		end
	end,
	Tooltip = 'Flips your character, disables itself after the flip'
})

Flips = Backflip:CreateSlider({
	Name = 'Flips',
	Min = 1,
	Max = 3,
	Default = 1,
	Tooltip = 'Amount of rotations done per jump'
})
