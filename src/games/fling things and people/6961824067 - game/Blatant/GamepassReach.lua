local GamepassReach

-- This game sells reach as a gamepass: the character carries a bool called
-- `FartherReach` and the grab code reads it to decide how far a line may go. The client
-- sets that value on itself, so writing it here is the whole module.
--
-- It is named GamepassReach and not Reach because universal ships a Reach of its own:
-- two modules called Reach in one category would overwrite each other in
-- `vape.Modules`, and the base removes the universal one on load.
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

			-- the game re-creates the flag when it re-evaluates the gamepass, so it is
			-- re-asserted on the same rhythm the grab code uses
			repeat
				apply()
				task.wait(0.5)
			until not GamepassReach.Enabled
		end
	end
})
