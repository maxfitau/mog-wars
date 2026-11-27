--!strict
-- Simple placeholder scenery for the six territories, built from blocks, cylinders and ramps. Detailed art
-- comes later. Positions come from src/shared/Territories.luau; the shapes here are loose decoration around
-- those positions (the flags themselves are built by PlaceholderMap). Nothing here needs any asset id.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Territories = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Territories"))
local Builder = require(script.Parent:WaitForChild("Builder"))

local SPARKLES = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local STONE = Color3.fromRGB(125, 125, 140)
local PURPLE = Color3.fromRGB(140, 60, 210)
local ROCK = Color3.fromRGB(150, 110, 90)

local TerritoryScenery = {}

local function solid(part: Part): Part
	part.CanCollide = true
	return part
end

local function decor(part: Part): Part
	part.CanCollide = false
	return part
end

-- ---------- Centre: Gigachad Gate, a stone fortress with purple banners ----------
local function gigachadGate(folder: Folder)
	local function block(name: string, x: number, y: number, z: number, sx: number, sy: number, sz: number, color: Color3)
		return solid(Builder.part(name, Vector3.new(sx, sy, sz), Vector3.new(x, y, z), color, folder))
	end
	-- two towers behind the left and right flags
	for _, side in { -1, 1 } do
		block("Tower", side * 30, 14, -14, 10, 28, 10, STONE)
		decor(Builder.part("Banner", Vector3.new(5, 14, 0.5), Vector3.new(side * 30, 17, -8.6), PURPLE, folder))
	end
	-- walls with an opening in the middle of each side, and the gate in the south wall
	block("WallNorthA", -28, 5, -34, 36, 10, 3, STONE)
	block("WallNorthB", 28, 5, -34, 36, 10, 3, STONE)
	block("WallEastA", 46, 5, -22, 3, 10, 24, STONE)
	block("WallEastB", 46, 5, 25, 3, 10, 30, STONE)
	block("WallWestA", -46, 5, -22, 3, 10, 24, STONE)
	block("WallWestB", -46, 5, 25, 3, 10, 30, STONE)
	block("WallSouthA", -29, 5, 40, 34, 10, 3, STONE)
	block("WallSouthB", 29, 5, 40, 34, 10, 3, STONE)
	-- the gate: two pillars and a top beam, with purple banners
	block("GatePillarLeft", -14, 10, 40, 6, 20, 6, STONE)
	block("GatePillarRight", 14, 10, 40, 6, 20, 6, STONE)
	block("GateBeam", 0, 22, 40, 34, 4, 6, STONE)
	decor(Builder.part("GateBannerLeft", Vector3.new(4, 12, 0.5), Vector3.new(-14, 12, 36.8), PURPLE, folder))
	decor(Builder.part("GateBannerRight", Vector3.new(4, 12, 0.5), Vector3.new(14, 12, 36.8), PURPLE, folder))
end

-- ---------- Inner ring: Rizz Ravine, two cliffs with a rope bridge between ----------
local function rizzRavine(folder: Folder)
	decor(Builder.part("RavineFloor", Vector3.new(48, 0.3, 20), Vector3.new(85, 0.15, -15), Color3.fromRGB(35, 28, 40), folder))
	solid(Builder.part("NorthCliff", Vector3.new(48, 5, 24), Vector3.new(85, 2.5, -37), ROCK, folder))
	solid(Builder.part("SouthCliff", Vector3.new(48, 5, 24), Vector3.new(85, 2.5, 7), ROCK, folder))
	Builder.ramp("NorthRamp", Vector3.new(85, 0, -70), Vector3.new(85, 5, -49), 10, ROCK, folder)
	Builder.ramp("SouthRamp", Vector3.new(85, 0, 43), Vector3.new(85, 5, 19), 10, ROCK, folder)
	-- the rope bridge: planks and two ropes across the gap
	solid(Builder.part("BridgePlanks", Vector3.new(6, 0.6, 20), Vector3.new(85, 4.7, -15), Color3.fromRGB(150, 110, 60), folder))
	decor(Builder.part("RopeLeft", Vector3.new(0.3, 0.3, 20), Vector3.new(82, 7, -15), Color3.fromRGB(200, 180, 130), folder))
	decor(Builder.part("RopeRight", Vector3.new(0.3, 0.3, 20), Vector3.new(88, 7, -15), Color3.fromRGB(200, 180, 130), folder))
