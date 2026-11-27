--!strict
-- NPC Village (Gold, north-west): a blocky village of enterable houses around a plaza, with villagers who stare at you
-- now and then, a well with a secret room underneath, and a giant grey NPC statue you climb by wooden scaffolding.
-- The flag is on the statue's head. Palette: warm wood, cream and red roofs, grey statue. Ground: packed dirt.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ambience = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Ambience"))
local Builder = require(script.Parent.Parent:WaitForChild("Builder"))
local Cover = require(script.Parent.Parent:WaitForChild("Cover"))
local Common = require(script.Parent:WaitForChild("Common"))
local Kit = require(script.Parent.Parent:WaitForChild("Kit"))
local TerrainKit = require(script.Parent.Parent:WaitForChild("TerrainKit"))
local SkyKit = require(script.Parent.Parent:WaitForChild("SkyKit"))

local GREY = Color3.fromRGB(160, 160, 170)
local DARK = Color3.fromRGB(120, 120, 130)
local WOOD = Color3.fromRGB(176, 128, 74)
local CREAM = Color3.fromRGB(240, 226, 190)

-- The giant statue: legs, torso, arms, a blank blocky head with a flat plate on top for the flag.
local function statue(k: any)
	local z = -20
	k:box("StatueLegL", -8, 0, z, 8, 28, 10, DARK, Enum.Material.Slate)
	k:box("StatueLegR", 8, 0, z, 8, 28, 10, DARK, Enum.Material.Slate)
	k:box("StatueTorso", 0, 28, z, 34, 30, 17, GREY, Enum.Material.Slate)
	k:box("StatueArmL", -22, 30, z, 9, 27, 9, DARK, Enum.Material.Slate, { collide = true })
	k:box("StatueArmR", 22, 30, z, 9, 27, 9, DARK, Enum.Material.Slate)
	k:box("StatueHead", 0, 58, z, 24, 24, 24, Color3.fromRGB(190, 190, 200), Enum.Material.Slate) -- a blank face
	k:box("StatueHeadPlate", 0, 82, z + 1, 28, 2, 26, GREY, Enum.Material.Slate) -- the flag stands here, y = 84
	-- the speech bubble: a white squashed ball with "..." on it, floating beside the head
	local bubble = k:ball("SpeechBubble", 26, 70, z + 8, 24, 14, 3, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, { collide = false })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = bubble
	local dots = Instance.new("TextLabel")
	dots.Size = UDim2.new(1, 0, 1, 0)
	dots.BackgroundTransparency = 1
	dots.TextColor3 = Color3.fromRGB(35, 25, 60)
	dots.Font = Enum.Font.FredokaOne
	dots.TextScaled = true
	dots.Text = "..."
	dots.Parent = gui

	-- wooden scaffolding up the front: six flights of stairs zig-zagging between landings, 14 up each
	local row = -4
	local function flight(fromX: number, toX: number, base: number)
		k:stairs("ScaffoldStair", fromX, base, row, toX, row, 14, 5, WOOD, Enum.Material.WoodPlanks, true)
	end
	local landings = { { 20, 14 }, { -20, 28 }, { 20, 42 }, { -20, 56 }, { 20, 70 } }
	flight(-16, 16, 0)
	flight(16, -16, 14)
	flight(-16, 16, 28)
	flight(16, -16, 42)
	flight(-16, 16, 56)
	flight(16, -4, 70) -- the last flight ends level with the head plate
	for _, landing in landings do
		k:box("ScaffoldLanding", landing[1], landing[2] - 0.8, row, 10, 0.8, 8, WOOD, Enum.Material.WoodPlanks)
		for _, dx in { -4, 4 } do
			for _, dz in { -3, 3 } do
				k:box("ScaffoldPost", landing[1] + dx, 0, row + dz, 1, landing[2] - 0.8, 1, WOOD, Enum.Material.Wood)
			end
		end
	end
end

