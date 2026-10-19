local SilentAim
local FOV
local Part
local ShowTarget

SilentAim = vape.Categories.Combat:CreateModule({
	Name = 'SilentAim',
	Function = function(callback)
		if not callback then return end

		local connected = {}

		repeat
			local tool = redwood.meleeTool()
			if tool and not connected[tool] then
				connected[tool] = true

				SilentAim:Clean(tool.Activated:Connect(function()
					if not SilentAim.Enabled then return end

					local entity = entitylib.EntityMouse({
						Range = FOV.Value,
						Part = Part.Value,
						Players = true,
						NPCs = true
					})

					if not entity or not redwood.attack(entity, Part.Value) then return end

					if ShowTarget.Enabled then
						targetinfo.Targets[entity] = os.clock() + 1
					end
				end))
			end

			task.wait(1)
		until not SilentAim.Enabled or vape.Loaded == nil
	end,
	Tooltip = 'Adds a melee hit on the closest target inside the FOV every time you attack'
})
FOV = SilentAim:CreateSlider({
	Name = 'FOV',
	Min = 0,
	Max = 1000,
	Default = 150
})
Part = SilentAim:CreateDropdown({
	Name = 'Part',
	List = {'Head', 'RootPart'}
})
ShowTarget = SilentAim:CreateToggle({
	Name = 'Show target info'
})
