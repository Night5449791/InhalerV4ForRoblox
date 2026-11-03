VehicleWallbang = vape.Categories.Blatant:CreateModule({
	Name = 'VehicleWallbang',
	Function = function(callback)
		OriginScanner:UpdateIgnore()

		if not pl.ShootParams then return end

		pl.ShootParams.FilterDescendantsInstances = callback and {lplr.Character, workspace.CarContainer} or {lplr.Character}

		if callback then
			VehicleWallbang:Clean(entitylib.Events.LocalAdded:Connect(function()
				task.defer(function()
					if pl.ShootParams then
						pl.ShootParams.FilterDescendantsInstances = {lplr.Character, workspace.CarContainer}
					end
				end)
			end))
		end
	end,
	Tooltip = 'Allow you to shoot through vehicles.'
})
