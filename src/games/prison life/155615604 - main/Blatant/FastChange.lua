local FastChange
local reqteam = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes"):FindFirstChild("RequestTeamChange")
local ChooseTeam

FastChange = vape.Categories.Blatant:CreateModule({
    Name = 'FastChange',
    Function = function(callback)
        if callback then 
            if ChooseTeam.Value == 'Guards' then
                if lplr.Team == 'Neutral' then
                    reqteam:InvokeServer(game:GetService("Teams"):FindFirstChild("Guards"), 1)
                else
                    task.wait(1)
                    reqteam:InvokeServer(game:GetService("Teams"):FindFirstChild("Neutral"), 1)
                    task.wait(1)
                    reqteam:InvokeServer(game:GetService("Teams"):FindFirstChild("Guards"), 1)
                end                
            elseif ChooseTeam.Value == 'Inmates' then
                if lplr.Team == 'Neutral' then
                    notif('FastChange', 'wait 2s for fadeGui', 2, 'warn')
                    reqteam:InvokeServer(game:GetService("Teams"):FindFirstChild("Inmates"), 1)
                else
                    task.wait(1)
                    reqteam:InvokeServer(game:GetService("Teams"):FindFirstChild("Neutral"), 1)
                    task.wait(1)
                    reqteam:InvokeServer(game:GetService("Teams"):FindFirstChild("Inmates"), 1)
                end   
            end
            FastChange:Toggle()
        end
    end,
    Tooltip = 'not-Automatically switch team'
})

ChooseTeam = FastChange:CreateDropdown({
	Name = 'Team',
	List = {'Guards', 'Inmates'}
})