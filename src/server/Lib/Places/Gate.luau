--!strict
-- Gigachad Gate (Ultra, centre of the island): a giant stone face with sunglasses. Its mouth is a tunnel you walk
-- through. Inside the head is the throne room, reached from two spiral-stair towers by covered corridors; the towers
-- have flags on their roofs. Castle walls, a courtyard, banners and a secret stash room round it off.
-- Palette: grey stone, gold and purple. Ground: cobblestone.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ambience = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Ambience"))
local Cover = require(script.Parent.Parent:WaitForChild("Cover"))
local Common = require(script.Parent:WaitForChild("Common"))
local Kit = require(script.Parent.Parent:WaitForChild("Kit"))
local TerrainKit = require(script.Parent.Parent:WaitForChild("TerrainKit"))

local STONE = Color3.fromRGB(150, 150, 166)
local DARK = Color3.fromRGB(105, 105, 122)
local GOLD = Color3.fromRGB(255, 200, 60)
local PURPLE = Color3.fromRGB(140, 60, 210)
local BLACK = Color3.fromRGB(20, 20, 28)

-- One tower. `side` is -1 for the west tower and 1 for the east tower; the corridor to the head is on the inner wall.
local function tower(k: any, side: number)
	local x = side * 75
	-- walls 64 tall with a ground door on the north wall, and a high door on the wall facing the head (y = 26)
	local inner = if side < 0 then "E" else "W"
	local dirX = -side -- toward the head: +1 for the west tower, -1 for the east tower
	k:room("Tower", x, 0, 0, 22, 64, 22, 2, STONE, Enum.Material.Cobblestone, { N = true, [inner] = { w = 7, h = 8, y = 26 } }, DARK, false)
	-- four flights of thin stairs around the inside, 15 up each, ending level with the roof deck (y = 60)
	local function flight(x0: number, z0: number, x1: number, z1: number, base: number)
		k:stairs("TowerStair", x + dirX * x0, base, z0, x + dirX * x1, z1, 15, 5, DARK, Enum.Material.Slate, true)
	end
	flight(-8, 7, 8, 7, 0) -- along the south wall
	flight(7, 8, 7, -8, 15) -- along the wall facing the head
	flight(8, -7, -8, -7, 30) -- along the north wall
	flight(-7, -8, -7, 8, 45) -- along the far wall, up to the roof
	-- the roof deck covers everything except the top of that last flight
	local deckX = x + dirX * 3.25
	k:box("TowerDeck", deckX, 58, 0, 15.5, 2, 20, STONE, Enum.Material.Cobblestone)
	-- battlements on the deck edge
	for index = -2, 2 do
		k:box("Merlon", x + dirX * 10, 62, index * 4.2, 2, 3, 2.4, STONE, Enum.Material.Cobblestone, { cover = true })
	end
	k:box("Banner", x, 36, 11.4, 7, 18, 0.5, PURPLE, Enum.Material.Fabric, { collide = false })
	k:box("BannerGold", x, 52, 11.5, 7, 2, 0.6, GOLD, Enum.Material.Neon, { collide = false })
end

