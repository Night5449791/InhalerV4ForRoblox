local PlayerFling

-- The grab system is what makes this game fling: whoever holds a part owns its network,
-- and the server trusts that owner's CFrame. So a fling is a loop that keeps claiming
-- ownership of the target and writes a velocity far past what the game expects; the
-- server replicates the result to everybody, which is the throw.
--
-- The loop has to keep running: the game re-claims ownership on its own rhythm, and one
-- write is undone before it replicates. 0.1s is the source's cadence and it is what the
-- server tolerates without dropping the grab.
local SPIN_CFRAME = CFrame.new(150, 307, 332)

local function primaryOf(obj)
	if not obj then return nil end

	if obj:IsA('BasePart') then return obj end
	if obj.PrimaryPart then return obj.PrimaryPart end

	return obj:FindFirstChild('HumanoidRootPart')
		or obj:FindFirstChild('Head')
		or obj:FindFirstChild('Torso')
		or obj:FindFirstChildWhichIsA('BasePart')
end

local function flingTarget(ent)
	local remotes = ftap.remotes
	if not remotes or not remotes.setNetworkOwner then return false end

	local character = ent and ent.Character
	local root = character and (ent.RootPart or character:FindFirstChild('HumanoidRootPart'))
	if not root then return false end

	pcall(function()
		remotes.setNetworkOwner:FireServer(root, gameCamera.CFrame)
		root.AssemblyLinearVelocity = Vector3.new(0, 1e7, 0)
		root.AssemblyAngularVelocity = Vector3.new(1e7, 1e7, 1e7)
	end)

	return true
end

PlayerFling = vape.Categories.Blatant:CreateModule({
	Name = 'Player Fling',
	Function = function(callback)
		if callback then
			local range = PlayerFling.Options['Range']
			local auto = PlayerFling.Options['Auto']
			local immediate = PlayerFling.Options['Instant']

			repeat
				local target = entitylib.EntityPosition({
					Players = true,
					Part = 'RootPart',
					Range = range.Value
				})

				if target then
					if immediate.Enabled then
						-- one shot: claim, write, and let the server replicate the throw
						flingTarget(target)
					else
						-- keep claiming until the grab drops or the target leaves
						repeat
							flingTarget(target)
							task.wait(0.1)
						until not PlayerFling.Enabled or not auto.Enabled or not target.Character
					end
				end

				task.wait(0.1)
			until not PlayerFling.Enabled
		end
	end
})
PlayerFling:CreateSlider({
	Name = 'Range',
	Min = 1,
	Max = 200,
	Default = 60,
	Suffix = 'studs'
})
PlayerFling:CreateToggle({
	Name = 'Auto',
	Default = true,
	Tooltip = 'Keep flinging whoever comes into range without holding a key'
})
PlayerFling:CreateToggle({
	Name = 'Instant',
	Default = false,
	Tooltip = 'One throw instead of a continuous loop'
})
