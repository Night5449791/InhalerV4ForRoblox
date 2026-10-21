local GamepassBreaker
local GamepassType
local GamepassId
local GamepassPasses
local GamepassLogger
local gamepassLookup = {}
local gamepassHttp = request or syn and syn.request or http and http.request or http_request
local gamepassTypes = {
	Gamepass = Enum.InfoType.GamePass,
	Product = Enum.InfoType.Product,
	Asset = Enum.InfoType.Asset,
	Bundle = Enum.InfoType.Bundle
}
local gamepassOrder = {'Gamepass', 'Product', 'Asset', 'Bundle'}

local function gamepassDetect(id)
	for _, kind in gamepassOrder do
		local infoType = gamepassTypes[kind]
		if pcall(function()
			return marketplaceService:GetProductInfo(id, infoType)
		end) then
			return kind
		end
	end

	return nil
end

local function gamepassSignal(kind, id)
	if vape.ThreadFix then
		setthreadidentity(8)
	end

	local method, args
	if kind == 'Gamepass' then
		method, args = 'SignalPromptGamePassPurchaseFinished', {lplr, id, true}
	elseif kind == 'Asset' then
		method, args = 'SignalPromptPurchaseFinished', {lplr, id, true}
	elseif kind == 'Bundle' then
		method, args = 'SignalPromptBundlePurchaseFinished', {lplr, id, true}
	else
		method, args = 'SignalPromptProductPurchaseFinished', {lplr.UserId, id, true}
	end

	local suc, func = pcall(function()
		return marketplaceService[method]
	end)

	if not suc or type(func) ~= 'function' then
		return false, method..' is not exposed by this executor'
	end

	local ok, err = pcall(func, marketplaceService, table.unpack(args))
	if not ok then
		return false, err
	end

	return true
end

local function gamepassFake()
	local id = tonumber(GamepassId.Value) or tonumber(GamepassId.Value:match('(%d+)'))
	if not id then
		notif('GamepassBreaker', 'Enter a numeric asset or gamepass id.', 4, 'warning')
		return
	end

	local kind = GamepassType.Value ~= 'Auto' and GamepassType.Value or gamepassDetect(id)
	if not kind then
		notif('GamepassBreaker', 'Could not resolve '..id..' as a gamepass, product, asset or bundle.', 5, 'warning')
		return
	end

	local suc, err = gamepassSignal(kind, id)
	if suc then
		notif('GamepassBreaker', 'Signalled a <font color="#00AA00">'..kind..'</font> purchase for '..id, 4)
	else
		notif('GamepassBreaker', 'Failed : '..tostring(err), 6, 'alert')
	end
end

--only fires for events the executor exposes, hidden marketplace signals are not guaranteed
local function gamepassWatch(name, label)
	local suc, event = pcall(function()
		return marketplaceService[name]
	end)

	if not suc or typeof(event) ~= 'RBXScriptSignal' then
		return
	end

	GamepassBreaker:Clean(event:Connect(function(_, id, purchased)
		if not GamepassLogger.Enabled then
			return
		end

		local text = label..' - '..tostring(id)
		if purchased ~= nil then
			text = text..(purchased and ' (bought)' or ' (closed)')
		end

		notif('GamepassBreaker', text, 3)
	end))
end

local function gamepassRequest(url)
	if gamepassHttp then
		local suc, res = pcall(gamepassHttp, {Url = url, Method = 'GET'})
		return suc and res.Success and res.Body or nil
	end

	local suc, body = pcall(function()
		return game:HttpGet(url)
	end)

	return suc and body or nil
end

local function gamepassRefresh()
	local labels = {}
	local lookup = {}
	local body = gamepassRequest('https://games.roblox.com/v1/games/'..game.PlaceId..'/game-passes?limit=100&sortOrder=Asc')
		or gamepassRequest('https://games.roproxy.com/v1/games/'..game.PlaceId..'/game-passes?limit=100&sortOrder=Asc')

	if body then
		local suc, data = pcall(function()
			return httpService:JSONDecode(body)
		end)

		if suc and type(data) == 'table' and data.gamePasses then
			for _, pass in data.gamePasses do
				local label = pass.name..' ('..pass.id..')'
				labels[#labels + 1] = label
				lookup[label] = {'Gamepass', pass.id}
			end
		end
	end

	local suc, products = pcall(function()
		return marketplaceService:GetDeveloperProductsAsync():GetCurrentPage()
	end)

	if suc and type(products) == 'table' then
		for _, product in products do
			local label = product.Name..' ('..product.ProductId..')'
			labels[#labels + 1] = label
			lookup[label] = {'Product', product.ProductId}
		end
	end

	if #labels == 0 then
		notif('GamepassBreaker', 'Found no gamepasses or products for this place.', 5, 'warning')
		return
	end

	table.sort(labels)
	table.insert(labels, 1, 'None')
	gamepassLookup = lookup
	GamepassPasses:Change(labels)
	notif('GamepassBreaker', 'Loaded '..#labels..' ids.', 3)
end

GamepassBreaker = vape.Categories.Utility:CreateModule({
	Name = 'GamepassBreaker',
	Function = function(callback)
		if callback then
			gamepassWatch('PromptGamePassPurchaseRequested', 'Gamepass requested')
			gamepassWatch('PromptGamePassPurchaseFinished', 'Gamepass finished')
			gamepassWatch('PromptProductPurchaseRequested', 'Product requested')
			gamepassWatch('PromptProductPurchaseFinished', 'Product finished')
			gamepassWatch('PromptPurchaseRequested', 'Asset requested')
			gamepassWatch('PromptPurchaseFinished', 'Asset finished')
			gamepassWatch('PromptBundlePurchaseRequested', 'Bundle requested')
			gamepassWatch('PromptBundlePurchaseFinished', 'Bundle finished')
		end
	end,
	Tooltip = 'Fakes buying gamepasses, it wont srsly work if server no trust client'
})
GamepassType = GamepassBreaker:CreateDropdown({
	Name = 'Type',
	List = {'Auto', 'Gamepass', 'Product', 'Asset', 'Bundle'},
	Tooltip = 'Auto - Resolves the id through GetProductInfo in Gamepass, Product, Asset, Bundle order'
})
GamepassId = GamepassBreaker:CreateTextBox({
	Name = 'ID',
	Placeholder = 'Gamepass or product id'
})
GamepassBreaker:CreateButton({
	Name = 'Fake purchase',
	Function = gamepassFake,
	Tooltip = 'Signals a finished purchase for the id above'
})
GamepassPasses = GamepassBreaker:CreateDropdown({
	Name = 'Passes',
	List = {'None'},
	Tooltip = 'This place\'s gamepasses and developer products, press Refresh to load them',
	Function = function(value)
		local entry = gamepassLookup[value]
		if entry then
			GamepassType:SetValue(entry[1])
			GamepassId:SetValue(tostring(entry[2]))
		end
	end
})
GamepassBreaker:CreateButton({
	Name = 'Refresh ids',
	Function = gamepassRefresh,
	Tooltip = 'Fetches this place\'s gamepasses and developer products'
})
GamepassLogger = GamepassBreaker:CreateToggle({
	Name = 'Logger',
	Default = true,
	Tooltip = 'Logs every marketplace prompt the game makes while the module is enabled'
})
