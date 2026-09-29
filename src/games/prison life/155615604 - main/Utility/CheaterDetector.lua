-- we all code for shits lol

local CheaterDetector
local Users

local cUsernames = {
	['WyRaff'] = 'speedhack,teleporting', -- vc server common
	['PraiseDracc'] = 'known exploiter', -- since he is commonly in vc server
	['jerry_plsnoban7'] = 'known exploiter (kerax)', -- cringe
	['jerry_plsnoban6'] = 'known exploiter (kerax)',
	['jerry_plsnoban5'] = 'known exploiter (kerax)',
	['rudeeis_ab'] = 'phase/noclip ahhh hack', -- saint member, dont they even use the same thing
	['JOJI12416'] = 'known exploiter (kerax owner)', -- kerax if u wonder
	['DawnPulseVoid'] = 'known exploiter',
	['BestCode_BaconThx']= 'known exploiter (kerax)',   -- join .gg/prisonlife if u got flagged by this dude, we wanna laugh at u
	['RazhulanDeveloper'] = 'known exploiter (kerax)', -- join .gg/prisonlife if u got flagged by this dude, we wanna laugh at u
	['SaintSkirr'] = 'known exploiter (vape)', -- not a big deal, why kerax just why
	['centipedeinmyheads'] = 'known exploiter (kerax)', -- NOT another saint member lol, kerax user
	-- skids list
	["veggeta38372737"] = "kerax user, abuser", -- most kerax users are skids abusing so, yeah
	['jbskjbg'] = 'invalid state Platform Stand exp',
	['1267_isevil'] = 'failed fling attempt',
	['1987_isevil'] = 'failed fling attempt',
	['HeyiamTheCooolest'] = 'skid exploiter',
	['Chill_baconr00'] = 'highjump', --  using vape v4 from Night5449791 and cant beat me XD
	['gcfhjfjf4'] = 'highjump, aimbot',
	['dannielll51'] = 'headsit exploit', -- inspired, vape antiheadsit soon.
	['Bonjour394'] = 'skid exploiter', -- hes js a jerk
	['princeofegypt'] = 'gets kicked for fling attempt', -- imagine gets kicked for script that kicks
	['bilinmez4095'] = 'invalid state Platform Stand',
	['djdjdd54321'] = 'phase/noclip into walls',
	['cnmjm222'] = 'invisible',
	['oyeuser67'] = 'speedhack',
	['BetterCallMe788'] = 'fling',
	['Avacad0731'] = 'phase/noclip',
	['C0nquerons'] = 'Platform Stand exploit',
	['goobyzoobytv'] = 'phase/noclip',
	['Joni_8824'] = 'phase/noclip',
	['jaycomputing'] = 'skid using selenium larps and got kicked',
	['tooodarl9'] = 'skid exploiter',
	['Henr45555455'] = 'invalid state Platform Stand',
	['Marssimo_14'] = 'invalid state Platform Stand',
	['boy_cantot2'] = 'invalid state Platform Stand',
	['killerdoy372bro'] = 'invalid animation',
	['trervoTDJ'] = 'aimbotting',
	['Pedro9Henrique2000'] = 'phase/noclip',
	["faizan1111789"] = "speed",
	['juanpro231ew'] = "invalid state Swimming",
	["voidwalker5346"] = "invalid animation (car kick)",
	["mchser3"] = "invalid state Swimming",
	["ang5454"] = "highjump",
	['rackasauras'] = 'speed',
	["dobys149"] = "phase/noclip",
	["SyntaxK3v"] = "speed",
	["Thacosmick_2"] = "invalid state Swimming",
	["Unicornpoop1239508"] = "speed",
	["kind_jack001"] = "invalid animation (invis)",
	["lilyazz0000"] = "invalid state PlatformStanding (fly)",
	["nobby_rules2"] = "speed",
	["duimaxxing"] = "phase/noclip",
	['sauodwuansd212'] = 'fling/kickall'
}

local function playerAdded(plr)
	local reason = cUsernames[plr.Name]
	if Users then
		reason = table.find(Users.ListEnabled, tostring(plr.UserId)) or reason
	end

	if reason then
		notif('CheaterDetector', 'Cheater Detected ('..reason..'): '..plr.Name, 60, 'alert')
		whitelist.customtags[plr.Name] = {{text = 'Exploiter', color = Color3.new(1, 0, 0)}}
		tempTargets[plr.Name] = true
	end
end

CheaterDetector = vape.Categories.Utility:CreateModule({
	Name = 'CheaterDetector',
	Function = function(callback)
		if callback then
			CheaterDetector:Clean(playersService.PlayerAdded:Connect(playerAdded))
			for _, v in playersService:GetPlayers() do
				task.spawn(playerAdded, v)
			end
		end
	end,
	Tooltip = 'Detects people with history of cheating',
})