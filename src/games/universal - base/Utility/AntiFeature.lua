local AntiFeature
local Ragdoll
local GameplayPaused

local function apply()
	if not (AntiFeature.Enabled and entitylib.isAlive) then return end

	local humanoid = entitylib.character.Humanoid
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, not Ragdoll.Enabled)
end

local function clearGameplayPaused()
	if not (AntiFeature.Enabled and GameplayPaused.Enabled) then return end

	if not GameplayPaused.Connection then
		GameplayPaused.Connection = coreGui.RobloxGui.ChildAdded:Connect(function(child)
			if child.Name == 'CoreScripts/NetworkPause' then
				child:Destroy()
			end
		end)
		AntiFeature:Clean(GameplayPaused.Connection)
	end

	local paused = coreGui.RobloxGui:FindFirstChild('CoreScripts/NetworkPause')
	if paused then
		paused:Destroy()
	end
end

local function disconnectGameplayPaused()
	if not GameplayPaused.Connection then return end

	GameplayPaused.Connection:Disconnect()
	GameplayPaused.Connection = nil
end

AntiFeature = vape.Categories.Utility:CreateModule({
	Name = 'AntiFeature',
	Function = function(callback)
		if not callback then
			disconnectGameplayPaused()

			if entitylib.isAlive then
				entitylib.character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
			end
			return
		end

		apply()
		clearGameplayPaused()

		AntiFeature:Clean(entitylib.Events.LocalAdded:Connect(apply))
	end,
	Tooltip = 'Stops the game from disabling your humanoid states'
})

Ragdoll = AntiFeature:CreateToggle({
	Name = 'Anti ragdoll',
	Default = true,
	Function = function(callback)
		apply()
	end,
	Tooltip = 'Prevents you from getting knocked down in a ragdoll state'
})

GameplayPaused = AntiFeature:CreateToggle({
	Name = 'Anti gameplay paused',
	Default = false,
	Function = function(callback)
		clearGameplayPaused()

		if not callback then
			disconnectGameplayPaused()
		end
	end,
	Tooltip = 'Removes the box the client shows when a game loads assets too slowly'
})