end

-- ---------- Inner ring: Locked-In Lighthouse ----------
local function lighthouse(folder: Folder, territory: Territories.Territory)
	local top = territory.flags[2].y -- the height of the top platform
	local stripeHeight = (top - 1.5) / 4
	for index = 0, 3 do
		local color = if index % 2 == 0 then Color3.fromRGB(215, 55, 55) else Color3.fromRGB(240, 240, 240)
		solid(Builder.cylinder("Stripe" .. index, 12, stripeHeight, Vector3.new(territory.x, stripeHeight * (index + 0.5), territory.z), color, folder))
	end
	solid(Builder.part("TopPlatform", Vector3.new(22, 1.5, 22), Vector3.new(territory.x, top - 0.75, territory.z), Color3.fromRGB(240, 230, 200), folder))
	local lamp = Builder.part("Lamp", Vector3.new(4, 4, 4), Vector3.new(territory.x, top + 8, territory.z), Color3.fromRGB(255, 240, 150), folder)
	lamp.Material = Enum.Material.Neon
	lamp.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 240, 150)
	light.Range = 40
	light.Brightness = 2
	light.Parent = lamp
	-- a long ramp up to the platform from the west edge of the map
	Builder.ramp("LighthouseRamp", Vector3.new(-155, 0, territory.z), Vector3.new(territory.x - 11, top, territory.z), 10, Color3.fromRGB(190, 170, 140), folder)
end

-- ---------- Outer ring: NPC Village, blocky cube houses and grey blocky villagers ----------
local function npcVillage(folder: Folder, territory: Territories.Territory)
	local cx, cz = territory.x, territory.z
	local houses = { { -22, -19 }, { 22, -19 }, { -30, 9 }, { 30, 9 }, { -22, 19 }, { 22, 19 } }
	for index, offset in houses do
		local x, z = cx + offset[1], cz + offset[2]
		local wallColor = if index % 2 == 0 then Color3.fromRGB(195, 160, 120) else Color3.fromRGB(170, 175, 190)
		solid(Builder.part("House" .. index, Vector3.new(8, 8, 8), Vector3.new(x, 4, z), wallColor, folder))
		solid(Builder.part("Roof" .. index, Vector3.new(10, 2, 10), Vector3.new(x, 9, z), Color3.fromRGB(125, 75, 65), folder))
	end
	-- plain grey blocky villagers (no faces, original look)
	local villagers = { { -8, 12 }, { 10, -20 }, { -12, -5 }, { 14, 5 }, { 0, 16 } }
	for index, offset in villagers do
		local x, z = cx + offset[1], cz + offset[2]
		decor(Builder.part("VillagerLegs" .. index, Vector3.new(2, 3, 1), Vector3.new(x, 1.5, z), Color3.fromRGB(110, 110, 118), folder))
		decor(Builder.part("VillagerBody" .. index, Vector3.new(2, 3, 1), Vector3.new(x, 4.5, z), Color3.fromRGB(150, 150, 158), folder))
		decor(Builder.part("VillagerHead" .. index, Vector3.new(2, 2, 2), Vector3.new(x, 7, z), Color3.fromRGB(185, 185, 192), folder))
	end
end

-- ---------- Outer ring: Brainrot Bog, a bubbling green swamp with a dead tree ----------
local function brainrotBog(folder: Folder, territory: Territories.Territory)
	local cx, cz = territory.x, territory.z
	local pool = Builder.cylinder("SwampPool", 56, 0.4, Vector3.new(cx, 0.2, cz), Color3.fromRGB(70, 190, 60), folder)
	pool.Material = Enum.Material.Neon
	pool.Transparency = 0.25
	pool.CanCollide = false
	local spots = { { 0, 0 }, { -16, 8 }, { 14, -10 }, { 8, 16 }, { -10, -16 }, { 20, 6 } }
	for index, offset in spots do
		local emitter = Builder.emitter("Bubbles" .. index, Vector3.new(cx + offset[1], 0.6, cz + offset[2]), SPARKLES, Color3.fromRGB(120, 255, 90), folder)
		emitter.Rate = 6
		emitter.Lifetime = NumberRange.new(1, 2)
		emitter.Speed = NumberRange.new(2, 4)
		emitter.SpreadAngle = Vector2.new(15, 15)
		emitter.EmissionDirection = Enum.NormalId.Top
		emitter.Size = NumberSequence.new(1.6, 0)
		emitter.Transparency = NumberSequence.new(0.2, 1)
		emitter.LightEmission = 0.6
	end
	-- a dead tree on the edge of the swamp
	local tx, tz = cx + 20, cz - 16
	decor(Builder.part("DeadTreeTrunk", Vector3.new(2.5, 16, 2.5), Vector3.new(tx, 8, tz), Color3.fromRGB(80, 55, 35), folder))
	for index, tilt in { 35, -40, 20 } do
		local branch = Builder.part("DeadTreeBranch" .. index, Vector3.new(1, 8, 1), Vector3.new(tx, 12 + index * 1.5, tz), Color3.fromRGB(70, 48, 30), folder)
		branch.CFrame = CFrame.new(tx, 12 + index * 1.5, tz) * CFrame.Angles(math.rad(tilt), math.rad(index * 90), math.rad(tilt))
		branch.CanCollide = false
	end
