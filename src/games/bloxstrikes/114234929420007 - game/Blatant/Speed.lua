local Speed
local Value

local runService = game:GetService('RunService')
local inputService = game:GetService('UserInputService')

local w, s, a, d = 0, 0, 0, 0

-- camera-relative movement vector, same convention as the universal calculateMoveVector but
-- self-contained (this chunk does not share the universal scope). Ignores pitch, so the input
-- maps onto the flat ground plane the way the game's own movement does.
local function moveVector()
	local cam = workspace.CurrentCamera
	local cf = cam and cam.CFrame
	if not cf then return Vector3.zero end

	local _, _, _, R00, R01, R02, _, _, R12, _, _, R22 = cf:GetComponents()
	local c, s
	if R12 < 1 and R12 > -1 then
		c, s = R22, R02
	else
		c, s = R00, -R01 * math.sign(R12)
	end

	local x = a + d
	local z = w + s
	local vec = Vector3.new((c * x + s * z), 0, (c * z - s * x)) / math.sqrt(c * c + s * s)
	return vec.Unit == vec.Unit and vec.Unit or Vector3.zero
end

Speed = vape.Categories.Blatant:CreateModule({
	Name = 'Speed',
	Function = function(callback)
		if callback then
			w = inputService:IsKeyDown(Enum.KeyCode.W) and -1 or 0
			s = inputService:IsKeyDown(Enum.KeyCode.S) and 1 or 0
			a = inputService:IsKeyDown(Enum.KeyCode.A) and -1 or 0
			d = inputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0

			for _, v in {'InputBegan', 'InputEnded'} do
				Speed:Clean(inputService[v]:Connect(function(input)
					if inputService:GetFocusedTextBox() then return end

					if input.KeyCode == Enum.KeyCode.W then
						w = v == 'InputBegan' and -1 or 0
					elseif input.KeyCode == Enum.KeyCode.S then
						s = v == 'InputBegan' and 1 or 0
					elseif input.KeyCode == Enum.KeyCode.A then
						a = v == 'InputBegan' and -1 or 0
					elseif input.KeyCode == Enum.KeyCode.D then
						d = v == 'InputBegan' and 1 or 0
					end
				end))
			end

			-- the local rig is an anchored presentation model with no Humanoid, so the only way
			-- to move it is to step its CFrame. RenderStepped lands after the game's own movement
			-- update, so the extra step stays on top of it for the rendered frame.
			Speed:Clean(runService.RenderStepped:Connect(function(dt)
				if not entitylib.isAlive then return end
				local root = entitylib.character.RootPart
				if not root then return end

				local movevec = moveVector()
				if movevec == Vector3.zero then return end

				root.CFrame = root.CFrame + (movevec * Value.Value * dt)
			end))
		end
	end,
	Tooltip = 'Steps your character forward with the movement keys (no physics on this game)'
})
Value = Speed:CreateSlider({
	Name = 'Speed',
	Min = 1,
	Max = 150,
	Default = 50,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end
})
