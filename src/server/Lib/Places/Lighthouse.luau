--!strict
-- Locked-In Lighthouse (Diamond, west): a striped lighthouse on a rocky island in a moat (a sand causeway leads in from
-- the east). A spiral staircase winds up INSIDE; the base flag is by the door, the top flag is in the lamp room: a giant
-- golden padlock on a balcony deck, with a turning beam. Secret: a cave in the rock with a free Aura Stash.
-- Palette: red and white stripes, gold, sea blue. Island: dark rock.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ambience = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Ambience"))
local Cover = require(script.Parent.Parent:WaitForChild("Cover"))
local Common = require(script.Parent:WaitForChild("Common"))
local Kit = require(script.Parent.Parent:WaitForChild("Kit"))
local TerrainKit = require(script.Parent.Parent:WaitForChild("TerrainKit"))
local SkyKit = require(script.Parent.Parent:WaitForChild("SkyKit"))

local RED = Color3.fromRGB(215, 55, 55)
local WHITE = Color3.fromRGB(245, 245, 245)
local GOLD = Color3.fromRGB(255, 200, 40)
local STONE = Color3.fromRGB(105, 95, 115)
local ISLAND_Y = 0 -- the island top is the ground (Kit is built on it)
local DECK = 72 -- height of the lamp deck above the island

