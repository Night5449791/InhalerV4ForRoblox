local AntiCarFling
local CarContainer
local CarContainerParent
AntiCarFling = vape.Categories.World:CreateModule({
	Name = 'AntiCarFling',
	Function = function(callback)
		if callback then
			CarContainer = workspace:FindFirstChild('CarContainer')
			if CarContainer then
				CarContainerParent = CarContainer.Parent
				CarContainer.Parent = nil
			end
			notif('AntiCarFling', 'hided cars.', 5, 'alert')
		elseif CarContainer then
			CarContainer.Parent = CarContainerParent
			CarContainer = nil
			CarContainerParent = nil
		end
	end,
	Tooltip = 'just prevents u getting fucked by cars'
})