local ToySpawner

-- The game only lets you spawn what you have bought, and the check is a CanSpawnToy
-- remote the client is free to skip: the spawn function itself takes a toy name and a
-- position and does not re-check ownership. So the dropdown is simply the list of names
-- the request accepts.
local TOYS = {
	'Campfire',
	'CreatureBlobman',
	'CreatureRobot',
	'CupMugBrown',
	'FoodCoconut',
	'InstrumentWoodwindOcarina',
	'NinjaShuriken',
	'PalletLightBrown',
	'TractorGreen',
	'FlyingToyHelicopter',
	'FlyingToyPlane',
	'FlyingToyUfo'
}

ToySpawner = vape.Categories.Utility:CreateModule({
	Name = 'Toy Spawner',
	Function = function(callback)
		if callback then
			local toy = ToySpawner.Options['Toy']
			local bind = ToySpawner.Options['Bind']
			local distance = ToySpawner.Options['Distance']

			local function spawn()
				if not entitylib.isAlive then return end

				local root = entitylib.character.RootPart
				if not root then return end

				local position = root.Position + (gameCamera.CFrame.LookVector * distance.Value)

				if not ftap.spawnToy(toy.Value, position) then
					notif('Toy Spawner', 'The game has not loaded its spawn remote yet', 3, 'warning')
				end
			end

			ToySpawner:Clean(bind.Triggered:Connect(function(isDown)
				if isDown then spawn() end
			end))

			repeat
				task.wait()
			until not ToySpawner.Enabled
		end
	end
})
ToySpawner:CreateDropdown({
	Name = 'Toy',
	List = TOYS,
	Default = 'TractorGreen'
})
ToySpawner:CreateSlider({
	Name = 'Distance',
	Min = 2,
	Max = 50,
	Default = 8,
	Suffix = 'studs'
})
ToySpawner:CreateBind({
	Name = 'Bind',
	Default = {'F'},
	Tooltip = 'Spawn the selected toy where you are looking'
})
