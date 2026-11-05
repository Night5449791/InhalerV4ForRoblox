local AntiFeature
local Ragdoll
local GameplayPaused

-- one module, one line in the list: AntiRagdoll used to be its own module beside this
-- one, and two entries that both answer "stop the game disabling my states" is a
-- distinction nobody reads. It is folded in here as an option, and the module carries
-- the name the games remove.
--
-- The module owns the humanoid, the options only record intent: an option toggled while
-- the module is off must not touch the character, which is why every write below goes
-- through `apply` and `apply` asks the module first. A new character starts with the
-- default states, so the states are re-applied on every respawn.
local function apply()
	if not (AntiFeature.Enabled and entitylib.isAlive) then return end

	local humanoid = entitylib.character.Humanoid
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, not Ragdoll.Enabled)
end

-- the loading box is a CoreScript the client drops into `RobloxGui` every time the
-- network stalls, so it has to be caught as it arrives and not just once; the copy
-- already present is destroyed on the same pass, because a paused client can hand it
-- back right after the connection is made
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
		-- turning the module off restores the state the game expects, whatever the
		-- option says: the option is not a live setting, it is an intent
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
