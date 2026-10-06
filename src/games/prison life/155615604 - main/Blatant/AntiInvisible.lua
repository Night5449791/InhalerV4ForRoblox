local AntiInvisible
local AntiLag
local threads = {}
local connections = {}
local allowedAnims = {
	-- default roblox animations
	['http://www.roblox.com/asset/?id=125750702'] = true,
	['http://www.roblox.com/asset/?id=128777973'] = true,
	['http://www.roblox.com/asset/?id=128853357'] = true,
	['http://www.roblox.com/asset/?id=129423030'] = true,
	['http://www.roblox.com/asset/?id=129423131'] = true,
	['http://www.roblox.com/asset/?id=129967390'] = true,
	['http://www.roblox.com/asset/?id=129967478'] = true,
	['http://www.roblox.com/asset/?id=178130996'] = true,
	['http://www.roblox.com/asset/?id=180426354'] = true,
	['http://www.roblox.com/asset/?id=180435571'] = true,
	['http://www.roblox.com/asset/?id=180435792'] = true,
	['http://www.roblox.com/asset/?id=180436148'] = true,
	['http://www.roblox.com/asset/?id=180436334'] = true,
	['http://www.roblox.com/asset/?id=182393478'] = true,
	['http://www.roblox.com/asset/?id=182435998'] = true,
	['http://www.roblox.com/asset/?id=182436842'] = true,
	['http://www.roblox.com/asset/?id=182436935'] = true,
	['http://www.roblox.com/asset/?id=182491037'] = true,
	['http://www.roblox.com/asset/?id=182491065'] = true,
	['http://www.roblox.com/asset/?id=182491248'] = true,
	['http://www.roblox.com/asset/?id=182491277'] = true,
	['http://www.roblox.com/asset/?id=182491368'] = true,
	['http://www.roblox.com/asset/?id=182491423'] = true,
	-- game animations
	['rbxassetid://279227693'] = true,
	['rbxassetid://279229192'] = true,
	['rbxassetid://287112271'] = true,
	['rbxassetid://388723916'] = true,
	['rbxassetid://388726667'] = true,
	['rbxassetid://389472570'] = true,
	['rbxassetid://405194080'] = true,
	['rbxassetid://405212265'] = true,
	['rbxassetid://481088553'] = true,
	['rbxassetid://481089053'] = true,
	['rbxassetid://484200742'] = true,
	['rbxassetid://484926359'] = true,
	['rbxassetid://83690472549256'] = true,
	['rbxassetid://107176344504758'] = true,
	['rbxassetid://111090572475133'] = true,
	['rbxassetid://113267949064300'] = true,
	['rbxassetid://131326339350805'] = true
}

-- UniversalBroadcast / UniversalLagger feed the animator things like
-- 'http=507770677\1<random>\n \n<message>\n \n', every client then fails to
-- resolve it, floods the console and eats fps
local function isValidAnimationId(id)
	if not id or id == '' then return true end

	return id:match('^rbxassetid://%d+$') ~= nil or id:match('^https?://[%w%.]*roblox%.com/asset/%?id=%d+') ~= nil
end

local function AnimationAdded(anim, plr)
	local animation = anim.Animation
	local id = animation and animation.AnimationId
	if allowedAnims[id] or not plr then return end

	-- malformed animation ids (e.g. the UniversalBroadcast spam) cannot be
	-- resolved by the client, flood the console and tank fps. dropping them
	-- here stops the retry loop even when AntiInvisible itself is off.
	if AntiLag.Enabled and not isValidAnimationId(id) then
		Cheats:Flag(plr, 'console lag', 1)
		pcall(anim.Stop, anim, 0)

		if animation then
			pcall(animation.Destroy, animation)
		end

		return
	end

	-- only hide animations that are not part of the game when AntiInvisible is on
	if not AntiInvisible.Enabled then return end

	if threads[anim] then
		task.cancel(threads[anim])
	end

	Cheats:Flag(plr, 'invalid animation', 1)
	threads[anim] = task.spawn(function()
		repeat
			anim:AdjustWeight(0, 0)
			task.wait()
		until not (anim.IsPlaying and AntiInvisible.Enabled)

		threads[anim] = nil
	end)
end

local function EntityAdded(ent)
	local animator = ent.Humanoid:WaitForChild('Animator', 5)
	if not animator then return end

	table.insert(connections, animator.AnimationPlayed:Connect(function(anim)
		AnimationAdded(anim, ent.Player)
	end))

	for _, anim in animator:GetPlayingAnimationTracks() do
		task.spawn(AnimationAdded, anim, ent.Player)
	end
end

local function teardown()
	for i = #connections, 1, -1 do
		connections[i]:Disconnect()
		connections[i] = nil
	end

	for _, v in threads do
		task.cancel(v)
	end

	table.clear(threads)
end

-- (re)connect the AnimationPlayed watchers whenever either feature is on
local function refresh()
	teardown()

	if not (AntiInvisible.Enabled or AntiLag.Enabled) then return end

	table.insert(connections, entitylib.Events.EntityAdded:Connect(EntityAdded))
	for _, v in entitylib.List do
		task.spawn(EntityAdded, v)
	end
end

for _, v in replicatedStorage:QueryDescendants('Animation') do
	allowedAnims[v.AnimationId] = true
end

AntiInvisible = vape.Categories.Blatant:CreateModule({
	Name = 'AntiInvisible',
	Function = function(callback)
		if callback then
			refresh()
		else
			teardown()

			-- AntiLag may still want the watchers up after AntiInvisible turns off
			if AntiLag.Enabled then
				refresh()
			end
		end
	end,
	Tooltip = 'Prevent people from using animations outside of the game\'s scope'
})
AntiLag = AntiInvisible:CreateToggle({
	Name = 'AntiLag',
	Default = false,
	Tooltip = 'Drops malformed animations so they cannot spam your console and drop fps',
	Function = function(callback)
		if callback then
			refresh()
		elseif not AntiInvisible.Enabled then
			teardown()
		end
	end
})