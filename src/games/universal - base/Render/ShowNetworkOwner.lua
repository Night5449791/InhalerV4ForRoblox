local ShowNetworkOwner

ShowNetworkOwner = vape.Categories.Render:CreateModule({
	Name = 'ShowNetworkOwner',
	Function = function(callback)
		if callback then
			settings():GetService("PhysicsSettings").AreOwnersShown = true
		else
			settings():GetService("PhysicsSettings").AreOwnersShown = false
		end
	end,
	Tooltip = 'Shows network owner'
})