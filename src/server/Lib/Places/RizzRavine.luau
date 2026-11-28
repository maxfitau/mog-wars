--!strict
-- Rizz Ravine (Diamond, east): a deep pink-rock ravine. A flag sits on top of each cliff, with a rope bridge across
-- and a giant HOLLOW balloon-heart hanging over the middle of the bridge that you walk through. Jump pads either
-- side of the heart. Secret: a ledge path under the bridge with a free Aura Stash. Gentle grass hills lead up to the
-- cliff tops from the west. Palette: rose pink, white rope, warm gold. Cliffs: limestone.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ambience = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Ambience"))
local Detail = require(script.Parent.Parent:WaitForChild("Detail"))
local Cover = require(script.Parent.Parent:WaitForChild("Cover"))
local Common = require(script.Parent:WaitForChild("Common"))
local Kit = require(script.Parent.Parent:WaitForChild("Kit"))
local TerrainKit = require(script.Parent.Parent:WaitForChild("TerrainKit"))
local SkyKit = require(script.Parent.Parent:WaitForChild("SkyKit"))

local PINK = Color3.fromRGB(255, 95, 165)
local ROSE = Color3.fromRGB(240, 130, 180)
local ROPE = Color3.fromRGB(235, 220, 190)
local PLANK = Color3.fromRGB(190, 140, 90)
local DECK_Y = 24 -- the bridge deck and both cliff tops

