local LongGrab

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
