local JoinJobid
local Place
local JobId

local places = {
	['Non-VC'] = 155615604,
	VC = 135564683255158
}

JoinJobid = vape.Categories.World:CreateModule({
	Name = 'JoinJobid',
	Function = function(callback)
		if callback then
			JoinJobid:Toggle()

			local id = (JobId.Value or ''):gsub('%s+', '')
			if id == '' then
				notif('JoinJobid', 'Enter a job id first.', 5, 'warning')
				return
			end

			if id == game.JobId and (places[Place.Value] or game.PlaceId) == game.PlaceId then
				notif('JoinJobid', 'Already in that server.', 5, 'warning')
				return
			end

			notif('JoinJobid', 'Joining '..Place.Value..' server.', 5)
			teleportService:TeleportToPlaceInstance(places[Place.Value] or game.PlaceId, id)
			JobId:SetValue('') -- spent, don't leave it saved to be rejoined by accident
		end
	end,
	Tooltip = 'Teleports into a specific server using its job id\nReinjects after the teleport just like ServerHop does.'
})
Place = JoinJobid:CreateDropdown({
	Name = 'Place',
	List = {'Non-VC', 'VC'},
	Tooltip = 'Non-VC - 155615604\nVC - 135564683255158'
})
JobId = JoinJobid:CreateTextBox({
	Name = 'JobId',
	Placeholder = 'Job id'
})
JoinJobid:CreateButton({
	Name = 'Copy JobId',
	Function = function()
		if not setclipboard then
			notif('JoinJobid', 'Your executor does not support clipboard.', 5, 'warning')
			return
		end

		if game.JobId == '' then
			notif('JoinJobid', 'This server has no job id.', 5, 'warning')
			return
		end

		setclipboard(game.JobId)
		notif('JoinJobid', 'Copied job id.', 5)
	end,
	Tooltip = 'Copies the job id of the server you are currently in'
})
