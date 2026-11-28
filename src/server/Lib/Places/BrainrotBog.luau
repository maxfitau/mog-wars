--!strict
-- Brainrot Bog (Gold, south-west): a foggy green swamp with ponds, lily-pad jumps and dead trees. The giant pink brain
-- is HOLLOW: walk in through the crack on its north side, wind through fleshy tunnels, and the flag stands in the
-- centre chamber. Secret: a hollow log tunnel with a free Aura Stash. Palette: swamp green and brain pink.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ambience = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Ambience"))
local Detail = require(script.Parent.Parent:WaitForChild("Detail"))
local Cover = require(script.Parent.Parent:WaitForChild("Cover"))
local Common = require(script.Parent:WaitForChild("Common"))
local Kit = require(script.Parent.Parent:WaitForChild("Kit"))
local TerrainKit = require(script.Parent.Parent:WaitForChild("TerrainKit"))
local SkyKit = require(script.Parent.Parent:WaitForChild("SkyKit"))

local PINK = Color3.fromRGB(255, 135, 178)
local PINK_DARK = Color3.fromRGB(232, 98, 150)
local FLESH = Color3.fromRGB(245, 120, 160)
local GREEN = Color3.fromRGB(110, 190, 70)
local WOOD = Color3.fromRGB(95, 70, 45)

local BRAIN_RADIUS = 34

-- The hollow brain: rings of big overlapping balls make a bumpy dome; a crack is left open on the north side.
local function brain(k: any)
	local rings = {
		{ lat = 20, count = 16, size = 22 },
		{ lat = 45, count = 12, size = 20 },
		{ lat = 70, count = 7, size = 18 },
	}
	for _, ring in rings do
		local lat = math.rad(ring.lat)
		local y = BRAIN_RADIUS * math.sin(lat)
		local radius = BRAIN_RADIUS * math.cos(lat)
		for index = 0, ring.count - 1 do
			local angle = index / ring.count * math.pi * 2
			-- north is -z, which is angle -pi/2: leave the lower two rings open there (the crack)
			local fromNorth = math.abs(math.atan2(math.sin(angle + math.pi / 2), math.cos(angle + math.pi / 2)))
			if not (ring.lat < 60 and fromNorth < 0.42) then
				local colour = if index % 2 == 0 then PINK else PINK_DARK
				k:ball("BrainBall", math.cos(angle) * radius, y - ring.size / 2, math.sin(angle) * radius, ring.size, ring.size, ring.size, colour, Enum.Material.Fabric)
			end
		end
	end
	k:ball("BrainBall", 0, BRAIN_RADIUS - 9, 0, 22, 18, 22, PINK, Enum.Material.Fabric)
	-- the core chamber: a ring of fleshy walls around the flag with one gap on the east side, so the way in winds round
	local count = 12
	for index = 0, count - 1 do
		local angle = index / count * math.pi * 2
		if math.abs(math.atan2(math.sin(angle), math.cos(angle))) > 0.3 then -- the gap faces east (angle 0)
			local part = k:box("CoreWall", math.cos(angle) * 15, 0, math.sin(angle) * 15, 8.2, 12, 2, FLESH, Enum.Material.Fabric, { cover = true })
			part.CFrame = CFrame.lookAt(part.Position, part.Position + Vector3.new(math.cos(angle), 0, math.sin(angle)))
		end
	end
	-- fleshy pillars in the outer tunnel, and a glow in the core
	for index = 0, 3 do
		local angle = math.rad(45 + index * 90)
		k:cyl("FleshPillar", math.cos(angle) * 21, 0, math.sin(angle) * 21, 4.5, 14, PINK_DARK, Enum.Material.Fabric, { cover = true })
	end
	local core = k:cyl("CoreGlow", 0, 0.05, 0, 14, 0.3, Color3.fromRGB(255, 170, 200), Enum.Material.Neon, { collide = false })
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 150, 190)
	light.Range = 30
	light.Brightness = 2
	light.Parent = core
end

local function deadTree(k: any, x: number, z: number, lean: number)
	k:box("DeadTrunk", x, 0, z, 2.5, 16, 2.5, WOOD, Enum.Material.Wood, { cover = true })
	for index, tilt in { 35, -40, 20 } do
		local branch = k:box("DeadBranch", x, 11 + index * 1.5, z, 1, 8, 1, WOOD, Enum.Material.Wood, { collide = false })
		branch.CFrame = CFrame.new(branch.Position) * CFrame.Angles(math.rad(tilt), math.rad(index * 90 + lean), math.rad(tilt))
	end
