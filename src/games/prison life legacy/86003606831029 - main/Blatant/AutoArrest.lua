local AutoArrest
local Range
local HandCheck
local arrestCooldown = 0

AutoArrest = vape.Categories.Blatant:CreateModule({
	Name = 'AutoArrest',
	Function = function(callback)
		if callback then
			repeat
				local clock = os.clock()
				if arrestCooldown < clock and Remotes.arrest then
					local handcuffs = entitylib.isAlive and lplr.Character:FindFirstChild('Handcuffs')
					if not HandCheck.Enabled or handcuffs then
						local entities = entitylib.AllPosition({
							Range = Range.Value,
							Players = true,
							Part = 'RootPart',
							TargetCheck = true
						})

						for _, ent in entities do
							if ent.Character and not ent.Character:GetAttribute('Arrested') then
								local torso = ent.Character:FindFirstChild('Torso') or ent.RootPart
								local suc, result = pcall(function()
									return Remotes.arrest:InvokeServer(torso)
								end)

								if suc and result == true then
									arrestCooldown = clock + 15
									vape:CreateNotification('AutoArrest', 'Arrested '..ent.Player.Name, 5)
								end
								break
							end
						end
					end
				end
				task.wait(0.1)
			until not AutoArrest.Enabled
		end
	end,
	Tooltip = 'Automatically arrests nearby enemies'
})
Range = AutoArrest:CreateSlider({
	Name = 'Range',
	Min = 1,
	Max = 8,
	Default = 6,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end
})
HandCheck = AutoArrest:CreateToggle({
	Name = 'Hand Check',
	Tooltip = 'Only arrest while handcuffs are equipped'
})
