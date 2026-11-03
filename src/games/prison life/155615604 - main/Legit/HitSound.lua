local HitSound
local Volume
local PitchShift
local sounds = {}

HitSound = vape.Legit:CreateModule({
	Name = 'HitSound',
	Function = function(callback)
		if callback then
			local played
			TracerHook:Add('HitSound', function()
				if played or #sounds == 0 then return end

				local part = debug.getstack(4, 13)
				if typeof(part) ~= 'Instance' then return end

				for _, v in entitylib.List do
					if part:IsDescendantOf(v.Character) and entitylib.isVulnerable(v, true) then
						local sound = Instance.new('Sound')
						sound.SoundId = sounds[math.random(#sounds)]
						sound.PlaybackSpeed = PitchShift.Enabled and 1 + ((0.5 - math.random()) / 10) or 1
						sound.Volume = Volume.Value
						sound.PlayOnRemove = true
						sound.Parent = workspace
						sound:Destroy()

						played = task.defer(function()
							played = nil
						end)

						break
					end
				end
			end)
		else
			TracerHook:Remove('HitSound')
		end
	end,
	Tooltip = 'Custom hit sound'
})
HitSound:CreateTextList({
	Name = 'Sounds',
	Placeholder = 'sound id (roblox or file path)',
	Function = function(list)
		table.clear(sounds)

		for _, sound in list or {} do
			if sound:find('rbxasset', 1, true) then
				table.insert(sounds, sound)
			elseif isfile(sound) then
				local success, path = pcall(getcustomasset, sound)
				if success then
					table.insert(sounds, path)
				end
			end
		end
	end
})
Volume = HitSound:CreateSlider({
	Name = 'Volume',
	Min = 0,
	Max = 2,
	Default = 1,
	Decimal = 10
})
PitchShift = HitSound:CreateToggle({
	Name = 'Pitch Shift'
})
