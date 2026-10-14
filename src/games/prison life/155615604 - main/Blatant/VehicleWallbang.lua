VehicleWallbang = vape.Categories.Blatant:CreateModule({
	Name = 'VehicleWallbang',
	Function = function(callback)
		OriginScanner:UpdateIgnore()

		-- pl is rebuilt in the background on every reinject, so ShootParams can still be
		-- nil here; indexing it would throw and the module would not even stay enabled
		if not pl.ShootParams then return end

		if callback then
			pl.ShootParams.FilterDescendantsInstances = {lplr.Character, workspace.CarContainer}

			VehicleWallbang:Clean(entitylib.Events.LocalAdded:Connect(function()
				task.defer(function()
					if pl.ShootParams then
						pl.ShootParams.FilterDescendantsInstances = {lplr.Character, workspace.CarContainer}
					end
				end)
			end))
		else
			pl.ShootParams.FilterDescendantsInstances = {lplr.Character}
		end
	end,
	Tooltip = 'Allow you to shoot through vehicles.'
})