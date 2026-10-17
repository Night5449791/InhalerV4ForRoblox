local Speed
local SpeedValue
local original

-- walk speed only: the other modes move the root part and spike AssemblyLinearVelocity,
-- which this game reads as a fall (it reports anything above 95 to the server), while a
-- plain WalkSpeed stays under that and only has to deal with the Adonis check, which the
-- base already neuters
Speed = vape.Categories.Blatant:CreateModule({
	Name = 'Speed',
	Function = function(callback)
		if callback then
			original = entitylib.isAlive and entitylib.character.Humanoid.WalkSpeed or 16

			Speed:Clean(runService.PreSimulation:Connect(function()
				if entitylib.isAlive and entitylib.character.Humanoid.WalkSpeed ~= SpeedValue.Value then
					entitylib.character.Humanoid.WalkSpeed = SpeedValue.Value
				end
			end))
		elseif entitylib.isAlive then
			entitylib.character.Humanoid.WalkSpeed = original or 16
		end
	end,
	Tooltip = 'Sets your walk speed instead of moving the character.'
})
SpeedValue = Speed:CreateSlider({
	Name = 'Speed',
	Min = 17,
	Max = 100,
	Default = 30,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end,
	Tooltip = 'Above 95 the game reads your movement as a fall and reports it.'
})
