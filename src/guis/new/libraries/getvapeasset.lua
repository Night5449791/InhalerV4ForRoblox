do
	local vapeAssets = {
		['InhalerV4/assets/new/add.png'] = 'rbxassetid://121642387707174',
		['InhalerV4/assets/new/aim.png'] = 'rbxassetid://122207028123421',
		['InhalerV4/assets/new/allowedicon.png'] = 'rbxassetid://112336790299036',
		['InhalerV4/assets/new/allowediconmini.png'] = 'rbxassetid://90142384730147',
		['InhalerV4/assets/new/back.png'] = 'rbxassetid://80523803497740',
		['InhalerV4/assets/new/backmini.png'] = 'rbxassetid://85859225495272',
		['InhalerV4/assets/new/bind.png'] = 'rbxassetid://81399857677684',
		['InhalerV4/assets/new/bindbkg.png'] = 'rbxassetid://101996225428926',
		['InhalerV4/assets/new/blatant.png'] = 'rbxassetid://126929923309265',
		['InhalerV4/assets/new/blur.png'] = 'rbxassetid://79246816170155',
		['InhalerV4/assets/new/blurnoti.png'] = 'rbxassetid://124705876663719',
		['InhalerV4/assets/new/close.png'] = 'rbxassetid://121816018671466',
		['InhalerV4/assets/new/closemini.png'] = 'rbxassetid://108320409341289',
		['InhalerV4/assets/new/closetiny.png'] = 'rbxassetid://71393233149714',
		['InhalerV4/assets/new/colorpreview.png'] = 'rbxassetid://140438628568318',
		['InhalerV4/assets/new/combat.png'] = 'rbxassetid://94762732349053',
		['InhalerV4/assets/new/customtheme.png'] = 'rbxassetid://91756736022800',
		['InhalerV4/assets/new/discord.png'] = 'rbxassetid://99871463341003',
		['InhalerV4/assets/new/downexpand.png'] = 'rbxassetid://94197751291504',
		['InhalerV4/assets/new/downexpandslider.png'] = 'rbxassetid://90289944682645',
		['InhalerV4/assets/new/edit.png'] = 'rbxassetid://105801951237137',
		['InhalerV4/assets/new/editlarge.png'] = 'rbxassetid://119233876755282',
		['InhalerV4/assets/new/expandarrow.png'] = 'rbxassetid://86360332526471',
		['InhalerV4/assets/new/friends.png'] = 'rbxassetid://92957214042038',
		['InhalerV4/assets/new/inventory.png'] = 'rbxassetid://93264756888499',
		['InhalerV4/assets/new/legit_mode_icon.png'] = 'rbxassetid://102858626075156',
		['InhalerV4/assets/new/legit_switch.png'] = 'rbxassetid://127508881124779',
		['InhalerV4/assets/new/min.png'] = 'rbxassetid://82175054487146',
		['InhalerV4/assets/new/noti_alert.png'] = 'rbxassetid://82356478726846',
		['InhalerV4/assets/new/noti_info.png'] = 'rbxassetid://102614825645099',
		['InhalerV4/assets/new/noti_warning.png'] = 'rbxassetid://119631730212167',
		['InhalerV4/assets/new/notification.png'] = 'rbxassetid://90300780458781',
		['InhalerV4/assets/new/npcs.png'] = 'rbxassetid://104434365485227',
		['InhalerV4/assets/new/overlaydots.png'] = 'rbxassetid://78012624671930',
		['InhalerV4/assets/new/overlays.png'] = 'rbxassetid://136535637407545',
		['InhalerV4/assets/new/overlayslarge.png'] = 'rbxassetid://127574141208160',
		['InhalerV4/assets/new/pin.png'] = 'rbxassetid://92459145800579',
		['InhalerV4/assets/new/players.png'] = 'rbxassetid://105137446428129',
		['InhalerV4/assets/new/profiles.png'] = 'rbxassetid://126051451865127',
		['InhalerV4/assets/new/radar.png'] = 'rbxassetid://97983828696086',
		['InhalerV4/assets/new/rainbow_1.png'] = 'rbxassetid://101329996188554',
		['InhalerV4/assets/new/rainbow_2.png'] = 'rbxassetid://72739074644654',
		['InhalerV4/assets/new/rainbow_3.png'] = 'rbxassetid://100716555253397',
		['InhalerV4/assets/new/rainbow_4.png'] = 'rbxassetid://133424174227092',
		['InhalerV4/assets/new/range.png'] = 'rbxassetid://107794917650053',
		['InhalerV4/assets/new/rangeindicator.png'] = 'rbxassetid://107038094175283',
		['InhalerV4/assets/new/render.png'] = 'rbxassetid://125472576898654',
		['InhalerV4/assets/new/search.png'] = 'rbxassetid://115611852955611',
		['InhalerV4/assets/new/settingdots.png'] = 'rbxassetid://130896840048276',
		['InhalerV4/assets/new/settings.png'] = 'rbxassetid://73820177347303',
		['InhalerV4/assets/new/settingsmini.png'] = 'rbxassetid://115732118290997',
		['InhalerV4/assets/new/targetinfo.png'] = 'rbxassetid://121604266095276',
		['InhalerV4/assets/new/textgui.png'] = 'rbxassetid://99438663817412',
		['InhalerV4/assets/new/theme.png'] = 'rbxassetid://111525258317113',
		['InhalerV4/assets/new/utility.png'] = 'rbxassetid://108303206513893',
		['InhalerV4/assets/new/vape.png'] = 'rbxassetid://92153855792786',
		['InhalerV4/assets/new/vapelogo.png'] = 'rbxassetid://126205920310261',
		['InhalerV4/assets/new/vapelogomini.png'] = 'rbxassetid://109041903452149',
		['InhalerV4/assets/new/v4.png'] = 'rbxassetid://102549752760489',
		['InhalerV4/assets/new/v4mini.png'] = 'rbxassetid://115213099001611',
		['InhalerV4/assets/new/world.png'] = 'rbxassetid://118917453153459'
	}

	local function createDownloader(text)
		if vape.Loaded ~= true then
			local downloader = vape.Downloader
			if not downloader then
				downloader = Instance.new('TextLabel')
				downloader.BackgroundTransparency = 1
				downloader.FontFace = uipallet.Font
				downloader.Size = UDim2.new(1, 0, 0, 40)
				downloader.TextColor3 = Color3.new(1, 1, 1)
				downloader.TextSize = 20
				downloader.TextStrokeTransparency = 0
				downloader.Parent = vape.gui
				vape.Downloader = downloader
			end

			downloader.Text = 'Downloading '..text
		end
	end

	local function downloadFile(path, callback)
		if not isfile(path) then
			createDownloader(path)

			local success, data = pcall(function()
				return game:HttpGet('https://raw.githubusercontent.com/Night5449791/InhalerCompiled/'..readfile('InhalerV4/profiles/commit.txt')..'/'..select(1, path:gsub('InhalerV4/', '')), true)
			end)

			if not success or data == '404: Not Found' then
				error(data)
			end

			if path:find('.lua') then
				data = '--This watermark is used to delete the file if its cached, remove it to make the file persist after inhaler updates.\n'..data
			end

			writefile(path, data)
		end

		return (callback or readfile)(path)
	end

	getvapeasset = not inputService.TouchEnabled and getcustomasset and function(path)
		return downloadFile(path, getcustomasset)
	end or function(path)
		return vapeAssets[path] or ''
	end
end