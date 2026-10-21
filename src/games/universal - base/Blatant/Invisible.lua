local Invisible
local Forcefield
local animtrack
local oldcf
local forcefield
local forcefieldOwned
local forcefieldVisible
local rigReady
local isR15
local rigAngle

--rig type and the angle that flips you below the floor never change for a character, so they are rebuilt only on spawn
local function cacheRig()
	local character = entitylib.isAlive and entitylib.character
	local humanoid = character and character.Humanoid

	if not (humanoid and character.RootPart) then
		rigReady = false
		return
	end

	isR15 = humanoid.RigType == Enum.HumanoidRigType.R15
	rigAngle = CFrame.Angles(math.rad(isR15 and 180 or 90), 0, 0)
	rigReady = true
end

local function setWeight(weight)
	if animtrack and animtrack.Parent then
		animtrack:AdjustWeight(weight)
	end
end

local function animationTrickery()
	local animator = rigReady and entitylib.character.Humanoid:FindFirstChildOfClass('Animator')
	if not animator then
		return
	end

	local anim = Instance.new('Animation')
	anim.AnimationId = 'rbxassetid://'..(isR15 and '18665825805' or '215384594')
	animtrack = animator:LoadAnimation(anim)
	animtrack.Priority = Enum.AnimationPriority.Action4
	animtrack:Play(0, 0.001, 0)
	anim:Destroy()

	task.delay(0, function()
		if animtrack and animtrack.Parent then
			animtrack.TimePosition = isR15 and 1.95 or 0.4
		end
	end)
end

local function clearForcefield()
	if not forcefield then
		return
	end

	if forcefieldOwned then
		if forcefield.Parent then
			forcefield:Destroy()
		end
	elseif forcefield.Parent then
		forcefield.Visible = forcefieldVisible ~= false
	end

	forcefield = nil
	forcefieldOwned = nil
	forcefieldVisible = nil
end

local function applyForcefield()
	if not (Forcefield and Forcefield.Enabled and entitylib.isAlive) then
		return
	end

	local character = entitylib.character
	local humanoid = character.Humanoid
	local existing = humanoid:FindFirstChildOfClass('ForceField') or character.Character:FindFirstChildOfClass('ForceField')

	if existing then
		--adopt the game's own shield, a second forcefield on one humanoid is the easiest thing to flag
		forcefield = existing
		forcefieldOwned = false
		forcefieldVisible = existing.Visible
		existing.Visible = false
	else
		local shield = Instance.new('ForceField')
		forcefield = shield
		forcefieldOwned = true
		shield.Visible = false
		shield.Parent = humanoid
	end
end

Invisible = vape.Categories.Blatant:CreateModule({
	Name = 'Invisible',
	Function = function(callback)
		if callback then
			cacheRig()
			animationTrickery()
			applyForcefield()

			oldcf = nil
			local bindKey = httpService:GenerateGUID(true)
			runService:BindToRenderStep(bindKey, 0, function()
				if rigReady and oldcf and entitylib.isAlive then
					local root = entitylib.character.RootPart
					if root.CFrame ~= oldcf then
						root.CFrame = oldcf
					end

					setWeight(0.001)
				end
			end)

			Invisible:Clean(function()
				runService:UnbindFromRenderStep(bindKey)
			end)

			Invisible:Clean(runService.Heartbeat:Connect(function()
				if not rigReady then
					cacheRig()
				end

				if rigReady and entitylib.isAlive then
					local character = entitylib.character
					local root = character.RootPart
					oldcf = root.CFrame
					root.CFrame = (oldcf - Vector3.new(0, character.Humanoid.HipHeight + (root.Size.Y / 2) - 1, 0)) * rigAngle
					setWeight(100)
				end
			end))

			Invisible:Clean(entitylib.Events.LocalAdded:Connect(function(char)
				local animator = char.Humanoid:WaitForChild('Animator', 1)
				if animator and Invisible.Enabled then
					rigReady = false
					forcefield = nil
					forcefieldOwned = nil
					forcefieldVisible = nil
					oldcf = nil
					Invisible:Toggle()
					Invisible:Toggle()
				end
			end))
		else
			rigReady = false

			if animtrack then
				animtrack:Stop()
				animtrack:Destroy()
				animtrack = nil
			end

			clearForcefield()

			if entitylib.isAlive and oldcf then
				entitylib.character.RootPart.CFrame = oldcf
			end
		end
	end,
	Tooltip = 'Turns you invisible.'
})

Forcefield = Invisible:CreateToggle({
	Name = 'Force Field',
	Default = true,
	Tooltip = 'Blocks damage while invisible. Reuses an existing forcefield instead of stacking one, and runs without its shield effect.',
	Function = function(callback)
		if not Invisible.Enabled then
			return
		end

		if callback then
			applyForcefield()
		else
			clearForcefield()
		end
	end
})
