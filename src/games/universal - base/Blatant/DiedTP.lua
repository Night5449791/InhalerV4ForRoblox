local DiedTP
local lastDeath

local function trackDeath(entity)
	DiedTP:Clean(entity.Humanoid.Died:Connect(function()
		local root = entity.RootPart
		if root then
			lastDeath = root.CFrame
		end
	end))
end

local function returnToDeath(entity)
	if not lastDeath then return end

	local root = entity.RootPart
	if not root then return end

	root.CFrame = lastDeath
	lastDeath = nil
end

DiedTP = vape.Categories.Blatant:CreateModule({
	Name = 'DiedTP',
	Function = function(callback)
		if callback then
			DiedTP:Clean(entitylib.Events.LocalAdded:Connect(function(entity)
				trackDeath(entity)
				task.defer(returnToDeath, entity)
			end))

			if entitylib.isAlive then
				trackDeath(entitylib.character)
			end
		else
			lastDeath = nil
		end
	end,
	Tooltip = 'Teleports you back to where you died after respawning.'
})
