local AutoTeam

AutoTeam = vape.Categories.Utility:CreateModule({
	Name = 'AutoTeam',
	Function = function(callback)
		if callback then
			local gui = lplr.PlayerGui:FindFirstChild('TeamsFrame', true)
			if gui then
				for _, holder in gui:GetChildren() do
					if holder.Button.AutoButtonColor then
						firesignal(holder.Button.MouseButton1Click)
						break
					end
				end
			end
		end
	end,
	Tooltip = 'Automatically join a team when joining the server'
})

AutoOnDied = KickExploit:CreateToggle({
	Name = 'OnDied',
	Tooltip = 'Automatically pick team on death'
})

-- firesignal(game:GetService("Players").LocalPlayer.PlayerGui.Home.hud.Topbar.MenuFrame.SwitchTeams.MouseButton1Click) switching neutral imma take note on