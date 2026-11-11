local FlingAura

FlingAura = vape.Categories.Blatant:CreateModule({
	Name = 'Fling Aura',
	Function = function(callback)
		if callback then
			local range = FlingAura.Options['Range']
			local speed = FlingAura.Options['Speed']
			local setOwner = ftap.remotes and ftap.remotes.setNetworkOwner

			repeat
				setOwner = ftap.remotes and ftap.remotes.setNetworkOwner
				local origin = entitylib.character.RootPart.Position
				local reach = range.Value

				for _, ent in entitylib.List do
					if not FlingAura.Enabled then break end
					if not ent.Targetable or not ent.RootPart then continue end
					if (ent.RootPart.Position - origin).Magnitude > reach then continue end

					local root = ent.RootPart
					pcall(function()
						if setOwner then setOwner:FireServer(root, gameCamera.CFrame) end
						local power = speed.Value * 1e5
						root.AssemblyLinearVelocity = Vector3.new(power, power, power)
						root.AssemblyAngularVelocity = Vector3.new(power, power, power)
					end)
				end

				task.wait(0.1)
			until not FlingAura.Enabled
		end
	end
})
FlingAura:CreateSlider({
	Name = 'Range',
	Min = 5,
	Max = 120,
	Default = 30,
	Suffix = 'studs'
})
FlingAura:CreateSlider({
	Name = 'Speed',
	Min = 1,
	Max = 100,
	Default = 50
})
