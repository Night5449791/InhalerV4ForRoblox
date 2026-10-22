local AutoJoinGuards
local JoinDelay

-- becoming a guard is a single CopEvent('Join') call, the same one both guard computers send, so
-- the retry is just repeated until the server balances the teams and accepts it
AutoJoinGuards = vape.Categories.Utility:CreateModule({
	Name = 'AutoJoinGuards',
	Function = function(callback)
		if not callback then return end

		repeat
			if not sentence.isTeam(lplr, sentence.Teams.Guards) then
				sentence.fire('CopEvent', 'Join')
			end

			task.wait(JoinDelay.Value)
		until not AutoJoinGuards.Enabled or vape.Loaded == nil
	end,
	Tooltip = 'Joins the guard team through the game cop computer'
})
JoinDelay = AutoJoinGuards:CreateSlider({
	Name = 'Retry delay',
	Min = 1,
	Max = 30,
	Default = 3,
	Suffix = function(val)
		return val == 1 and 'second' or 'seconds'
	end,
	Tooltip = 'The server refuses teams that are not balanced, so the request is repeated'
})
