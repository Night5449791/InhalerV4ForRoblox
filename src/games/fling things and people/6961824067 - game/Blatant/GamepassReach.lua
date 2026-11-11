local GamepassReach

GamepassReach = vape.Categories.Blatant:CreateModule({
	Name = 'Gamepass Reach',
	Function = function(callback)
		if callback then
			local flag

			local function apply()
				if not entitylib.isAlive then return end
				if not flag then
					flag = Instance.new('BoolValue')
					flag.Name = 'FartherReach'
					flag.Parent = lplr
				end

				flag.Value = true
			end

			apply()

			GamepassReach:Clean(function()
				if flag then
					flag:Destroy()
					flag = nil
				end
			end)

			repeat
				apply()
				task.wait(0.5)
			until not GamepassReach.Enabled
		end
	end
})