end

return function(folder: Folder, territory: any)
	local cx, cz = territory.x, territory.z
	local k = Kit.new(folder, cx, cz, territory.height)
	Cover.reserve(cx, cz, 105, 105)
	SkyKit.island(cx, cz, territory.height, territory.radius, 60)
	SkyKit.vines(folder, cx, cz, territory.height, territory.radius, 16)
	SkyKit.waterfall(folder, Vector3.new(cx - territory.radius + 3, territory.height, cz - 20), Vector3.new(-1, 0, 0), 40)
	TerrainKit.cylinder(cx, -6, cz, 105, 6, Enum.Material.Mud) -- swamp ground
	for index = 1, 10 do -- moss patches (the moss palette) over the mud
		local angle = index / 10 * math.pi * 2 + 0.3
		TerrainKit.cylinder(cx + math.cos(angle) * (30 + (index % 3) * 22), -6, cz + math.sin(angle) * (30 + (index % 3) * 22), 10 + (index % 4) * 3, 6, Enum.Material.LeafyGrass)
	end

	-- ponds, each with a ring of lily pads to jump across
	local ponds = { { -50, -40, 12 }, { 52, -34, 11 }, { -62, 28, 12 }, { 58, 42, 12 }, { -18, 68, 11 }, { 22, -72, 10 } }
	for _, pond in ponds do
		TerrainKit.pond(cx + pond[1], cz + pond[2], pond[3], 8)
		for pad = 0, 5 do
			local angle = pad / 6 * math.pi * 2 + pond[1] * 0.01
			local reach = pond[3] * 0.55
			k:cyl("LilyPad", pond[1] + math.cos(angle) * reach, -1.3, pond[2] + math.sin(angle) * reach, 5, 0.7, GREEN, Enum.Material.Grass)
		end
		k:cyl("LilyPad", pond[1], -1.3, pond[2], 5.5, 0.7, Color3.fromRGB(240, 130, 190), Enum.Material.Grass) -- a pink flower pad in the middle
	end
	-- stepping pads across the ponds toward the brain from the north and west, so there is always a dry-ish route
	for index = 1, 5 do
		k:cyl("LilyPad", -38 + index * 7, -1.3, -52 + index * 3, 4.5, 0.7, GREEN, Enum.Material.Grass)
	end

	brain(k)

	-- dead trees and swamp cover (stumps and mossy boulders)
	for index, spot in { { -78, -10 }, { 75, 10 }, { -30, 82 }, { 40, 88 }, { -85, 60 }, { 84, -50 }, { 8, -90 }, { -60, -78 } } do
		deadTree(k, spot[1], spot[2], index * 37)
	end
	for index, spot in { { -42, -12 }, { 40, -10 }, { -38, 44 }, { 36, 52 }, { 0, 50 }, { 0, -52 }, { 70, -14 }, { -72, 12 }, { 16, 84 }, { -48, 90 }, { 62, 70 }, { -22, -62 } } do
		if index % 2 == 0 then
			k:cyl("Stump", spot[1], 0, spot[2], 5, 4 + index % 3, WOOD, Enum.Material.Wood, { cover = true })
		else
			k:ball("MossRock", spot[1], 0, spot[2], 7, 5, 6, Color3.fromRGB(90, 130, 80), Enum.Material.Rock, { cover = true })
		end
	end

	-- the secret: a hollow log, open at the near end, a stash at the far end (behind a dead tree and a stump)
	local lx, lz = 66, -46
	k:box("LogFloor", lx, 0, lz, 22, 1, 8, WOOD, Enum.Material.Wood)
	k:box("LogRoof", lx, 7, lz, 22, 1.2, 8, WOOD, Enum.Material.Wood)
	k:box("LogSide", lx, 1, lz - 3.8, 22, 6, 1, WOOD, Enum.Material.Wood, { cover = true })
	k:box("LogSide", lx, 1, lz + 3.8, 22, 6, 1, WOOD, Enum.Material.Wood, { cover = true })
	k:box("LogEnd", lx + 11, 1, lz, 1, 6, 8, WOOD, Enum.Material.Wood)
	Common.stash(folder, k:at(lx + 8, 1, lz), territory.id)

	-- fog and bubbles
	for index, spot in { { 0, 0 }, { -50, -20 }, { 50, 20 }, { -20, 60 }, { 30, -60 }, { 0, 90 } } do
		Common.smoke(folder, "BogFog" .. index, k:at(spot[1], 2, spot[2]), Color3.fromRGB(150, 220, 130), 2, 22)
		Common.sparkles(folder, "Bubbles" .. index, k:at(spot[1] + 8, 0.5, spot[2] + 6), Color3.fromRGB(130, 255, 100), 5, 20)
	end
	-- ===== DETAIL PASS (see ART.md): boardwalks, glowing mushrooms, reeds, frogs, hanging moss, green light, fireflies =====
	local rng = Random.new(66)
	local world = function(x: number, z: number): Vector3
		return Vector3.new(cx + x, territory.height, cz + z)
	end
	Detail.plankPath(folder, world(-96, -60), world(-40, -30), 5, rng) -- boardwalks to the brain from the north-west and south-east
	Detail.plankPath(folder, world(-40, -30), world(-14, -6), 5, rng)
	Detail.plankPath(folder, world(96, 60), world(40, 30), 5, rng)
	Detail.plankPath(folder, world(40, 30), world(14, 6), 5, rng)
	for index = 1, 14 do -- lanterns along them, glowing swamp-green
		local x = if index <= 7 then -96 + index * 10 else 96 - (index - 7) * 10
		local z = if index <= 7 then -60 + index * 6 else 60 - (index - 7) * 6
		Detail.lanternPost(folder, world(x + 3, z - 3), index % 3 == 0)
	end
	for _, pond in ponds do
		Detail.reeds(folder, world(pond[1] + pond[3] * 0.8, pond[2] - pond[3] * 0.4), rng, 9)
		Detail.reeds(folder, world(pond[1] - pond[3] * 0.7, pond[2] + pond[3] * 0.6), rng, 7)
		local frog = k:ball("Frog", pond[1] + pond[3] * 0.3, -0.8, pond[2] - pond[3] * 0.2, 2, 1.4, 2.4, Color3.fromRGB(90, 180, 70), Enum.Material.Marble, { collide = false })
		for _, side in { -1, 1 } do
			k:ball("FrogEye", pond[1] + pond[3] * 0.3 + side * 0.6, 0.1, pond[2] - pond[3] * 0.2 - 0.6, 0.8, 0.8, 0.8, Color3.new(1, 1, 1), Enum.Material.Marble, { collide = false })
		end
		frog.CFrame = CFrame.new(frog.Position)
	end
	for index = 1, 26 do -- glowing mushrooms in toxic green, magenta and cyan
		local angle = index * 2.4
		local radius = 25 + (index * 13) % 70
		local spot = Detail.ground(cx + math.cos(angle) * radius, cz + math.sin(angle) * radius, territory.height)
		if spot then
			Detail.glowMushroom(folder, spot, ({ Color3.fromRGB(120, 255, 120), Color3.fromRGB(255, 110, 230), Color3.fromRGB(90, 240, 240) })[index % 3 + 1], 1 + (index % 3) * 0.3, index % 4 == 0)
		end
	end
	for index, spot in { { -78, -10 }, { 75, 10 }, { -30, 82 }, { 40, 88 }, { -85, 60 }, { 84, -50 } } do -- hanging moss on the dead trees
		for strand = 1, 4 do
			k:box("HangingMoss", spot[1] + (strand - 2.5) * 1.6, 5 + (strand % 2) * 2, spot[2] + (index % 2) * 1.2, 0.5, 4 + strand % 3, 0.5, Color3.fromRGB(95, 140, 70), Enum.Material.Grass, { collide = false })
		end
	end
	Detail.tuftRing(folder, Vector3.new(cx, territory.height, cz), 20, 98, 110, rng)
	Detail.rocks(folder, world(-60, 50), rng, 5)
	Detail.rocks(folder, world(64, -20), rng, 5)
	for index, spot in { { -50, 10 }, { 50, -10 }, { 0, 70 }, { 0, -70 } } do
		local glow = k:ball("BogGlow", spot[1], 6, spot[2], 2, 2, 2, Color3.fromRGB(120, 255, 130), Enum.Material.Neon, { collide = false, transparency = 0.4 })
		local light = Instance.new("PointLight") -- a green glow over the bog
		light.Color = Color3.fromRGB(120, 255, 130)
		light.Range = 36
		light.Brightness = 1.4
		light.Parent = glow
		Detail.fireflies(folder, world(spot[1], spot[2]) + Vector3.new(0, 4, 0), Vector3.new(36, 8, 36))
	end
	Common.ambience(folder, k:at(0, 6, 0), Ambience.brainrot_bog, 0.4)
end
