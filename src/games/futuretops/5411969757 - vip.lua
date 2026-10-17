-- Futuretops [VIP SERVER]: the place ships a client anti cheat under Lighting, so it is
-- destroyed as soon as the script loads and again whenever the server re-creates it.
-- Everything else is covered by the universal modules and the lobby base.
local vape = shared.vape
local lighting = game:GetService('Lighting')

local function removeAntiCheat()
	local antiCheat = lighting:FindFirstChild('AntiCheat')
	if antiCheat then
		antiCheat:Destroy()
	end
end

removeAntiCheat()
vape:Clean(lighting.ChildAdded:Connect(function(child)
	if child.Name == 'AntiCheat' then
		child:Destroy()
	end
end))
