local DiedTP
local MovementMode
local lastDeath

local function trackDeath(entity)
	entity.Humanoid.Died:Connect(function()
		local root = entity.RootPart
		if root then
			lastDeath = root.CFrame
		end
	end)
end

DiedTP = vape.Categories.Blatant:CreateModule({
	Name = 'DiedTP',
	Function = function(callback)
		if callback then
			if not entitylib.isAlive then
				notif('DiedTP', 'Character missing.', 5, 'warning')
				DiedTP:Toggle()
				return
			end

			if not lastDeath then
				notif('DiedTP', 'No death position recorded.', 5, 'warning')
				DiedTP:Toggle()
				return
			end

			local root = entitylib.character.RootPart
			if entitylib.character.Humanoid.SeatPart then
				entitylib.character.Humanoid.Sit = false
				task.wait(0.1)
			end

			if MovementMode.Value == 'Motor' then
				motorMove(root, lastDeath)
			else
				root.CFrame = lastDeath
			end

			DiedTP:Toggle()
		end
	end,
	Tooltip = 'Teleports you to where you last died.'
})
MovementMode = DiedTP:CreateDropdown({
	Name = 'Movement',
	List = {'CFrame', 'Motor'}
})

if entitylib.isAlive then
	trackDeath(entitylib.character)
end

vape:Clean(entitylib.Events.LocalAdded:Connect(trackDeath))
