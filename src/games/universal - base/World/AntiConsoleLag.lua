local AntiConsoleLag
local Notifications
local Whitelist

-- every animation the game ships counts as safe, same idea as the allowedAnims
-- table in prison life's AntiInvisible
local allowedAnims = {}
local notifyTimer = 0

-- UniversalBroadcast / UniversalLagger feed the animator things like
-- 'http=507770677\1<random>\n \n<message>\n \n', which is not a real asset.
-- every client then tries to resolve it, floods the console and eats the fps,
-- so anything that is not a plain asset id gets killed on arrival
local function isValidAnimationId(id)
	if not id or id == '' then return true end

	return id:match('^rbxassetid://%d+$') ~= nil or id:match('^https?://[%w%.]*roblox%.com/asset/%?id=%d+') ~= nil
end

local function blockAnimation(anim, plr)
	local animation = anim.Animation
	local id = animation and animation.AnimationId

	if isValidAnimationId(id) and (not Whitelist.Enabled or allowedAnims[id]) then return end

	-- dropping the animation itself stops the client from retrying the load
	pcall(anim.Stop, anim, 0)
	pcall(animation.Destroy, animation)

	if not (Notifications.Enabled and plr) then return end

	local now = os.clock()
	if (now - notifyTimer) < 5 then return end

	notifyTimer = now
	notif('AntiConsoleLag', 'Blocked a lagger: '..plr.DisplayName, 5, 'warning')
end

local function EntityAdded(ent)
	if not AntiConsoleLag.Enabled then return end

	local animator = ent.Humanoid:FindFirstChildOfClass('Animator') or ent.Humanoid:WaitForChild('Animator', 5)
	if not animator then return end

	AntiConsoleLag:Clean(animator.AnimationPlayed:Connect(function(anim)
		blockAnimation(anim, ent.Player)
	end))

	for _, anim in animator:GetPlayingAnimationTracks() do
		task.spawn(blockAnimation, anim, ent.Player)
	end
end

for _, anim in replicatedStorage:QueryDescendants('Animation') do
	allowedAnims[anim.AnimationId] = true
end

AntiConsoleLag = vape.Categories.World:CreateModule({
	Name = 'AntiConsoleLag',
	Function = function(callback)
		if callback then
			AntiConsoleLag:Clean(entitylib.Events.EntityAdded:Connect(EntityAdded))
			for _, v in entitylib.List do
				task.spawn(EntityAdded, v)
			end
		end
	end,
	Tooltip = 'Stops malicious animations from spamming your console and dropping fps'
})

Notifications = AntiConsoleLag:CreateToggle({
	Name = 'Notifications',
	Default = true,
	Tooltip = 'Notifies you when someone tries to lag you'
})

Whitelist = AntiConsoleLag:CreateToggle({
	Name = 'Whitelist',
	Default = false,
	Tooltip = 'Only allow animations the game itself uses, blocks custom ones too'
})
