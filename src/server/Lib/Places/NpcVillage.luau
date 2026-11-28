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
local Detail = require(script.Parent.Parent:WaitForChild("Detail"))
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
	local bubble = k:ball("SpeechBubble", 26, 70, z + 8, 24, 14, 3, Color3.new(1, 1, 1), Enum.Material.Marble, { collide = false })
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

	-- STATUE DETAIL (the hero of the village): a plinth, carved face, ears, shoulder pads, belt, hands, moss, vines and cracks
	local faceZ = z + 12.2
	k:box("StatuePlinth", 0, 0, z, 46, 3, 22, Color3.fromRGB(128, 122, 118), Enum.Material.Cobblestone)
	k:box("StatuePlinthTop", 0, 3, z, 40, 1, 18, Color3.fromRGB(150, 142, 134), Enum.Material.Slate, { collide = false })
	for _, side in { -1, 1 } do
		k:box("Eye", side * 5.2, 69, faceZ, 4, 4, 0.6, Color3.fromRGB(40, 40, 52), Enum.Material.Slate, { collide = false })
		k:box("EyeShine", side * 5.8, 70, faceZ + 0.35, 1.2, 1.2, 0.3, Color3.new(1, 1, 1), Enum.Material.Marble, { collide = false })
		k:box("Brow", side * 5.2, 73.2, faceZ, 6, 1.2, 0.9, DARK, Enum.Material.Slate, { collide = false })
		k:box("Ear", side * 12.8, 66, z, 2, 6, 5, Color3.fromRGB(175, 175, 186), Enum.Material.Slate, { collide = false })
		k:ball("ShoulderPad", side * 20, 54.5, z, 14, 8, 15, GREY, Enum.Material.Slate, { collide = false })
		k:box("Hand", side * 22, 24, z, 8, 6, 8, Color3.fromRGB(175, 175, 186), Enum.Material.Slate, { collide = false })
		for finger = -1, 1 do
			k:box("Finger", side * 22 + finger * 2.6, 21, z + 1, 1.8, 3.4, 2.2, Color3.fromRGB(175, 175, 186), Enum.Material.Slate, { collide = false })
		end
		k:ball("Moss", side * 8, 6, z + 5.4, 6, 4, 2, Color3.fromRGB(100, 160, 70), Enum.Material.Grass, { collide = false })
		k:box("Vine", side * 24.6, 30, z + 1, 0.5, 22, 0.5, Color3.fromRGB(70, 140, 60), Enum.Material.Grass, { collide = false })
	end
	k:box("Nose", 0, 64.5, faceZ + 0.8, 3, 5, 2, Color3.fromRGB(185, 185, 196), Enum.Material.Slate, { collide = false })
	k:box("Mouth", 0, 62.4, faceZ, 10, 1.2, 0.6, Color3.fromRGB(40, 40, 52), Enum.Material.Slate, { collide = false })
	k:box("Belt", 0, 29, z, 36, 3, 19, DARK, Enum.Material.Slate, { collide = false })
	k:box("BeltBuckle", 0, 29.4, z + 9.6, 5, 2.4, 0.8, Color3.fromRGB(255, 200, 60), Enum.Material.Metal, { collide = false })
	for row = 1, 8 do -- stone block lines on the torso and head
		k:box("StatueMortar", 0, 28 + row * 3.4, z + 8.8, 33.6, 0.2, 0.3, Color3.fromRGB(110, 110, 122), Enum.Material.Slate, { collide = false })
	end
	for _, crack in { { -10, 40, 18 }, { 12, 48, -25 }, { 4, 20, 14 } } do
		local line = k:box("Crack", crack[1], crack[2], z + 8.9, 0.35, 7, 0.3, Color3.fromRGB(70, 70, 82), Enum.Material.Slate, { collide = false })
		line.CFrame = CFrame.new(line.Position) * CFrame.Angles(0, 0, math.rad(crack[3]))
	end
	-- a flag-pole on the head plate with a tiny pennant
	k:box("PennantPole", -10, 84, z + 1, 0.5, 6, 0.5, Color3.fromRGB(104, 72, 48), Enum.Material.Wood, { collide = false })

	-- the scaffolding is gone: one big BUBBLE LIFT at the foot of the statue floats you up to the head plate (84 up)
	local row = -4
	k:lift("StatueLift", { { -16, 0, row }, { -16, 86, row }, { -6, 86, -14 } })
	for _, dx in { -1, 1 } do -- two little banner posts so the lift is easy to spot
		k:box("LiftPost", -16 + dx * 4, 0, row, 1, 6, 1, WOOD, Enum.Material.Wood)
	end
end

