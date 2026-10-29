local AntiTaze
local old, connection

-- the game's handler sits on this remote next to engine ones whose Function is nil, a
-- thread or a number, and hookfunction only accepts a real function
local function tazeConnection()
	for _, conn in getconnections(replicatedStorage.GunRemotes.PlayerTased.OnClientEvent) do
		if typeof(conn.Function) == 'function' then
			return conn
		end
	end
end

local function EntityAdded()
	if old then return end

	repeat
		connection = tazeConnection()
		if not connection then
			task.wait(0.25)
		end
	until connection or not AntiTaze.Enabled

	if not (connection and AntiTaze.Enabled) then return end

	old = hookfunction(connection.Function, function()
		local char = lplr.Character
		lplr:SetAttribute('BackpackEnabled', false)
		if entitylib.isAlive then
			entitylib.character.Humanoid:UnequipTools()
		end

		task.wait(3.5)
		if lplr.Character == char then
			lplr:SetAttribute('BackpackEnabled', true)
		end
	end)
end

AntiTaze = vape.Categories.Blatant:CreateModule({
	Name = 'AntiTaze',
	Function = function(callback)
		if callback then
			AntiTaze:Clean(entitylib.Events.LocalAdded:Connect(function()
				task.spawn(EntityAdded)
			end))
			task.spawn(EntityAdded)
		elseif old then
			if restorefunction then
				pcall(restorefunction, connection.Function)
			else
				pcall(hookfunction, connection.Function, old)
			end

			old = nil
		end
	end,
	Tooltip = 'Prevent you from getting tazed'
})
