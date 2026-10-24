local KillSound
local Volume
local PitchShift
local sounds = {}

KillSound = vape.Legit:CreateModule({
	Name = 'KillSound',
	Function = function(callback)
		if callback then
			KillSound:Clean(vapeEvents.PlayerKill.Event:Connect(function(plr)
				if plr ~= lplr.Name or #sounds == 0 then
					return
				end

				local sound = Instance.new('Sound')
				sound.SoundId = sounds[math.random(#sounds)]
				sound.PlaybackSpeed = PitchShift.Enabled and 1 + ((0.5 - math.random()) / 10) or 1
				sound.Volume = Volume.Value
				sound.PlayOnRemove = true
				sound.Parent = workspace
				sound:Destroy()
			end))
		end
	end,
	Tooltip = 'Custom kill sound'
})
KillSound:CreateTextList({
	Name = 'Sounds',
	Placeholder = 'sound id (roblox or file path)',
	Function = function(list)
		table.clear(sounds)

		for _, sound in list or {} do
			local asset

			if sound:find('rbxasset', 1, true) then
				asset = sound
			elseif isfile(sound) then
				local success, path = pcall(getcustomasset, sound)
				asset = success and path or nil
			end

			if asset then
				table.insert(sounds, asset)
			end
		end
	end
})
Volume = KillSound:CreateSlider({
	Name = 'Volume',
	Min = 0,
	Max = 2,
	Default = 1,
	Decimal = 10
})
PitchShift = KillSound:CreateToggle({
	Name = 'Pitch Shift'
})