-- A house: a room with a door facing the plaza. Two-storey houses have stairs inside and a fighting roof deck.
local function house(k: any, x: number, z: number, doorSide: string, twoStory: boolean, roofColor: Color3)
	local doors: { [string]: any } = { [doorSide] = { w = 6, h = 8 } }
	local floorY = 0
	k:room("House", x, floorY, z, 20, 11, 18, 1.5, CREAM, Enum.Material.WoodPlanks, doors, WOOD, false)
	-- windows to shoot through (gaps cut by short walls: here simple dark panes on the outside, no gap)
	k:box("Pane", x, 5, z + 9.1, 4, 3, 0.2, Color3.fromRGB(110, 170, 220), Enum.Material.Glass, { collide = false })
	-- timber framing, door frame and awning, shutters and a flower box: no plain walls
	local darkWood = Color3.fromRGB(96, 66, 44)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			k:box("TimberPost", x + sx * 10.1, 0, z + sz * 9.1, 0.9, 11, 0.9, darkWood, Enum.Material.Wood, { collide = false })
		end
	end
	for _, level in { 0.2, 5, 10 } do
		for _, sz in { -1, 1 } do
			k:box("TimberBeam", x, level, z + sz * 9.15, 20.4, 0.8, 0.5, darkWood, Enum.Material.Wood, { collide = false })
		end
		for _, sx in { -1, 1 } do
			k:box("TimberBeam", x + sx * 10.15, level, z, 0.5, 0.8, 18.4, darkWood, Enum.Material.Wood, { collide = false })
		end
	end
	local awningX = if doorSide == "E" then 11.4 elseif doorSide == "W" then -11.4 else 0
	local awningZ = if doorSide == "N" then -10.4 else 0
	local awning = k:box("DoorAwning", x + awningX, 9, z + awningZ, if doorSide == "N" then 9 else 2.6, 0.5, if doorSide == "N" then 2.6 else 9, roofColor, Enum.Material.Fabric, { collide = false })
	awning.CFrame = CFrame.new(awning.Position)
	for _, shutter in { -3.4, 3.4 } do
		k:box("Shutter", x + shutter, 3.4, z + 9.3, 1.3, 3.8, 0.3, roofColor, Enum.Material.WoodPlanks, { collide = false })
	end
	k:box("FlowerBox", x, 2, z + 9.7, 5, 0.9, 1.2, darkWood, Enum.Material.Wood, { collide = false })
	for index = -2, 2 do
		k:ball("BoxFlower", x + index, 2.9, z + 9.7, 0.9, 0.9, 0.9, Color3.fromHSV((index * 0.17 + 0.05) % 1, 0.7, 1), Enum.Material.Marble, { collide = false })
	end
	k:box("Chimney", x + 6, 11, z - 4, 2.6, 8, 2.6, Color3.fromRGB(150, 118, 100), Enum.Material.Brick, { collide = false })
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
		-- a pitched tile roof (looks only: nobody stands on it), with a ridge cap and stepped gables
		local span, rise = 9.9, 6
		local slope = math.sqrt(span * span + rise * rise)
		local angle = math.atan2(rise, span)
		for _, side in { -1, 1 } do
			local slab = k:box("RoofTiles", x, 11 + rise / 2 + 0.1, z + side * span / 2, 22.4, 0.9, slope + 0.6, roofColor, Enum.Material.Brick, { collide = false })
			slab.CFrame = CFrame.new(slab.Position) * CFrame.Angles(side * angle, 0, 0)
			for course = 1, 3 do -- darker tile courses
				local line = k:box("RoofCourse", x, 11 + rise / 2 + 0.6, z + side * span / 2, 22.5, 0.2, 0.35, roofColor:Lerp(Color3.new(0, 0, 0), 0.25), Enum.Material.Slate, { collide = false })
				local along = (course - 2) * slope * 0.28
				line.CFrame = CFrame.new(x, 11 + rise / 2 + 0.7 - along * math.sin(angle), z + side * (span / 2 + along * math.cos(angle))) * CFrame.Angles(side * angle, 0, 0)
			end
		end
		k:box("RoofRidge", x, 11 + rise, z, 22.6, 0.9, 1.4, roofColor:Lerp(Color3.new(0, 0, 0), 0.3), Enum.Material.Slate, { collide = false })
		for _, sx in { -1, 1 } do
			for step, width in { 17, 11, 5 } do
				k:box("Gable", x + sx * 10.1, 11 + (step - 1) * 2, z, 0.6, 2, width, CREAM, Enum.Material.WoodPlanks, { collide = false })
			end
		end
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
	k:truss("WellLadder", wellX + 1.2, -16, wellZ, 17, wellX + 1.2, wellZ + 7.5, 5)
	Common.stash(folder, k:at(wellX + 4, -16, wellZ + 3), territory.id)
	local glow = Instance.new("PointLight")
	glow.Range = 20
	glow.Color = Color3.fromRGB(255, 230, 170)
	glow.Parent = folder:FindFirstChild("AuraStash") or folder

	-- ===== DETAIL PASS (see ART.md): grass patches, cobble plaza and paths, trees, stalls, fences, gardens, light and life =====
	local rng = Random.new(2024)
	local world = function(x: number, z: number): Vector3
		return Vector3.new(cx + x, territory.height, cz + z)
	end
	for index = 1, 9 do -- grass patches round the rim, so the packed dirt is not one flat colour
		local angle = index / 9 * math.pi * 2
		TerrainKit.cylinder(cx + math.cos(angle) * 78, -6, cz + math.sin(angle) * 78, 16 + (index % 3) * 4, 6, Enum.Material.Grass)
	end
	Detail.cobblePath(folder, world(-12, 16), world(12, 16), 24, rng) -- the plaza
	for _, door in { { -50, 10 }, { 50, 10 }, { -50, -35 }, { 50, -35 }, { -50, 55 }, { 50, 55 }, { -22, 60 }, { 22, 60 } } do
		Detail.cobblePath(folder, world(if door[1] < 0 then -12 else 12, 20), world(door[1], door[2]), 5, rng)
	end
	for _, side in { -1, 1 } do
		-- market stalls on the plaza edge, striped awnings
		Detail.stall(folder, world(side * 26, 30), Vector3.new(-side, 0, 0), if side < 0 then { Color3.fromRGB(215, 70, 60), Color3.fromRGB(245, 240, 225) } else { Color3.fromRGB(70, 130, 210), Color3.fromRGB(245, 240, 225) }, rng)
		Detail.cart(folder, world(side * 38, 52), side * 0.6)
		-- fences along the house gardens
		Detail.fence(folder, world(side * 44, -20), world(side * 44, -2))
		Detail.fence(folder, world(side * 44, 24), world(side * 44, 42))
		Detail.flowerBed(folder, world(side * 8, -4), Vector3.xAxis, 10, 4, rng) -- flowers at the foot of the statue
		for index = 1, 5 do
			Detail.lanternPost(folder, world(side * 14, -8 + index * 12), index % 2 == 1)
		end
		for index = 1, 6 do
			Detail.bush(folder, world(side * (48 + index * 7), -60 + index * 4), 1.1, rng)
		end
	end
	-- trees: warm leaves at the edges, never on the plaza or paths
	for index = 1, 14 do
		local angle = index / 14 * math.pi * 2 + rng:NextNumber() * 0.3
		local radius = 78 + rng:NextNumber() * 14
		local spot = Detail.ground(cx + math.cos(angle) * radius, cz + math.sin(angle) * radius, territory.height)
		if spot then
			Detail.tree(folder, spot, 0.9 + rng:NextNumber() * 0.5, if index % 3 == 0 then Color3.fromRGB(230, 170, 60) else Color3.fromRGB(110, 190, 70), rng)
		end
	end
	-- the well gets a little roof and a bucket
	for _, post in { { -3.2, 3.2 }, { 3.2, 3.2 }, { -3.2, -3.2 }, { 3.2, -3.2 } } do
		k:box("WellPost", wellX + post[1], 3, wellZ + post[2], 0.7, 7, 0.7, Color3.fromRGB(104, 72, 48), Enum.Material.Wood)
	end
	k:cyl("WellBucket", wellX, 6.5, wellZ, 1.6, 1.4, Color3.fromRGB(150, 105, 62), Enum.Material.Wood, { collide = false })
	for _, side in { -1, 1 } do
		local half = k:box("WellRoof", wellX, 10.4, wellZ + side * 2.4, 9, 0.6, 5.6, Color3.fromRGB(200, 80, 70), Enum.Material.Brick, { collide = false })
		half.CFrame = CFrame.new(half.Position) * CFrame.Angles(side * math.rad(35), 0, 0)
	end
	Detail.tuftRing(folder, Vector3.new(cx, territory.height, cz), 20, 92, 90, rng)
	Detail.rocks(folder, world(-86, -50), rng, 6)
	Detail.rocks(folder, world(80, 60), rng, 6)
	Detail.fireflies(folder, world(0, -50) + Vector3.new(0, 4, 0), Vector3.new(70, 8, 30))
	Detail.fireflies(folder, world(0, 60) + Vector3.new(0, 4, 0), Vector3.new(80, 8, 24))
	Detail.leaves(folder, world(-70, 0) + Vector3.new(0, 20, 0), Color3.fromRGB(230, 170, 60))

	Common.ambience(folder, k:at(0, 6, 20), Ambience.npc_village, 0.35)
end
