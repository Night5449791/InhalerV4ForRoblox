local AutoToxic
local GG
local KXUser
local Toggles, Lists, said, dead = {}, {}, {}

local function sendMessage(name, obj, default)
	local tab = Lists[name].ListEnabled
	local custommsg = #tab > 0 and tab[math.random(1, #tab)] or default
	if not custommsg then return end
	if #tab > 1 and custommsg == said[name] then
		repeat 
			task.wait() 
			custommsg = tab[math.random(1, #tab)] 
		until custommsg ~= said[name]
	end
	said[name] = custommsg

	custommsg = custommsg and custommsg:gsub('<obj>', obj or '') or ''
	if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		textChatService.ChatInputBarConfiguration.TargetTextChannel:SendAsync(custommsg)
	else
		replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(custommsg, 'All')
	end
end

local function say(message)
	if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		textChatService.ChatInputBarConfiguration.TargetTextChannel:SendAsync(message)
	else
		replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(message, 'All')
	end
end

-- `.kxusers` is another script's command: it prints who else in the server is running a
-- whitelisted injector, which is the only way to know without asking. Sending it once per
-- module start is enough — it is a query, not a greeting, and repeating it every match
-- would be noise in a chat window everyone reads.
local function sayKXUsers()
	if not KXUser.Enabled then return end

	pcall(say, '.kxusers')
end

AutoToxic = vape.Categories.Utility:CreateModule({
	Name = 'AutoToxic',
	Function = function(callback)
		if callback then
			-- one line as soon as the module is on, so the list is there before the first
			-- fight rather than after somebody asks for it
			task.spawn(sayKXUsers)

			AutoToxic:Clean(vapeEvents.BedwarsBedBreak.Event:Connect(function(bedTable)
				if Toggles.BedDestroyed.Enabled and bedTable.brokenBedTeam.id == lplr:GetAttribute('Team') then
					sendMessage('BedDestroyed', (bedTable.player.DisplayName or bedTable.player.Name), 'how dare you >:( | <obj>')
				elseif Toggles.Bed.Enabled and bedTable.player.UserId == lplr.UserId then
					local team = bedwars.QueueMeta[store.queueType].teams[tonumber(bedTable.brokenBedTeam.id)]
					sendMessage('Bed', team and team.displayName:lower() or 'white', 'nice bed lul | <obj>')
				end
			end))
			AutoToxic:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
				if deathTable.finalKill then
					local killer = playersService:GetPlayerFromCharacter(deathTable.fromEntity)
					local killed = playersService:GetPlayerFromCharacter(deathTable.entityInstance)
					if not killed or not killer then return end
					if killed == lplr then
						if (not dead) and killer ~= lplr and Toggles.Death.Enabled then
							dead = true
							sendMessage('Death', (killer.DisplayName or killer.Name), 'my gaming chair subscription expired :( | <obj>')
						end
					elseif killer == lplr and Toggles.Kill.Enabled then
						sendMessage('Kill', (killed.DisplayName or killed.Name), 'vxp on top | <obj>')
					end
				end
			end))
			AutoToxic:Clean(vapeEvents.MatchEndEvent.Event:Connect(function(winstuff)
				if GG.Enabled then
					pcall(say, 'gg')
				end
				
				local myTeam = bedwars.Store:getState().Game.myTeam
				if myTeam and myTeam.id == winstuff.winningTeamId or lplr.Neutral then
					if Toggles.Win.Enabled then 
						sendMessage('Win', nil, 'yall garbage') 
					end
				end
			end))
		end
	end,
	Tooltip = 'Says a message after a certain action'
})
GG = AutoToxic:CreateToggle({
	Name = 'AutoGG',
	Default = true
})
KXUser = AutoToxic:CreateToggle({
	Name = 'KXUser',
	Default = true,
	Tooltip = 'Says .kxusers once when the module starts, so the chat shows who else is injecting'
})
for _, v in {'Kill', 'Death', 'Bed', 'BedDestroyed', 'Win'} do
	Toggles[v] = AutoToxic:CreateToggle({
		Name = v..' ',
		Function = function(callback)
			if Lists[v] then
				Lists[v].Object.Visible = callback
			end
		end
	})
	Lists[v] = AutoToxic:CreateTextList({
		Name = v,
		Darker = true,
		Visible = false
	})
end