return function(folder: Folder, territory: any)
	local cx, cz = territory.x, territory.z
	local k = Kit.new(folder, cx, cz, 0)
	Cover.reserve(cx, cz - 5, 118, 62)
	TerrainKit.cylinder(cx, -6, cz, 115, 6, Enum.Material.Cobblestone) -- a stone plaza under the whole castle

	-- the head: jaws either side of a 24-wide mouth tunnel, a floor over the tunnel, the throne room above it
	k:box("JawLeft", -28.5, 0, 0, 33, 25, 60, STONE, Enum.Material.Slate)
	k:box("JawRight", 28.5, 0, 0, 33, 25, 60, STONE, Enum.Material.Slate)
	k:box("HeadFloor", 0, 25, 0, 90, 1, 60, DARK, Enum.Material.Slate)
	k:room("Throne", 0, 26, 0, 90, 34, 60, 3, STONE, Enum.Material.Slate, { W = { w = 8, h = 9 }, E = { w = 8, h = 9 } }, nil, false)
	k:box("HeadRoof", 0, 60, 0, 94, 6, 64, STONE, Enum.Material.Slate)
	-- sunglasses, brow, nose and teeth on the south face
	k:box("Glasses", 0, 42, 31.2, 74, 9, 2, BLACK, Enum.Material.SmoothPlastic, { collide = false })
	k:box("GlassesBridge", 0, 45, 31.8, 8, 2, 2, BLACK, Enum.Material.SmoothPlastic, { collide = false })
	k:box("Glint", -22, 46, 32.4, 10, 2, 0.4, Color3.new(1, 1, 1), Enum.Material.Neon, { collide = false })
	k:box("Glint", 22, 46, 32.4, 10, 2, 0.4, Color3.new(1, 1, 1), Enum.Material.Neon, { collide = false })
	k:box("Brow", 0, 52, 31.5, 80, 4, 3, DARK, Enum.Material.Slate, { collide = false })
	k:box("Nose", 0, 28, 31.5, 9, 14, 5, STONE, Enum.Material.Slate, { collide = false })
	for index = -4, 4 do
		k:box("Tooth", index * 2.6, 19, 29.5, 2.2, 6, 2, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, { collide = false })
	end
	k:box("GoldTrim", 0, 25.2, 31.2, 90, 1.2, 1, GOLD, Enum.Material.Neon, { collide = false })
	-- inside the throne room: a gold throne and four pillars to fight around
	k:box("ThroneSeat", 0, 26, -22, 9, 4, 7, GOLD, Enum.Material.Metal)
	k:box("ThroneBack", 0, 30, -25, 9, 12, 2, GOLD, Enum.Material.Metal)
	for _, px in { -24, 24 } do
		for _, pz in { -14, 14 } do
			k:cyl("Pillar", px, 26, pz, 5, 33, STONE, Enum.Material.Cobblestone, { cover = true })
		end
	end
	k:box("Rug", 0, 26, 6, 10, 0.3, 36, PURPLE, Enum.Material.Fabric, { collide = false })

	-- two towers and the covered corridors that join them to the throne room
	tower(k, -1)
	tower(k, 1)
	k:room("CorridorW", -54.5, 26, 0, 21, 9, 8, 1.5, STONE, Enum.Material.Slate, { W = { w = 7, h = 8 }, E = { w = 7, h = 8 } }, DARK, true)
	k:room("CorridorE", 54.5, 26, 0, 21, 9, 8, 1.5, STONE, Enum.Material.Slate, { W = { w = 7, h = 8 }, E = { w = 7, h = 8 } }, DARK, true)

	-- castle walls with battlements across the front, leaving a wide gateway
	for _, side in { -1, 1 } do
		k:box("CourtWall", side * 72.5, 0, 52, 75, 10, 3, STONE, Enum.Material.Cobblestone, { cover = true })
		for index = 0, 6 do
			k:box("Merlon", side * (38 + index * 11), 10, 52, 5, 3, 3, STONE, Enum.Material.Cobblestone, { cover = true })
		end
		k:box("CourtWall", side * 108, 0, 25, 3, 10, 55, STONE, Enum.Material.Cobblestone, { cover = true })
	end
	-- gold pillars either side of the gateway, and a few fountains of cover in the courtyard
	for _, side in { -1, 1 } do
		k:cyl("GatePillar", side * 22, 0, 52, 6, 22, GOLD, Enum.Material.Metal)
		k:box("CourtBlock", side * 40, 0, 40, 8, 5, 4, DARK, Enum.Material.Slate, { cover = true })
		k:box("CourtBlock", side * 14, 0, 62, 4, 5, 8, DARK, Enum.Material.Slate, { cover = true })
	end

	-- the secret: a small stone room behind the head, its doorway hidden behind a stub wall. Free Aura Stash inside.
	k:room("Secret", 0, 0, -50, 12, 9, 10, 1.5, DARK, Enum.Material.Slate, { E = { w = 5, h = 7 } }, DARK, true)
	k:box("StubWall", 9, 0, -50, 2, 9, 11, STONE, Enum.Material.Cobblestone, { cover = true })
	Common.stash(folder, k:at(-2, 0, -50), territory.id)

	Common.sparkles(folder, "GateSparkles", k:at(0, 8, 34), GOLD, 10, 60)
	Common.ambience(folder, k:at(0, 10, 0), Ambience.gigachad_gate, 0.35)
end
