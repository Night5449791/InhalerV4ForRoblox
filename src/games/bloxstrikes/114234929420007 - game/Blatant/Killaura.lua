local Killaura
local Targets
local Range
local Limit
local OriginalSend

run(function()
	local database = replicatedStorage:FindFirstChild('Database')
	local security = database and database:FindFirstChild('Security')
	local module = security and security:FindFirstChild('Remotes')
	if not module then return end

	local suc, Remotes = pcall(require, module)
	local melee = suc and Remotes.Melee and Remotes.Melee.MeleeAttack
	if not (melee and typeof(melee.Send) == 'function') then return end

	local participantsModule = replicatedStorage:FindFirstChild('Components')
	participantsModule = participantsModule and participantsModule:FindFirstChild('Common')
	participantsModule = participantsModule and participantsModule:FindFirstChild('Participants')

	local Participants
	if participantsModule then
		local ok, value = pcall(require, participantsModule)
		Participants = ok and value or nil
	end

	-- the melee packet is the client's own swing: Direction/Distance describe the ray from the
	-- camera, VictimUserId is the hit player or Participants.BotKey(CombatantId) for a bot, and
	-- Identifier is the knife the swing came from. Copying the packet the game itself sent and
	-- pointing the victim fields at another entity keeps the identifier and the swing name
	-- valid without rebuilding any of it.
	local function victimKey(entity)
		if entity.Player then
			return entity.Player.UserId
		end

		local combatant = entity.Character and entity.Character:GetAttribute('CombatantId')
		if typeof(combatant) ~= 'number' or not Participants then return end

		local ok, key = pcall(Participants.BotKey, combatant)
		return ok and key or nil
	end

	local function send(packet, entity, part)
		local key = victimKey(entity)
		if not key then return end

		local origin = gameCamera.CFrame.Position
		local direction = part.Position - origin

		local copy = table.clone(packet)
		copy.Instance = nil
		copy.VictimUserId = key
		copy.HitPartName = part.Name
		copy.Position = part.Position
		copy.Normal = packet.Normal or Vector3.zero
		copy.Direction = direction
		copy.Distance = direction.Magnitude
		pcall(OriginalSend, copy)
	end

	Killaura = vape.Categories.Blatant:CreateModule({
		Name = 'Killaura',
		Function = function(callback)
			if callback and not OriginalSend then
				OriginalSend = melee.Send
				melee.Send = function(packet)
					local result = OriginalSend(packet)
					if not Killaura.Enabled or type(packet) ~= 'table' then return result end

					local character = entitylib.character
					local origin = character and character.RootPart.Position
					if not origin then return result end

					local list = entitylib.AllPosition({
						Range = Range.Value,
						Part = 'Head',
						Origin = origin,
						Limit = Limit.Value + 1,
						Wallcheck = Targets.Walls.Enabled or nil,
						Players = Targets.Players.Enabled,
						NPCs = Targets.NPCs.Enabled
					})

					for _, entity in list do
						local part = entity.Head
						if part and victimKey(entity) ~= packet.VictimUserId then
							send(packet, entity, part)
						end
					end

					return result
				end
			end

			repeat
				task.wait(1)
			until not Killaura.Enabled or vape.Loaded == nil

			if OriginalSend then
				melee.Send = OriginalSend
				OriginalSend = nil
			end
		end,
		Tooltip = 'Repeats your knife swing on every target in range'
	})

	Targets = Killaura:CreateTargets({
		Players = true,
		NPCs = true
	})
	Range = Killaura:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 30,
		Default = 12,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	Limit = Killaura:CreateSlider({
		Name = 'Max targets',
		Min = 1,
		Max = 6,
		Default = 3
	})
end)
