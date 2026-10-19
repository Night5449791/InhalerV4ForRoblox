local AutoPlay
local Delay
local Team

run(function()
	local playerGui = lplr:WaitForChild('PlayerGui')
	local mainGui = playerGui and playerGui:WaitForChild('MainGui', 30)
	local menu = mainGui and mainGui:WaitForChild('Menu', 30)
	local gameplay = mainGui and mainGui:WaitForChild('Gameplay', 30)
	local middle = gameplay and gameplay:WaitForChild('Middle', 30)

	-- the home screen is MainGui.Menu and it is hidden while a match runs, so its visibility is
	-- the queue signal. PressedPlay takes no argument, SelectTeam takes the team name as a plain
	-- string ('Terrorists' / 'Counter-Terrorists'), both straight from the real buttons.
	local teamSelection = middle and middle:WaitForChild('TeamSelection', 30)
	local lastPress, lastTeam = 0, 0

	local function pressPlay()
		if not (menu and menu.Visible) then return end
		if os.clock() - lastPress < Delay.Value then return end

		lastPress = os.clock()
		bloxstrike.send('Player', 'PressedPlay')
	end

	local function selectTeam()
		if Team.Value == 'Auto' then return end
		if not (teamSelection and teamSelection.Visible) then return end
		if os.clock() - lastTeam < 5 then return end
		if lplr:GetAttribute('Team') == Team.Value then return end

		lastTeam = os.clock()
		bloxstrike.send('TeamSelection', 'SelectTeam', Team.Value)
	end

	AutoPlay = vape.Categories.Utility:CreateModule({
		Name = 'AutoPlay',
		Function = function(callback)
			if not callback then return end

			repeat
				pressPlay()
				selectTeam()
				task.wait(0.5)
			until not AutoPlay.Enabled or vape.Loaded == nil
		end,
		Tooltip = 'Presses Play in the lobby and queues the next match for you'
	})
	Delay = AutoPlay:CreateSlider({
		Name = 'Delay',
		Min = 1,
		Max = 30,
		Default = 3,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end
	})
	Team = AutoPlay:CreateDropdown({
		Name = 'Team',
		List = {'Auto', 'Terrorists', 'Counter-Terrorists'},
		Tooltip = 'Only applied while the team selection screen is up, Auto leaves the pick to the game'
	})
end)
