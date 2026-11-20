run(function()
	local AutoFire
	local Targets
	local Range
	local ShootDelay
	local mouseClicked
	local clickDelay = os.clock()

	local function isBait(obj)
		local urban = vape.Libraries.urbananticheat
		if urban and typeof(urban.IsBait) == 'function' then
			local suc, result = pcall(urban.IsBait, obj)
			return suc and result == true
		end
		return false
	end

	AutoFire = vape.Categories.Combat:CreateModule({
		Name = 'AutoFire',
		Function = function(callback)
			if callback then
				repeat
					task.wait()
					if mouse1click and (isrbxactive or iswindowactive)() and clickDelay < os.clock() then
						local entity = entitylib.EntityMouse({
							Part = 'Head',
							Range = Range.Value,
							Origin = gameCamera.CFrame.Position,
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled
						})
						if entity and not isBait(entity.Character) then
							targetinfo.Targets[entity] = os.clock() + 1
							if mouseClicked then
								mouse1release()
								clickDelay = os.clock() + ShootDelay.Value
							else
								mouse1press()
							end
							mouseClicked = not mouseClicked
						elseif mouseClicked then
							mouse1release()
							mouseClicked = false
						end
					end
				until not AutoFire.Enabled
			else
				if mouseClicked then mouse1release() end
				mouseClicked = false
			end
		end,
		Tooltip = 'Shoots automatically while a target is in range'
	})
	Targets = AutoFire:CreateTargets({
		Players = true
	})
	Range = AutoFire:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 1000,
		Default = 150,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	ShootDelay = AutoFire:CreateSlider({
		Name = 'Next Shot Delay',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Default = 0.1,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end
	})
end)