return function(folder: Folder, territory: any)
	local cx, cz = territory.x, territory.z
	local k = Kit.new(folder, cx, cz, territory.height)
	Cover.reserve(cx + 10, cz, 50, 75)
	SkyKit.island(cx, cz, territory.height, territory.radius, 70)
	SkyKit.vines(folder, cx, cz, territory.height, territory.radius, 16)
	SkyKit.waterfall(folder, Vector3.new(cx - territory.radius + 3, territory.height, cz + 30), Vector3.new(-1, 0, 0), 45)
	SkyKit.waterfall(folder, Vector3.new(cx + territory.radius - 3, territory.height, cz - 30), Vector3.new(1, 0, 0), 45)
	SkyKit.waterfallStash(folder, Vector3.new(cx + territory.radius - 3, territory.height, cz - 30), Vector3.new(1, 0, 0), territory.id, "rizz_waterfall")

	-- the ravine: pink limestone cliffs 24 high on the north and south, a pink floor between, grassy caps on top
	TerrainKit.block(cx, -2, cz, 72, 2, 64, Enum.Material.Limestone) -- ravine floor
	for _, side in { -1, 1 } do
		TerrainKit.block(cx, 0, cz + side * 42, 72, 24, 36, Enum.Material.Limestone)
		TerrainKit.block(cx, 22, cz + side * 42, 72, 2, 36, Enum.Material.Salt)
		TerrainKit.dome(cx - 46, cz + side * 42, 75, 24, Enum.Material.Salt) -- the way up: a wide, gentle hill from the west
	end

	-- layered pink cliffs: coloured strata bands on both faces of the ravine, and a waterfall pouring into it
	for _, side in { -1, 1 } do
		for band, colour in { Color3.fromRGB(255, 160, 205), Color3.fromRGB(235, 110, 170), Color3.fromRGB(255, 190, 220), Color3.fromRGB(205, 85, 150) } do
			k:box("CliffStrata", 0, (band - 1) * 6, side * 24.4, 70, 3.5, 1, colour, Enum.Material.Limestone, { collide = false })
		end
	end
	local fall = k:box("RavineFall", -22, 0, -24.9, 5, 24, 1, Color3.fromRGB(190, 230, 255), Enum.Material.Glass, { collide = false, transparency = 0.45 })
	Common.sparkles(folder, "RavineMist", fall.Position - Vector3.new(0, 11, -2), Color3.fromRGB(235, 245, 255), 8, 50)
	k:cyl("RavinePool", -22, 0, -20, 14, 0.4, Color3.fromRGB(110, 190, 235), Enum.Material.Glass, { collide = false, transparency = 0.3 })
	-- flowers on both cliff tops
	for index = 1, 44 do
		local side = if index % 2 == 0 then 1 else -1
		local x = ((index * 37) % 64) - 32
		local z = side * (30 + ((index * 53) % 26))
		k:cyl("FlowerStem", x, DECK_Y, z, 0.3, 1.8, Color3.fromRGB(70, 150, 70), Enum.Material.Grass, { collide = false })
		k:ball("Flower", x, DECK_Y + 1.6, z, 1.4, 1.4, 1.4, ({ Color3.fromRGB(255, 120, 190), Color3.new(1, 1, 1), Color3.fromRGB(255, 220, 90), Color3.fromRGB(190, 120, 255) })[index % 4 + 1], Enum.Material.Marble, { collide = false })
	end
	-- the rope bridge: individual planks (with little gaps) and rails
	for index = 0, 24 do
		k:box("BridgePlank", 0, DECK_Y - 1, -24 + index * 2, 9, 0.9, 1.7, PLANK, Enum.Material.WoodPlanks)
	end
	k:box("BridgeKeel", 0, DECK_Y - 1.6, 0, 1.2, 0.6, 52, Color3.fromRGB(120, 85, 50), Enum.Material.Wood, { collide = false })
	for _, side in { -1, 1 } do
		k:box("RopeRail", side * 4.4, DECK_Y + 3, 0, 0.5, 0.5, 52, ROPE, Enum.Material.Fabric, { collide = false })
		for _, z in { -24, -12, 0, 12, 24 } do
			k:box("RopePost", side * 4.4, DECK_Y, z, 0.7, 3.2, 0.7, ROPE, Enum.Material.Wood, { collide = false })
		end
		for _, z in { -20, -10, 10, 20 } do -- glowing lanterns hanging along the bridge
			k:box("LanternCord", side * 4.4, DECK_Y + 3, z, 0.15, 1.2, 0.15, ROPE, Enum.Material.Fabric, { collide = false })
			local lantern = k:ball("Lantern", side * 4.4, DECK_Y + 1.6, z, 1.5, 1.8, 1.5, Color3.fromRGB(255, 205, 110), Enum.Material.Neon, { collide = false })
			local glow = Instance.new("PointLight")
			glow.Color = Color3.fromRGB(255, 200, 120)
			glow.Range = 12
			glow.Parent = lantern
		end
	end

	-- the giant hollow heart: a balloon outline of big pink balls front and back, translucent skin, a deck to walk across
	local scale = 1.45
	local centreY = DECK_Y + 25 -- the heart's tip just touches the bridge deck
	local steps = 32
	for _, z in { -10, 10 } do
		for index = 0, steps - 1 do
			local t = index / steps * math.pi * 2
			local hx = 16 * math.sin(t) ^ 3
			local hy = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
			local part = k:ball("HeartBalloon", hx * scale, centreY + hy * scale - 2.5, z, 5, 5, 5, if index % 2 == 0 then PINK else ROSE, Enum.Material.Foil, { cover = true })
			part.Reflectance = 0.15
		end
	end
	for _, z in { -10.5, 10.5 } do
		k:ball("HeartSkin", 0, centreY - 20, z, 46, 42, 0.8, PINK, Enum.Material.Glass, { collide = false, transparency = 0.8 })
	end
	k:box("HeartDeck", 0, DECK_Y - 1, 0, 24, 1, 24, Color3.fromRGB(255, 190, 215), Enum.Material.WoodPlanks)
	local heart = k:box("HeartCentre", 0, centreY - 1, 0, 1, 1, 1, PINK, Enum.Material.Neon, { collide = false, transparency = 1 })
	CollectionService:AddTag(heart, "RizzHeart") -- the moment bursts from here
	heart:SetAttribute("Territory", territory.id)
	for index, offset in { { -12, 8 }, { 12, 8 }, { 0, -2 }, { 0, 18 }, { -6, 22 }, { 6, 22 } } do
		Common.sparkles(folder, "HeartSparkles" .. index, k:at(offset[1], centreY + offset[2] - 10, 0), Color3.fromRGB(255, 190, 235), 12)
	end
	-- jump pads either side of the heart: they throw you up over its edge
	for _, side in { -1, 1 } do
		local pad = k:box("JumpPad", 0, DECK_Y - 0.2, side * 17, 5, 0.6, 5, Color3.fromRGB(255, 80, 170), Enum.Material.Neon, { collide = false })
		pad:SetAttribute("Launch", Vector3.new(0, 78, -side * 20))
		CollectionService:AddTag(pad, "LaunchPad")
	end

	-- cliff tops: pink crystals and rocks for cover, so each flag has somewhere to fight from
	for _, side in { -1, 1 } do
		for index, spot in { { -20, 8 }, { 22, 10 }, { -8, 18 }, { 10, 16 }, { -26, -6 }, { 28, -8 } } do
			local z = side * (42 + spot[2] * 0.0) + (-side) * spot[2] * 0.0
			if index % 2 == 0 then
				k:ball("CliffRock", spot[1], DECK_Y, z + spot[2] * side * 0.6, 7, 5, 7, ROSE, Enum.Material.Rock, { cover = true })
			else
				local crystal = k:box("Crystal", spot[1], DECK_Y, z + spot[2] * side * 0.6, 3, 7, 3, Color3.fromRGB(255, 150, 210), Enum.Material.Glass, { cover = true, rotY = index })
				crystal.Transparency = 0.2
			end
		end
	end

	-- the secret: stepping rocks under the bridge up to a ledge on the north cliff face, a free Aura Stash on it
	for index = 1, 4 do
		k:cyl("LedgeRock", 0, 0, -6 - index * 3.4, 5, index * 2.6, ROSE, Enum.Material.Rock)
	end
	k:box("Ledge", 0, 10.5, -22, 10, 1, 6, PINK, Enum.Material.Rock)
	Common.stash(folder, k:at(0, 11.5, -22), territory.id)

	-- ===== DETAIL PASS (see ART.md): pink grass, blossom trees, plank paths, torii gates, gardens, a stream, a bow on the heart =====
	local rng = Random.new(77)
	local capY = territory.height + DECK_Y
	local world = function(x: number, z: number): Vector3
		return Vector3.new(cx + x, capY, cz + z)
	end
	local blossom = { Color3.fromRGB(255, 160, 205), Color3.fromRGB(245, 120, 175), Color3.fromRGB(255, 195, 220) }
	for _, side in { -1, 1 } do
		-- plank paths from the western hill to the flag, and from the flag to the bridge end
		Detail.plankPath(folder, world(-60, side * 42), world(-8, side * 42), 6, rng)
		Detail.plankPath(folder, world(0, side * 36), world(0, side * 25.5), 7, rng)
		-- cherry-blossom trees along the cliff edges and in the corners
		for index = 1, 6 do
			Detail.tree(folder, world(-34 + index * 11, side * (56 + (index % 2) * 2)), 1, blossom[index % 3 + 1], rng)
		end
		Detail.tree(folder, world(-40, side * 30), 1.1, blossom[1], rng)
		Detail.tree(folder, world(36, side * 32), 1.1, blossom[2], rng)
		Detail.leaves(folder, world(-20, side * 50) + Vector3.new(0, 18, 0), blossom[1]) -- drifting petals
		Detail.leaves(folder, world(24, side * 50) + Vector3.new(0, 18, 0), blossom[3])
		-- gardens round the flags, pink paper-lantern posts, a torii gate at each bridge end
		Detail.flowerBed(folder, world(-14, side * 42), Vector3.zAxis, 10, 4, rng)
		Detail.flowerBed(folder, world(14, side * 42), Vector3.zAxis, 10, 4, rng)
		Detail.flowerBed(folder, world(-26, side * 48), Vector3.xAxis, 12, 4, rng)
		for _, x in { -8, 8 } do
			Detail.lanternPost(folder, world(x, side * 30), true)
			Detail.bush(folder, world(x * 2.2, side * 28), 1.2, rng)
		end
		for _, x in { -6, 6 } do
			k:cyl("ToriiPost", x, DECK_Y, side * 28, 1.6, 13, Color3.fromRGB(235, 70, 100), Enum.Material.Wood)
		end
		k:box("ToriiBeam", 0, DECK_Y + 11, side * 28, 17, 1.2, 1.8, Color3.fromRGB(235, 70, 100), Enum.Material.Wood, { collide = false })
		k:box("ToriiCap", 0, DECK_Y + 12.2, side * 28, 20, 0.9, 2.6, Color3.fromRGB(70, 48, 40), Enum.Material.Wood, { collide = false })
		k:box("ToriiTie", 0, DECK_Y + 8.6, side * 28, 15, 0.8, 1.2, Color3.fromRGB(235, 70, 100), Enum.Material.Wood, { collide = false })
		Detail.rocks(folder, world(-30, side * 36), rng, 5)
		Detail.rocks(folder, world(32, side * 46), rng, 5)
	end
	Detail.tuftRing(folder, Vector3.new(cx, capY, cz), 14, 100, 140, rng)
	-- the ravine floor: a gentle stream with lily pads, and rocks along its edges
	k:box("RavineStream", 0, 0, 0, 70, 0.3, 9, Color3.fromRGB(150, 215, 245), Enum.Material.Glass, { collide = false, transparency = 0.35 })
	for index = 1, 8 do
		k:cyl("LilyPad", -30 + index * 7, 0.3, -2 + (index % 3) * 2, 3, 0.2, Color3.fromRGB(110, 190, 90), Enum.Material.Grass, { collide = false })
	end
	Detail.rocks(folder, Vector3.new(cx - 20, territory.height + 0.5, cz + 6), rng, 6)
	Detail.rocks(folder, Vector3.new(cx + 24, territory.height + 0.5, cz - 6), rng, 6)
	-- the heart's big bow and gold knot
	for _, side in { -1, 1 } do
		k:ball("HeartBow", side * 4, centreY + 4, 0, 6, 4, 4, Color3.fromRGB(255, 120, 185), Enum.Material.Foil, { collide = false })
	end
	k:ball("HeartKnot", 0, centreY + 4, 0, 3, 3, 3, Color3.fromRGB(255, 200, 60), Enum.Material.Metal, { collide = false })
	Detail.fireflies(folder, world(0, 45) + Vector3.new(0, 5, 0), Vector3.new(60, 8, 20))
	Detail.fireflies(folder, world(0, -45) + Vector3.new(0, 5, 0), Vector3.new(60, 8, 20))

	Common.ambience(folder, k:at(0, 20, 0), Ambience.rizz_ravine, 0.35)
end
