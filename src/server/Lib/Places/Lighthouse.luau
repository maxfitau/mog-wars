--!strict
-- Locked-In Lighthouse (Diamond, west): a round, tapered tower on a rocky island, red and white stripes, a spiral staircase
-- inside, a gallery balcony all round the top, and a giant golden PADLOCK for a lamp room with a turning beam. The base
-- flag is by the door (east side), the top flag is in the padlock. Rocks round the base are cover. Secret: a cellar down
-- a ladder with a free Aura Stash. Palette: red and white, gold, sea blue. Island: dark rock.

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
local DECK = 72 -- height of the gallery and lamp deck above the island
local SIDES = 16 -- the tower is a ring of 16 slabs per band, which reads as round

-- The slabs of one round band: width along the ring, height `h`, thickness 2.4, facing outward.
local function band(k: any, name: string, radius: number, yb: number, h: number, colour: Color3, skipIndex: number?)
	local width = 2 * radius * math.tan(math.pi / SIDES) * 1.04
	for index = 0, SIDES - 1 do
		if index ~= skipIndex then
			local angle = index * 2 * math.pi / SIDES
			local piece = k:box(name, math.cos(angle) * (radius - 1.2), yb, math.sin(angle) * (radius - 1.2), width, h, 2.4, colour, Enum.Material.Concrete, { cover = true })
			piece.CFrame = CFrame.lookAt(piece.Position, piece.Position + Vector3.new(math.cos(angle), 0, math.sin(angle)))
		end
	end
end

return function(folder: Folder, territory: any)
	local cx, cz = territory.x, territory.z
	Cover.reserve(cx, cz, 78, 78)

	-- the rocky island, bare rock round the tower, roots and a waterfall
	SkyKit.island(cx, cz, territory.height, territory.radius, 70)
	SkyKit.vines(folder, cx, cz, territory.height, territory.radius, 14)
	SkyKit.waterfall(folder, Vector3.new(cx + territory.radius - 3, territory.height, cz + 14), Vector3.new(1, 0, 0), 45)
	TerrainKit.cylinder(cx, -3, cz, 62, 3, Enum.Material.Rock)
	-- the secret cellar: down a shaft with a ladder (the shaft is 4 studs wide so the edges are clean)
	TerrainKit.carve(cx - 30, -16, cz + 10, 16, 12, 16)
	TerrainKit.carve(cx - 30, -4, cz + 10, 4, 4, 4)

	local k = Kit.new(folder, cx, cz, territory.height)

	-- a rocky base: boulders heaped round the foot of the tower
	for index = 0, 11 do
		local angle = index / 12 * math.pi * 2 + 0.2
		local reach = 26 + (index % 3) * 4
		local size = 12 + (index % 4) * 3
		if math.abs(math.atan2(math.sin(angle), math.cos(angle))) > 0.55 then -- keep the doorway (east) clear
			k:ball("BaseBoulder", math.cos(angle) * reach, -2, math.sin(angle) * reach, size, size * 0.7, size, Color3.fromRGB(100 + index * 3, 92, 108), Enum.Material.Rock, { cover = index % 2 == 0 })
		end
	end

	-- the tapered tower: six bands, red and white, each a little narrower than the one below; a doorway on the east side
	local bandHeight = DECK / 6
	for index = 0, 5 do
		local radius = 20 - index * 1.1
		local colour = if index % 2 == 0 then RED else WHITE
		if index == 0 then
			band(k, "TowerWall", radius, 0, bandHeight, colour, 0) -- slab 0 faces east: left out to make the door
			local width = 2 * radius * math.tan(math.pi / SIDES) * 1.04
			local lintel = k:box("TowerLintel", radius - 1.2, 9, 0, width, bandHeight - 9, 2.4, colour, Enum.Material.Concrete)
			lintel.CFrame = CFrame.lookAt(lintel.Position, lintel.Position + Vector3.xAxis)
		else
			band(k, "TowerWall", radius, index * bandHeight, bandHeight, colour)
		end
	end

	-- the spiral staircase inside (visible steps; the invisible ramp over them is what you walk on)
	k:spiral("LighthouseStair", 0, 0, 3.5, 10.5, 0, DECK, 3.5, math.pi, 1, Color3.fromRGB(150, 130, 110), Enum.Material.WoodPlanks)
	k:cyl("StairCore", 0, 0, 0, 5, DECK - 1, WHITE, Enum.Material.Concrete)

	-- the gallery: a ring-shaped balcony all round the top (a hole in the middle for the stairs), with a gold railing
	for index = 0, SIDES - 1 do
		local angle = index * 2 * math.pi / SIDES
		local deck = k:box("GalleryDeck", math.cos(angle) * 19.5, DECK - 2, math.sin(angle) * 19.5, 11, 2, 15, STONE, Enum.Material.Concrete)
		deck.CFrame = CFrame.lookAt(deck.Position, deck.Position + Vector3.new(math.cos(angle), 0, math.sin(angle)))
		local rail = k:box("GalleryRail", math.cos(angle) * 26.6, DECK, math.sin(angle) * 26.6, 10.8, 3, 0.6, GOLD, Enum.Material.Metal, { cover = true })
		rail.CFrame = CFrame.lookAt(rail.Position, rail.Position + Vector3.new(math.cos(angle), 0, math.sin(angle)))
	end

	-- the lamp room is a giant golden PADLOCK: a hollow gold body with a shackle, shining a turning beam
	k:box("PadlockFloor", 20, DECK - 1, 0, 18, 1, 22, GOLD, Enum.Material.Metal)
	k:room("Padlock", 20, DECK, 0, 18, 22, 22, 1.5, GOLD, Enum.Material.Metal, { W = { w = 8, h = 9 }, E = { w = 8, h = 9 } }, nil, true)
	k:box("Keyhole", 20, DECK + 7, 11.4, 3, 6, 0.4, Color3.fromRGB(30, 25, 20), Enum.Material.Slate, { collide = false })
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
	local sweep = 0
	task.spawn(function()
		while beam.Parent do
			task.wait(0.1) -- ten small steps a second: one part, cheap
			sweep += math.rad(4)
			local direction = Vector3.new(math.cos(sweep), 0, math.sin(sweep))
			beam.CFrame = CFrame.lookAt(pivot + direction * 60, pivot + direction * 120)
		end
	end)

	-- crates and a mooring post at the foot for more cover, and the secret cellar's hatch and ladder
	for index, spot in { { 30, -16 }, { 31, 12 }, { 16, 32 }, { -12, 32 }, { 22, -30 } } do
		k:box("Crate", spot[1], 0, spot[2], 4.5, 4.5, 4.5, Color3.fromRGB(190, 140, 80), Enum.Material.WoodPlanks, { cover = true, rotY = index })
	end
	k:box("CellarRim", -30, 0, 10, 6, 1.5, 6, STONE, Enum.Material.Cobblestone, { collide = false }) -- the hatch frame
	k:truss("CellarLadder", -29, -16, 10, 17)
	Common.stash(folder, k:at(-34, -16, 14), territory.id)
	Common.ambience(folder, k:at(0, 6, 0), Ambience.locked_in_lighthouse, 0.4)
end
