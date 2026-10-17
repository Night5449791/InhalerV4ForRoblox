local SilentAim
local AutoFire
local AutoFireRate
local Range
local active = false

-- the blaster sends its shot through ReplicatedStorage.Blaster.Remotes.Shoot, with the
-- direction computed on the client. The direction is the only unit sized vector in the
-- call, so it is rewritten on the way out and everything else is passed through: a change
-- in the argument layout can only make the rewrite skip, never break shooting.
local function getTarget()
	local root = lplr.Character and lplr.Character:FindFirstChild('HumanoidRootPart')
	if not root then return end

	local best, bestDistance
	for _, entity in entitylib.List do
		if entity.Targetable and entity.Character and entity.Head and entitylib.isVulnerable(entity) then
			local distance = (entity.Head.Position - root.Position).Magnitude
			if distance <= Range.Value and (not bestDistance or distance < bestDistance) then
				best, bestDistance = entity, distance
			end
		end
	end

	return best
end

SilentAim = vape.Categories.Combat:CreateModule({
	Name = 'SilentAim',
	Function = function(callback)
		if not callback then
			active = false
			return
		end

		local blaster = replicatedStorage:FindFirstChild('Blaster')
		local remotes = blaster and blaster:FindFirstChild('Remotes')
		local shootRemote = remotes and remotes:FindFirstChild('Shoot')

		if not shootRemote then return end
		if typeof(hookmetamethod) ~= 'function' or typeof(getnamecallmethod) ~= 'function' then return end

		active = true

		local oldNamecall
		oldNamecall = hookmetamethod(game, '__namecall', function(self, ...)
			if not active or self ~= shootRemote or getnamecallmethod() ~= 'FireServer' or checkcaller() then
				return oldNamecall(self, ...)
			end

			local entity = getTarget()
			if not entity then
				return oldNamecall(self, ...)
			end

			local args = {...}
			local aim = (entity.Head.Position - gameCamera.CFrame.Position).Unit
			for index, value in args do
				if typeof(value) == 'Vector3' and value.Magnitude > 0.5 and value.Magnitude < 2 then
					args[index] = aim
					break
				end
			end

			return oldNamecall(self, unpack(args))
		end)

		task.spawn(function()
			while active do
				if AutoFire.Enabled and entitylib.isAlive then
					local tool = lplr.Character and lplr.Character:FindFirstChildWhichIsA('Tool')
					if tool and getTarget() then
						tool:Activate()
						task.wait(1 / AutoFireRate.Value)
					else
						task.wait(0.15)
					end
				else
					task.wait(0.25)
				end
			end
		end)
	end,
	Tooltip = 'Redirects the blaster towards the closest target.'
})
Range = SilentAim:CreateSlider({
	Name = 'Range',
	Min = 10,
	Max = 600,
	Default = 300,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end
})
AutoFire = SilentAim:CreateToggle({
	Name = 'AutoFire',
	Function = function(callback)
		AutoFireRate.Object.Visible = callback
	end,
	Tooltip = 'Shoots the held tool as soon as a target is in range.'
})
AutoFireRate = SilentAim:CreateSlider({
	Name = 'Fire rate',
	Min = 1,
	Max = 20,
	Default = 8,
	Darker = true,
	Visible = false,
	Suffix = function(val)
		return val == 1 and 'shot per second' or 'shots per second'
	end
})
