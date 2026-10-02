local DiedTP
local deathCFrame

local function getRoot(char)
	if not char then return end
	return char:FindFirstChild('HumanoidRootPart') or char:FindFirstChild('RootPart')
end

local function applyDeathCFrame(char)
	if not char or not deathCFrame then return end

	local root = getRoot(char)
	if not root then return end

	root.CFrame = deathCFrame + Vector3.new(0, 2, 0)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	deathCFrame = nil
end

local function watchCharacter(char)
	if not char then return end

	local humanoid = char:FindFirstChildOfClass('Humanoid')
	if not humanoid then return end

	humanoid.Died:Connect(function()
		local root = getRoot(char)
		if root then
			deathCFrame = root.CFrame
		end
	end)

	if deathCFrame then
		task.defer(applyDeathCFrame, char)
	end
end

DiedTP = vape.Categories.Blatant:CreateModule({
	Name = 'DiedTP',
	Function = function(callback)
		if callback then
			DiedTP:Clean(entitylib.Events.LocalAdded:Connect(function(char)
				watchCharacter(char)
			end))
			DiedTP:Clean(entitylib.Events.LocalRemoved:Connect(function(entity)
				if deathCFrame then return end
				local root = getRoot(entity.Character)
				if root then
					deathCFrame = root.CFrame
				end
			end))

			if entitylib.isAlive then
				watchCharacter(entitylib.character)
			end
		end
	end,
	Tooltip = 'Teleports you back to your last death position when you respawn.'
})