end

-- ---------- Outer ring: Cooked Canyon, a lava river, smoke and red rock walls ----------
local function cookedCanyon(folder: Folder, territory: Territories.Territory)
	local cx, cz = territory.x, territory.z
	local red = Color3.fromRGB(175, 65, 40)
	solid(Builder.part("RockWallWest", Vector3.new(6, 16, 60), Vector3.new(cx - 20, 8, cz), red, folder))
	solid(Builder.part("RockWallEast", Vector3.new(6, 16, 60), Vector3.new(cx + 37, 8, cz), red, folder))
	for index, offset in { { -14, -34 }, { 10, 36 }, { 30, -30 } } do
		solid(Builder.part("Boulder" .. index, Vector3.new(9, 7, 9), Vector3.new(cx + offset[1], 3.5, cz + offset[2]), Color3.fromRGB(150, 55, 35), folder))
	end
	-- the lava river runs along the east side, away from the flag
	local lava = Builder.part("LavaRiver", Vector3.new(8, 0.4, 60), Vector3.new(cx + 25, 0.2, cz), Color3.fromRGB(255, 110, 20), folder)
	lava.Material = Enum.Material.Neon
	lava.CanCollide = false
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 120, 30)
	glow.Range = 30
	glow.Brightness = 2
	glow.Parent = lava
	for index, offset in { -20, 0, 20 } do
		local emitter = Builder.emitter("Smoke" .. index, Vector3.new(cx + 25, 2, cz + offset), SMOKE, Color3.fromRGB(70, 65, 65), folder)
		emitter.Rate = 5
		emitter.Lifetime = NumberRange.new(3, 5)
		emitter.Speed = NumberRange.new(4, 6)
		emitter.EmissionDirection = Enum.NormalId.Top
		emitter.Size = NumberSequence.new(5, 12)
		emitter.Transparency = NumberSequence.new(0.4, 1)
	end
end

local builders: { [string]: (Folder, Territories.Territory) -> () } = {
	gigachad_gate = function(folder)
		gigachadGate(folder)
	end,
	rizz_ravine = function(folder)
		rizzRavine(folder)
	end,
	locked_in_lighthouse = lighthouse,
	npc_village = npcVillage,
	brainrot_bog = brainrotBog,
	cooked_canyon = cookedCanyon,
}

-- Build the scenery and one name sign for every territory.
function TerritoryScenery.build()
	local root = Instance.new("Folder")
	root.Name = "TerritoryScenery"
	root.Parent = Workspace
	for _, territory in Territories.list do
		local folder = Instance.new("Folder")
		folder.Name = territory.id
		folder.Parent = root
		local build = builders[territory.id]
		if build then
			build(folder, territory)
		end
		-- one sign per territory: facing outward near the middle of the map, otherwise toward the middle
		local sx, sz = territory.sign.x, territory.sign.z
		local fromMiddle = math.sqrt(sx * sx + sz * sz)
		local facing = if fromMiddle < 70 then Vector3.new(sx * 3, 0, sz * 3) else Vector3.new(0, 0, 0)
		Builder.sign("Sign_" .. territory.id, territory.name, Vector3.new(sx, 0, sz), facing, 28, 6, Color3.fromRGB(110, 70, 190), folder)
	end
end

return TerritoryScenery