-- A house: a room with a door facing the plaza. Two-storey houses have stairs inside and a fighting roof deck.
local function house(k: any, x: number, z: number, doorSide: string, twoStory: boolean, roofColor: Color3)
	local doors: { [string]: any } = { [doorSide] = { w = 6, h = 8 } }
	local floorY = 0
	k:room("House", x, floorY, z, 20, 11, 18, 1.5, CREAM, Enum.Material.WoodPlanks, doors, WOOD, false)
	-- windows to shoot through (gaps cut by short walls: here simple dark panes on the outside, no gap)
	k:box("Pane", x, 5, z + 9.1, 4, 3, 0.2, Color3.fromRGB(110, 170, 220), Enum.Material.Glass, { collide = false })
	if twoStory then
		-- upper floor with a stair hole, stairs along the west wall, and a parapet on the roof deck
		k:box("UpperFloor", x + 3, 11, z, 14, 1, 18, WOOD, Enum.Material.WoodPlanks)
		k:box("UpperFloor", x - 7, 11, z + 8, 6, 1, 2, WOOD, Enum.Material.WoodPlanks)
		k:box("UpperFloor", x - 7, 11, z - 8, 6, 1, 2, WOOD, Enum.Material.WoodPlanks)
		k:stairs("HouseStair", x - 7, 0, z - 6.5, x - 7, z + 6.5, 11, 4, WOOD, Enum.Material.WoodPlanks, true)
		for _, side in { -1, 1 } do
			k:box("Parapet", x, 12, z + side * 8.5, 20, 3, 1, CREAM, Enum.Material.WoodPlanks, { cover = true })
		end
		k:box("Parapet", x - 9.5, 12, z, 1, 3, 18, CREAM, Enum.Material.WoodPlanks, { cover = true })
		k:box("Parapet", x + 9.5, 12, z, 1, 3, 18, CREAM, Enum.Material.WoodPlanks, { cover = true })
	else
		k:box("RoofSlab", x, 11, z, 21, 1.5, 19, roofColor, Enum.Material.Slate)
		-- crates to jump up onto the roof
		local side = if doorSide == "E" then -1 else 1
		k:box("StepCrate", x + side * 12, 0, z + 8, 4, 4, 4, WOOD, Enum.Material.WoodPlanks, { cover = true })
		k:box("StepCrate", x + side * 11, 0, z + 5, 4, 8, 4, WOOD, Enum.Material.WoodPlanks, { cover = true })
	end
end

local function villager(folder: Folder, position: Vector3)
	local model = Instance.new("Model")
	model.Name = "Villager"
	local body = Builder.part("Body", Vector3.new(3.4, 5, 2), position + Vector3.new(0, 2.5, 0), GREY, model)
	body.Material = Enum.Material.Slate
	local head = Builder.part("Head", Vector3.new(3, 3, 3), position + Vector3.new(0, 6.5, 0), Color3.fromRGB(190, 190, 200), model)
	head.Material = Enum.Material.Slate
	for _, dx in { -1.1, 1.1 } do
		local leg = Builder.part("Leg", Vector3.new(1.4, 3, 1.6), position + Vector3.new(dx, -0.5 + 0.5, 0), DARK, model)
		leg.CanCollide = false
	end
	model.PrimaryPart = body
	model.Parent = folder
	-- the "..." bubble, shown by the village moment
	local gui = Instance.new("BillboardGui")
	gui.Name = "StareBubble"
	gui.Size = UDim2.new(0, 70, 0, 40)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.Enabled = false
	gui.Adornee = head
	gui.Parent = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(35, 25, 60)
	label.Text = "..."
	label.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = label
	CollectionService:AddTag(model, "Villager")
end

