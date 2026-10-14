-- the same array is written from the toggle, the respawn and the disable path, so one
-- named function covers all three and the respawn path stops building a closure plus a
-- deferred callback per character spawn
local function setWallbangFilter(ignoreCars)
	local shootParams = pl.ShootParams
	if not shootParams then return end

	shootParams.FilterDescendantsInstances = ignoreCars and {lplr.Character, workspace.CarContainer} or {lplr.Character}
end

local function onLocalAdded()
	-- deferred so the controller has finished setting up on the new character first
	task.defer(setWallbangFilter, true)
end

VehicleWallbang = vape.Categories.Blatant:CreateModule({
	Name = 'VehicleWallbang',
	Function = function(callback)
		OriginScanner:UpdateIgnore()

		-- pl is rebuilt in the background on every reinject, so ShootParams can still be
		-- nil here; indexing it would throw and the module would not even stay enabled
		if not pl.ShootParams then return end

		setWallbangFilter(callback)

		if callback then
			VehicleWallbang:Clean(entitylib.Events.LocalAdded:Connect(onLocalAdded))
		end
	end,
	Tooltip = 'Allow you to shoot through vehicles.'
})
