local ServerHop
local Sort

ServerHop = vape.Categories.Utility:CreateModule({
	Name = 'ServerHop',
	Function = function(callback)
		if callback then
			ServerHop:Toggle()
			serverHop(nil, Sort.Value)
		end
	end,
	Tooltip = 'Teleports into a unique server'
})
Sort = ServerHop:CreateDropdown({
	Name = 'Sort',
	List = {'Descending', 'Ascending', 'Best Ping'},
	Tooltip = 'Descending - Prefers full servers\nAscending - Prefers empty servers\nBest Ping - Prefers the lowest ping server'
})
ServerHop:CreateButton({
	Name = 'Rejoin Previous Server',
	Function = function()
		notif('ServerHop', shared.vapeserverhopprevious and 'Rejoining previous server...' or 'Cannot find previous server', 5)

		if shared.vapeserverhopprevious then
			teleportService:TeleportToPlaceInstance(game.PlaceId, shared.vapeserverhopprevious)
		end
	end
})