return function(folder: Folder, territory: any)
	local cx, cz = territory.x, territory.z
	local k = Kit.new(folder, cx, cz, territory.height)
	Cover.reserve(cx, cz, 100, 95)
	SkyKit.island(cx, cz, territory.height, territory.radius, 60)
	SkyKit.vines(folder, cx, cz, territory.height, territory.radius, 14)
	SkyKit.waterfall(folder, Vector3.new(cx + territory.radius - 3, territory.height, cz + 10), Vector3.new(1, 0, 0), 40)
	TerrainKit.cylinder(cx, -6, cz, 98, 6, Enum.Material.Ground)

	statue(k)
	-- six houses in two columns facing the plaza, two more at the south, the south pair with two storeys
	house(k, -60, -35, "E", false, Color3.fromRGB(200, 80, 70))
	house(k, 60, -35, "W", false, Color3.fromRGB(70, 120, 200))
	house(k, -60, 10, "E", true, Color3.fromRGB(200, 80, 70))
	house(k, 60, 10, "W", true, Color3.fromRGB(70, 120, 200))
	house(k, -60, 55, "E", false, Color3.fromRGB(230, 170, 60))
	house(k, 60, 55, "W", false, Color3.fromRGB(80, 170, 100))
	house(k, -22, 70, "N", true, Color3.fromRGB(200, 80, 70))
	house(k, 22, 70, "N", false, Color3.fromRGB(70, 120, 200))
	Common.stash(folder, k:at(-56, 12, 10), territory.id, "npc_rooftop") -- a stash on the roof deck of the two-storey house
	-- chimney smoke
	Common.smoke(folder, "ChimneySmoke", k:at(-60, 14, 10), Color3.fromRGB(235, 235, 235), 3, 6)
	Common.smoke(folder, "ChimneySmoke", k:at(60, 14, 10), Color3.fromRGB(235, 235, 235), 3, 6)

	-- villagers in the plaza
	for _, spot in { { -22, 20 }, { 18, 28 }, { -34, 44 }, { 34, 44 }, { 0, 52 }, { 8, 8 } } do
		villager(folder, k:at(spot[1], 0, spot[2]))
	end
	-- plaza cover: crates and barrels
	for index, spot in { { -30, 28 }, { 28, 18 }, { -12, 40 }, { 14, 46 }, { -44, 18 }, { 44, 36 }, { 0, 24 }, { -40, 62 }, { 40, 68 } } do
		if index % 2 == 0 then
			k:cyl("Barrel", spot[1], 0, spot[2], 3.4, 5, Color3.fromRGB(215, 70, 60), Enum.Material.Metal, { cover = true })
		else
			k:box("Crate", spot[1], 0, spot[2], 5, 5, 5, WOOD, Enum.Material.WoodPlanks, { cover = true, rotY = index * 0.7 })
		end
	end

	-- the well, and the secret under it: a carved room reached by dropping down the shaft (a ladder climbs back out)
	local wellX, wellZ = 0, 34 -- world position is a multiple of 4, so the carved room has clean edges
	local wx, wz = cx + wellX, cz + wellZ
	TerrainKit.carve(wx, -16, wz, 16, 12, 16) -- the room
	TerrainKit.carve(wx, -4, wz, 4, 4, 4) -- the shaft up through the ground
	k:box("WellRim", wellX, 0, wellZ - 3.5, 11, 3, 3, DARK, Enum.Material.Cobblestone)
	k:box("WellRim", wellX, 0, wellZ + 3.5, 11, 3, 3, DARK, Enum.Material.Cobblestone)
	k:box("WellRim", wellX - 3.5, 0, wellZ, 3, 3, 4, DARK, Enum.Material.Cobblestone)
	k:box("WellRim", wellX + 3.5, 0, wellZ, 3, 3, 4, DARK, Enum.Material.Cobblestone)
	k:truss("WellLadder", wellX + 1.2, -16, wellZ, 17)
	Common.stash(folder, k:at(wellX + 4, -16, wellZ + 3), territory.id)
	local glow = Instance.new("PointLight")
	glow.Range = 20
	glow.Color = Color3.fromRGB(255, 230, 170)
	glow.Parent = folder:FindFirstChild("AuraStash") or folder

	Common.ambience(folder, k:at(0, 6, 20), Ambience.npc_village, 0.35)
end
