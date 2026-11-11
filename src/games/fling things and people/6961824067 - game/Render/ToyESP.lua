local ToyESP

local hue, sat, val = 0.5, 1, 1
local boxes = {}

local function paint()
	local colour = Color3.fromHSV(hue, sat, val)
	for _, box in boxes do
		box.Color3 = colour
	end
end

ToyESP = vape.Categories.Render:CreateModule({
	Name = 'Toy ESP',
	Function = function(callback)
		if callback then
			local function partOf(obj)
				if obj:IsA('BasePart') then return obj end

				return obj.PrimaryPart
					or obj:FindFirstChild('Hitbox')
					or obj:FindFirstChildWhichIsA('BasePart')
			end

			local function add(obj)
				if not ToyESP.Enabled or boxes[obj] then return end

				local part = partOf(obj)
				if not part then return end

				local box = Instance.new('BoxHandleAdornment')
				box.Size = part.Size
				box.Adornee = part
				box.AlwaysOnTop = true
				box.ZIndex = 5
				box.Transparency = 0.5
				box.Color3 = Color3.fromHSV(hue, sat, val)
				box.Parent = vape.gui
				boxes[obj] = box
			end

			for obj in ftap.toys do
				add(obj)
			end

			ToyESP:Clean(collectionService:GetInstanceAddedSignal('Toy'):Connect(add))
			ToyESP:Clean(collectionService:GetInstanceAddedSignal('SpawnedToy'):Connect(add))

			repeat
				task.wait(1)

				for obj, box in boxes do
					if not obj.Parent then
						box:Destroy()
						boxes[obj] = nil
					end
				end
			until not ToyESP.Enabled

			for _, box in boxes do
				box:Destroy()
			end

			table.clear(boxes)
		end
	end
})
ToyESP:CreateColorSlider({
	Name = 'Color',
	Default = 500,
	DefaultOpacity = 100,
	Function = function(h, s, v)
		hue, sat, val = h, s, v
		if ToyESP.Enabled then paint() end
	end
})