return function(folder: Folder, territory: any)
	local cx, cz = territory.x, territory.z
	Cover.reserve(cx, cz, 78, 78)

	-- the rocky island itself, a flat top where the tower stands, with roots and waterfalls round the rim
	SkyKit.island(cx, cz, territory.height, territory.radius, 70)
	SkyKit.vines(folder, cx, cz, territory.height, territory.radius, 14)
	SkyKit.waterfall(folder, Vector3.new(cx + territory.radius - 3, territory.height, cz + 14), Vector3.new(1, 0, 0), 45)
	TerrainKit.cylinder(cx, -3, cz, 60, 3, Enum.Material.Rock) -- bare rock round the tower
	-- the secret: a cellar carved into the rock, down a shaft with a ladder (4 studs wide, so the edges are clean)
	TerrainKit.carve(cx - 26, -16, cz + 10, 16, 12, 16)
	TerrainKit.carve(cx - 26, -4, cz + 10, 4, 4, 4)

	local k = Kit.new(folder, cx, cz, territory.height)
	-- the tower: eight walls in a ring, five red and white stripes each, a doorway on the east side
	local stripe = DECK / 5
	for index = 0, 7 do
		local angle = index * math.pi / 4
		local px, pz = math.cos(angle) * 19.5, math.sin(angle) * 19.5
		for band = 0, 4 do
			local colour = if band % 2 == 0 then RED else WHITE
			local yb = band * stripe
			if index == 0 and band == 0 then
				-- the door wall's first band: two side pieces and a lintel
				for _, side in { -1, 1 } do
					local piece = k:box("TowerWall", px, yb, pz + side * 5.6, 5.2, stripe, 3, colour, Enum.Material.Concrete, { cover = true })
					piece.CFrame = CFrame.lookAt(piece.Position, piece.Position + Vector3.new(math.cos(angle), 0, math.sin(angle)))
				end
				local lintel = k:box("TowerWall", px, yb + 9, pz, 6.2, stripe - 9, 3, colour, Enum.Material.Concrete)
				lintel.CFrame = CFrame.lookAt(lintel.Position, lintel.Position + Vector3.new(math.cos(angle), 0, math.sin(angle)))
			else
				local piece = k:box("TowerWall", px, yb, pz, 16.6, stripe, 3, colour, Enum.Material.Concrete, { cover = true })
				piece.CFrame = CFrame.lookAt(piece.Position, piece.Position + Vector3.new(math.cos(angle), 0, math.sin(angle)))
			end
		end
	end
	-- the spiral staircase inside, 72 steps up in 3.5 turns, then through a hole in the lamp deck
	k:spiral("LighthouseStair", -2, 0, 3, 12.5, 0, DECK, 3.5, 0, 1, Color3.fromRGB(150, 130, 110), Enum.Material.WoodPlanks)
	k:cyl("StairCore", -2, 0, 0, 5, DECK - 2, WHITE, Enum.Material.Concrete)

	-- the lamp deck with a balcony all round, a hole where the stairs come up, and a railing
	k:box("DeckW", -22, DECK - 2, 0, 14, 2, 58, STONE, Enum.Material.Concrete)
	k:box("DeckE", 26, DECK - 2, 0, 30, 2, 58, STONE, Enum.Material.Concrete)
	k:box("DeckN", -2, DECK - 2, -21, 26, 2, 16, STONE, Enum.Material.Concrete)
	k:box("DeckS", -2, DECK - 2, 21, 26, 2, 16, STONE, Enum.Material.Concrete)
	k:box("RailN", 6, DECK, -28, 70, 3, 1, GOLD, Enum.Material.Metal, { cover = true })
	k:box("RailS", 6, DECK, 28, 70, 3, 1, GOLD, Enum.Material.Metal, { cover = true })
	k:box("RailW", -28.5, DECK, 0, 1, 3, 58, GOLD, Enum.Material.Metal, { cover = true })
	k:box("RailE", 40.5, DECK, 0, 1, 3, 58, GOLD, Enum.Material.Metal, { cover = true })

	-- the lamp room is a giant golden PADLOCK: a hollow gold body with a shackle, shining a turning beam
	k:room("Padlock", 20, DECK, 0, 18, 22, 22, 1.5, GOLD, Enum.Material.Metal, { W = { w = 8, h = 9 }, E = { w = 8, h = 9 } }, nil, true)
	k:box("Keyhole", 20, DECK + 7, 11.4, 3, 6, 0.4, Color3.fromRGB(30, 25, 20), Enum.Material.SmoothPlastic, { collide = false })
	k:cyl("ShackleL", 14, DECK + 23, 0, 3, 14, GOLD, Enum.Material.Metal, { collide = false })
	k:cyl("ShackleR", 26, DECK + 23, 0, 3, 14, GOLD, Enum.Material.Metal, { collide = false })
	k:box("ShackleTop", 20, DECK + 36, 0, 15, 3, 3, GOLD, Enum.Material.Metal, { collide = false })
	local lamp = k:ball("Lamp", 20, DECK + 8, 0, 6, 6, 6, Color3.fromRGB(255, 250, 190), Enum.Material.Neon, { collide = false })
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 240, 150)
	light.Range = 60
	light.Brightness = 3
	light.Parent = lamp
	local beam = k:box("Beam", 20, DECK + 38, 0, 6, 6, 120, Color3.fromRGB(255, 245, 160), Enum.Material.Neon, { collide = false, transparency = 0.6 })
	beam.CanQuery = false
	CollectionService:AddTag(beam, "LampBeam")
	beam:SetAttribute("Territory", territory.id)
	local pivot = beam.Position
	local angle = 0
	task.spawn(function()
		while beam.Parent do
			task.wait(0.1) -- ten small steps a second: one part, cheap
			angle += math.rad(4)
			local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
			beam.CFrame = CFrame.lookAt(pivot + direction * 60, pivot + direction * 120)
		end
	end)

	-- rocks for cover round the base, the secret cave's boulders, and sea foam
	for index, spot in { { 28, -14 }, { 30, 10 }, { 14, 28 }, { -10, 30 }, { -30, 0 }, { -6, -30 }, { 22, -26 }, { 25, 26 } } do
		k:ball("IslandRock", spot[1], 0, spot[2], 7, 5, 7, Color3.fromRGB(95, 88, 108), Enum.Material.Rock, { cover = true })
		if index % 3 == 0 then
			k:box("Crate", spot[1] + 5, 0, spot[2], 4, 4, 4, Color3.fromRGB(190, 140, 80), Enum.Material.WoodPlanks, { cover = true })
		end
	end
	k:box("CellarRim", -26, 0, 10, 6, 1.5, 6, STONE, Enum.Material.Cobblestone) -- the hatch frame: a ladder goes down the shaft
	k:truss("CellarLadder", -25, -16, 10, 17)
	Common.stash(folder, k:at(-30, -16, 14), territory.id)
	for index = 0, 5 do
		local ring = index / 6 * math.pi * 2
		Common.sparkles(folder, "Foam" .. index, k:at(math.cos(ring) * 68, -ISLAND_Y + 0.5, math.sin(ring) * 68), Color3.new(1, 1, 1), 4, 90)
	end
	Common.ambience(folder, k:at(0, 6, 0), Ambience.locked_in_lighthouse, 0.4)
end
