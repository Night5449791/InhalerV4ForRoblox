local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LP = Players.LocalPlayer

local Backflip = {
	Enabled = true,
	IsFlipping = false,
	TempConn = nil,
}

local function GetExpectedJumpTime(hum)
	local v0 = hum.JumpPower
	local g = workspace.Gravity
	if g <= 0 then return math.huge end
	return ((2 * v0) / g) - 0.05
end

local function IsAlive()
	local char = LP.Character
	if not char then return false end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return false end
	if hum.Health <= 0 then return false end
	return true
end

UserInputService.JumpRequest:Connect(function()
	if Backflip.IsFlipping then return end
	if not Backflip.Enabled then return end
	if not IsAlive() then return end

	local char = LP.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hum or not hrp then return end

	local totalAirTime = GetExpectedJumpTime(hum)
	if totalAirTime == math.huge or totalAirTime <= 0 then return end

	Backflip.IsFlipping = true
	pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false) end)

	local bodyGyro = Instance.new("BodyGyro")
	bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
	bodyGyro.P = 1000000
	bodyGyro.D = 500
	bodyGyro.CFrame = hrp.CFrame
	bodyGyro.Parent = hrp

	local startCFrame = hrp.CFrame
	local totalRotation = math.rad(360)
	local elapsed = 0

	Backflip.TempConn = RunService.Heartbeat:Connect(function(dt)
		if not char.Parent or not hrp.Parent or not bodyGyro.Parent then
			if Backflip.TempConn then Backflip.TempConn:Disconnect() end
			Backflip.IsFlipping = false
			return
		end
		hum.AutoRotate = false

		elapsed = elapsed + dt

		if elapsed >= totalAirTime then
			if Backflip.TempConn then Backflip.TempConn:Disconnect() end
			bodyGyro:Destroy()
			Backflip.IsFlipping = false
			hum.AutoRotate = true
			pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, not Backflip.Enabled) end)
			return
		end

		local alpha = elapsed / totalAirTime
		local currentAngle = totalRotation * alpha
		bodyGyro.CFrame = startCFrame * CFrame.Angles(-currentAngle, 0, 0)
	end)
end)

return Backflip