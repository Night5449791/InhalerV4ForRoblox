local LongGrab

-- Grabbing is the game's own verb: the client asks for a grab line to the part it is
-- looking at, and the server attaches it. The exploit here is that the line is not
-- range-checked on the client side of the request, so a longer reach than the game
-- offers still produces a valid line for whatever part the module picked.
local function grabPart(part)
	local remotes = ftap.remotes
	if not remotes or not remotes.createGrabLine then return false end
	if not part then return false end

	return pcall(function()
		remotes.createGrabLine:FireServer(part, part.CFrame)
	end)
end

LongGrab = vape.Categories.Blatant:CreateModule({
	Name = 'Long Grab',
	Function = function(callback)
		if callback then
			-- the bind fires on change; a hold bind sends true while held
			local held = false
			local range = LongGrab.Options['Range']

			LongGrab:Clean(LongGrab.Options['Bind'].Triggered:Connect(function(isDown)
				held = isDown
			end))

			repeat
				if held then
					local target = entitylib.EntityPosition({
						Players = true,
						Part = 'RootPart',
						Range = range.Value
					})

					if target and target.RootPart then
						grabPart(target.RootPart)
					end
				end

				task.wait(0.15)
			until not LongGrab.Enabled
		end
	end
})
LongGrab:CreateSlider({
	Name = 'Range',
	Min = 5,
	Max = 300,
	Default = 80,
	Suffix = 'studs'
})
LongGrab:CreateBind({
	Name = 'Bind',
	Default = {'E'},
	Hold = true
})
