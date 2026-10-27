local AutoRejoin

AutoRejoin = vape.Categories.Utility:CreateModule({
	Name = 'AutoRejoin',
	Function = function(callback)
		if callback then
			local rejoinCheck
			AutoRejoin:Clean(guiService.ErrorMessageChanged:Connect(function(str)
				if (str:lower():find('anomalous behavior detected') or not rejoinCheck or guiService:GetErrorCode() ~= Enum.ConnectionError.DisconnectLuaKick) and guiService:GetErrorCode() ~= Enum.ConnectionError.DisconnectConnectionLost and not str:lower():find('ban') then
					rejoinCheck = true

					if playersService.NumPlayers > 1 then
						teleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId)
					else
						teleportService:Teleport(game.PlaceId)
					end
				end
			end))
		end
	end,
	Tooltip = 'Force rejoins the same server if you get disconnected / kicked'
})
