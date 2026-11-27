--!strict
-- Rizz Ravine (Diamond, east): a deep pink-rock ravine. A flag sits on top of each cliff, with a rope bridge across
-- and a giant HOLLOW balloon-heart hanging over the middle of the bridge that you walk through. Jump pads either
-- side of the heart. Secret: a ledge path under the bridge with a free Aura Stash. Gentle grass hills lead up to the
-- cliff tops from the west. Palette: rose pink, white rope, warm gold. Cliffs: limestone.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ambience = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Ambience"))
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

	-- the ravine: pink limestone cliffs 24 high on the north and south, a pink floor between, grassy caps on top
	TerrainKit.block(cx, -2, cz, 72, 2, 64, Enum.Material.Limestone) -- ravine floor
	for _, side in { -1, 1 } do
		TerrainKit.block(cx, 0, cz + side * 42, 72, 24, 36, Enum.Material.Limestone)
		TerrainKit.block(cx, 22, cz + side * 42, 72, 2, 36, Enum.Material.LeafyGrass)
		TerrainKit.dome(cx - 46, cz + side * 42, 75, 24, Enum.Material.LeafyGrass) -- the way up: a wide, gentle hill from the west
	end

	-- the rope bridge: planks and rails
	k:box("BridgePlanks", 0, DECK_Y - 1, 0, 9, 1, 52, PLANK, Enum.Material.WoodPlanks)
	for _, side in { -1, 1 } do
		k:box("RopeRail", side * 4.4, DECK_Y + 3, 0, 0.5, 0.5, 52, ROPE, Enum.Material.Fabric, { collide = false })
		for _, z in { -24, -12, 0, 12, 24 } do
			k:box("RopePost", side * 4.4, DECK_Y, z, 0.7, 3.2, 0.7, ROPE, Enum.Material.Wood, { collide = false })
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
			local part = k:ball("HeartBalloon", hx * scale, centreY + hy * scale - 2.5, z, 5, 5, 5, if index % 2 == 0 then PINK else ROSE, Enum.Material.SmoothPlastic, { cover = true })
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

	Common.ambience(folder, k:at(0, 20, 0), Ambience.rizz_ravine, 0.35)
end
