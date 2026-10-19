local AimAssist
local Targets
local AimAssistMethod
local Sort
local AimSpeed
local Distance
local AngleSlider
local StrafeIncrease
local KillauraTarget
local ClickAim
local moveConst = Vector2.new(1, 0.77) * math.rad(0.5)

local function wrapAngle(num)
	num = num % math.pi
	num -= num >= (math.pi / 2) and math.pi or 0
	num += num < -(math.pi / 2) and math.pi or 0
	return num
end

AimAssist = vape.Categories.Combat:CreateModule({
	Name = 'AimAssist',
	Function = function(callback)
		if not callback then return end

		local cameraMode = AimAssistMethod.Value == 'Camera'
		local mouseScale
		if not cameraMode then
			-- hoisted so the per-frame path never touches UserSettings or allocates a new scale vector
			mouseScale = moveConst * UserSettings():GetService('UserGameSettings').MouseSensitivity
		end

		AimAssist:Clean(runService.Heartbeat:Connect(function(dt)
			local hand = store.hand
			if not entitylib.isAlive or not hand or hand.toolType ~= 'sword' then return end

			local sword = bedwars.SwordController
			if ClickAim.Enabled and (not sword or (tick() - sword.lastSwing) >= 0.4) then return end

			local ent = not KillauraTarget.Enabled and entitylib.EntityPosition({
				Range = Distance.Value,
				Part = 'RootPart',
				Wallcheck = Targets.Walls.Enabled,
				Players = Targets.Players.Enabled,
				NPCs = Targets.NPCs.Enabled,
				Sort = sortmethods[Sort.Value]
			}) or store.KillauraTarget

			local root = ent and ent.RootPart
			local character = entitylib.character
			local characterRoot = character and character.RootPart
			if not root or not characterRoot then return end

			local flatDelta = (root.Position - characterRoot.Position) * Vector3.new(1, 0, 1)
			local deltaMagnitude = flatDelta.Magnitude
			if deltaMagnitude < 0.001 then return end

			local localfacing = characterRoot.CFrame.LookVector * Vector3.new(1, 0, 1)
			if math.acos(math.clamp(localfacing:Dot(flatDelta / deltaMagnitude), -1, 1)) >= (math.rad(AngleSlider.Value) / 2) then return end

			targetinfo.Targets[ent] = os.clock() + 1

			local alpha = math.min((AimSpeed.Value + (StrafeIncrease.Enabled and (inputService:IsKeyDown(Enum.KeyCode.A) or inputService:IsKeyDown(Enum.KeyCode.D)) and 10 or 0)) * dt, 1)
			local camCF = gameCamera.CFrame

			if cameraMode then
				-- mobile method - only the local camera CFrame is written, no mouse input at all
				gameCamera.CFrame = camCF:Lerp(CFrame.lookAt(camCF.Position, root.Position), alpha)
			else
				local origin = camCF.Position
				local target = (root.Position - origin).Unit
				target = target == target and target or Vector3.zero
				if target == Vector3.zero then return end

				local facing = camCF.LookVector
				local diffYaw = wrapAngle(math.atan2(facing.X, facing.Z) - math.atan2(target.X, target.Z))
				local diffPitch = math.asin(facing.Y) - math.asin(target.Y)
				local move = Vector2.new(diffYaw, diffPitch) // mouseScale

				move *= alpha

				if typeof(mousemoverel) == 'function' then
					mousemoverel(move.X, move.Y)
				end
			end
		end))
	end,
	Tooltip = 'Smoothly aims to closest valid target with sword'
})
Targets = AimAssist:CreateTargets({
	Players = true,
	Walls = true
})
AimAssistMethod = AimAssist:CreateDropdown({
	Name = 'Method',
	List = {'Camera', 'Mouse'},
	Function = function()
		if AimAssist.Enabled then
			AimAssist:Toggle()
			AimAssist:Toggle()
		end
	end,
	Tooltip = 'Camera lerps the camera CFrame, which works on mobile and sends no mouse input.\nMouse moves the cursor with mousemoverel'
})
local methods = {'Damage', 'Distance'}
for i in sortmethods do
	if not table.find(methods, i) then
		table.insert(methods, i)
	end
end
Sort = AimAssist:CreateDropdown({
	Name = 'Target Mode',
	List = methods
})
AimSpeed = AimAssist:CreateSlider({
	Name = 'Aim Speed',
	Min = 1,
	Max = 20,
	Default = 6
})
Distance = AimAssist:CreateSlider({
	Name = 'Distance',
	Min = 1,
	Max = 30,
	Default = 30,
	Suffx = function(val)
		return val == 1 and 'stud' or 'studs'
	end
})
AngleSlider = AimAssist:CreateSlider({
	Name = 'Max angle',
	Min = 1,
	Max = 360,
	Default = 70
})
ClickAim = AimAssist:CreateToggle({
	Name = 'Click Aim',
	Default = true
})
KillauraTarget = AimAssist:CreateToggle({
	Name = 'Use killaura target'
})
StrafeIncrease = AimAssist:CreateToggle({Name = 'Strafe increase'})
