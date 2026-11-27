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

local RED = Color3.fromRGB(215, 55, 55)
local WHITE = Color3.fromRGB(245, 245, 245)
local GOLD = Color3.fromRGB(255, 200, 40)
local STONE = Color3.fromRGB(105, 95, 115)
local ISLAND_Y = 12 -- the rock island's flat top, where the tower stands
local DECK = 72 -- height of the lamp deck above the island

return function(folder: Folder, territory: any)
	local cx, cz = territory.x, territory.z
	Cover.reserve(cx, cz, 78, 78)

	-- the moat, the rocky island in it, and a sand causeway from the east
	TerrainKit.pond(cx, cz, 72, 10)
	TerrainKit.cylinder(cx, -10, cz, 36, 22, Enum.Material.Rock) -- flat top at y = 12
	TerrainKit.dome(cx, cz, 62, 12, Enum.Material.Rock)
	TerrainKit.block(cx + 58, -2, cz, 40, 2, 12, Enum.Material.Sand)
	-- the secret cave: carved into the rock from the west, behind two boulders
	TerrainKit.carve(cx - 26, 0, cz + 10, 16, 8, 16)
	TerrainKit.carve(cx - 44, 0, cz + 10, 24, 8, 4)

	local k = Kit.new(folder, cx, cz, ISLAND_Y)
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
	k:ball("CaveBoulder", -46, -ISLAND_Y + 1, 8, 7, 6, 7, STONE, Enum.Material.Rock, { cover = true })
	k:ball("CaveBoulder", -46, -ISLAND_Y + 1, 15, 8, 6, 6, STONE, Enum.Material.Rock, { cover = true })
	Common.stash(folder, k:at(-26, -ISLAND_Y, 10), territory.id)
	for index = 0, 5 do
		local ring = index / 6 * math.pi * 2
		Common.sparkles(folder, "Foam" .. index, k:at(math.cos(ring) * 68, -ISLAND_Y + 0.5, math.sin(ring) * 68), Color3.new(1, 1, 1), 4, 90)
	end
	Common.ambience(folder, k:at(0, 6, 0), Ambience.locked_in_lighthouse, 0.4)
end
