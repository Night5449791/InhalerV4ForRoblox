local AntiFeature
local Ragdoll

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

AntiFeature = vape.Categories.Utility:CreateModule({
	Name = 'AntiFeature',
	Function = function(callback)
		-- turning the module off restores the state the game expects, whatever the
		-- option says: the option is not a live setting, it is an intent
		if not callback and entitylib.isAlive then
			entitylib.character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
			return
		end

		apply()

		AntiFeature:Clean(entitylib.Events.LocalAdded:Connect(apply))
	end,
	Tooltip = 'Stops the game from disabling your humanoid states'
})

Ragdoll = AntiFeature:CreateToggle({
	Name = 'Anti ragdoll',
	Default = true,
	Function = function()
		apply()
	end,
	Tooltip = 'Prevents you from getting knocked down in a ragdoll state'
})
