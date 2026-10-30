local SilentAim
local FOV
local Part
local ShowTarget
local connections = {}

local function disconnectAll()
	for tool, connection in connections do
		connection:Disconnect()
		connections[tool] = nil
	end
end

-- entities carry their target part, so a renamed or missing part degrades to the root
-- instead of erroring inside EntityMouse
local function aimEntity()
	local part = Part.Value
	local entity = entitylib.EntityMouse({
		Range = FOV.Value,
		Part = part,
		Players = true,
		NPCs = true
	})

	if not entity and part ~= 'RootPart' then
		entity = entitylib.EntityMouse({
			Range = FOV.Value,
			Part = 'RootPart',
			Players = true,
			NPCs = true
		})
	end

	return entity
end

SilentAim = vape.Categories.Combat:CreateModule({
	Name = 'SilentAim',
	Function = function(callback)
		disconnectAll()

		if not callback then return end

		repeat
			local tool = redwood.meleeTool()
			if tool and not connections[tool] then
				connections[tool] = tool.Activated:Connect(function()
					if not SilentAim.Enabled then return end

					local entity = aimEntity()
					if not entity then return end
					if not redwood.attack(entity, Part.Value) then return end

					if ShowTarget.Enabled then
						targetinfo.Targets[entity] = os.clock() + 1
					end
				end)
			end

			task.wait(1)
		until not SilentAim.Enabled or vape.Loaded == nil

		disconnectAll()
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
