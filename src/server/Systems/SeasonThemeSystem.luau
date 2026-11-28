--!strict
-- THE SEASON THEME: sets Workspace attributes SeasonId and SeasonName (from src/shared/SeasonConfig.luau, one line to change) and
-- dresses ONE island, the NPC Village, in a Folder "SeasonDecor" in Workspace. Winter: snow patches, snowmen, snow on the roofs and
-- chimneys, frosted trees, falling snow and a few string lights. Spring: blossoms, flower beds, drifting petals. Summer:
-- sunflowers, flower beds, beach umbrellas, fireflies. Autumn: pumpkins, leaf piles, hay bales, orange trees, falling leaves.
-- It is all cosmetic, small (BUDGET parts and a few emitters) and never blocks anything: every piece is placed only where the spot
-- is clear of the house doors, the lifts, the plaza, the paths, the statue, the well, the stalls, the crates and the villagers,
-- and the decorations that are not tiny flowers do not collide. (The village layout below mirrors src/server/Lib/Places/NpcVillage.luau.)

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SeasonConfig = require(Shared:WaitForChild("SeasonConfig"))
local Territories = require(Shared:WaitForChild("Territories"))
local Lib = script.Parent.Parent:WaitForChild("Lib")
local Detail = require(Lib:WaitForChild("Detail"))
local Lifts = require(Lib:WaitForChild("Lifts"))

local SeasonThemeSystem = {}

local BUDGET = 420 -- the most parts the whole decoration may use
local FOLDER_NAME = "SeasonDecor"

type Ctx = { folder: Folder, cx: number, cz: number, h: number, rng: Random }

-- ===== WHERE THINGS ARE IN THE VILLAGE (relative to its centre) =====
-- houses: x, z, door side, size of the footprint is 20 x 18
local HOUSES = {
	{ x = -60, z = -35, door = "E", tall = false },
	{ x = 60, z = -35, door = "W", tall = false },
	{ x = -60, z = 10, door = "E", tall = true },
	{ x = 60, z = 10, door = "W", tall = true },
	{ x = -60, z = 55, door = "E", tall = false },
	{ x = 60, z = 55, door = "W", tall = false },
	{ x = -22, z = 70, door = "N", tall = true },
	{ x = 22, z = 70, door = "N", tall = false },
}
local DOORS = { { -50, 10 }, { 50, 10 }, { -50, -35 }, { 50, -35 }, { -50, 55 }, { 50, 55 }, { -22, 60 }, { 22, 60 } }
local VILLAGERS = { { -22, 20 }, { 18, 28 }, { -34, 44 }, { 34, 44 }, { 0, 52 }, { 8, 8 } }
local CRATES = { { -30, 28 }, { 28, 18 }, { -12, 40 }, { 14, 46 }, { -44, 18 }, { 44, 36 }, { 0, 24 }, { -40, 62 }, { 40, 68 } }
local STRING_ROWS = { 16, 28, 52 } -- the z of the lantern post pairs the string lights hang between (posts at x = -14 and 14)

local SNOW = Color3.fromRGB(246, 249, 255)

local function segmentDistance(px: number, pz: number, ax: number, az: number, bx: number, bz: number): number
	local dx, dz = bx - ax, bz - az
	local lengthSquared = dx * dx + dz * dz
	local t = if lengthSquared > 0 then math.clamp(((px - ax) * dx + (pz - az) * dz) / lengthSquared, 0, 1) else 0
	local nx, nz = ax + dx * t, az + dz * t
	return math.sqrt((px - nx) ^ 2 + (pz - nz) ^ 2)
end

-- Is the spot (relative to the village centre) clear of everything that must stay open?
local function isFree(ctx: Ctx, rx: number, rz: number): boolean
	if rx * rx + rz * rz > 88 * 88 then
		return false
	end
	if rx > -40 and rx < 40 and rz > -50 and rz < -1 then
		return false -- the statue and its scaffolding
	end
	if math.abs(rx) < 19 and rz > -1 and rz < 33 then
		return false -- the cobble plaza
	end
	if math.sqrt(rx * rx + (rz - 34) ^ 2) < 13 then
		return false -- the well and the way down
	end
	for _, side in { -1, 1 } do
		if math.sqrt((rx - side * 26) ^ 2 + (rz - 30) ^ 2) < 10 then
			return false -- market stalls
		end
		if math.sqrt((rx - side * 38) ^ 2 + (rz - 52) ^ 2) < 9 then
			return false -- carts
		end
		if segmentDistance(rx, rz, side * 44, -20, side * 44, -2) < 4 or segmentDistance(rx, rz, side * 44, 24, side * 44, 42) < 4 then
			return false -- garden fences
		end
		for index = 1, 5 do
			if math.sqrt((rx - side * 14) ^ 2 + (rz - (-8 + index * 12)) ^ 2) < 4 then
				return false -- lantern posts
			end
		end
	end
	for _, spot in VILLAGERS do
		if math.sqrt((rx - spot[1]) ^ 2 + (rz - spot[2]) ^ 2) < 6 then
			return false
		end
	end
	for _, spot in CRATES do
		if math.sqrt((rx - spot[1]) ^ 2 + (rz - spot[2]) ^ 2) < 6 then
			return false -- plaza cover
		end
	end
	for _, house in HOUSES do
		local minX, maxX, minZ, maxZ = house.x - 14, house.x + 14, house.z - 13, house.z + 13
		if house.door == "E" then
			maxX += 12 -- keep the front door clear
		elseif house.door == "W" then
			minX -= 12
		else
			minZ -= 12
		end
		if rx > minX and rx < maxX and rz > minZ and rz < maxZ then
			return false
		end
	end
	for _, door in DOORS do -- the cobble paths from the plaza to every door
		local fromX = if door[1] < 0 then -12 else 12
		if segmentDistance(rx, rz, fromX, 20, door[1], door[2]) < 7 then
			return false
		end
	end
	local wx, wz = ctx.cx + rx, ctx.cz + rz
	for _, lift in Lifts.list do -- every bubble lift: its entrance pad and the way up
		local points = lift.points
		if #points == 1 then
			if math.sqrt((wx - points[1].X) ^ 2 + (wz - points[1].Z) ^ 2) < 10 then
				return false
			end
		end
		for index = 1, #points - 1 do
			if segmentDistance(wx, wz, points[index].X, points[index].Z, points[index + 1].X, points[index + 1].Z) < 10 then
				return false
			end
		end
	end
	return true
end

-- A round patch of ground that is clear all the way round (centre and four edge points).
local function isFreeCircle(ctx: Ctx, rx: number, rz: number, radius: number): boolean
	if not isFree(ctx, rx, rz) then
		return false
	end
	for _, offset in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
		if not isFree(ctx, rx + offset[1] * radius, rz + offset[2] * radius) then
			return false
		end
	end
	return true
end

local function room(ctx: Ctx, parts: number): boolean
	return #ctx.folder:GetChildren() + parts <= BUDGET
end

local function newPart(ctx: Ctx, name: string, size: Vector3, cframe: CFrame, colour: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = colour
	part.Material = material
	part.Anchored = true
	part.CanCollide = false -- decoration never blocks anyone
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		part.Shape = shape
	end
	part.Parent = ctx.folder
	return part
end

-- A random clear spot on real ground: returns the world position, or nil after a few tries.
local function pickSpot(ctx: Ctx, clearRadius: number, minRadius: number?, maxRadius: number?): Vector3?
	local inner, outer = minRadius or 12, maxRadius or 84
	for _ = 1, 30 do
		local angle = ctx.rng:NextNumber() * math.pi * 2
		local distance = inner + ctx.rng:NextNumber() * (outer - inner)
		local rx, rz = math.cos(angle) * distance, math.sin(angle) * distance
		if isFreeCircle(ctx, rx, rz, clearRadius) then
			local ground = Detail.ground(ctx.cx + rx, ctx.cz + rz, ctx.h)
			if ground then
				return ground
			end
		end
	end
	return nil
end

-- An emitter in the sky over the village (one invisible part).
local function skyEmitter(ctx: Ctx, name: string, centre: Vector3, size: Vector3): ParticleEmitter
	local part = newPart(ctx, name, size, CFrame.new(centre), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
	part.Transparency = 1
	local emitter = Instance.new("ParticleEmitter")
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.Parent = part
	return emitter
end

-- All the tree leaf balls on the village island that the Places built (not our own), at most `limit`, spread out.
local function treeLeaves(ctx: Ctx, limit: number): { BasePart }
	local all: { BasePart } = {}
	for _, instance in Workspace:GetDescendants() do
		if instance.Name == "TreeLeaves" and instance:IsA("BasePart") and not instance:IsDescendantOf(ctx.folder) then
			local offset = instance.Position - Vector3.new(ctx.cx, ctx.h, ctx.cz)
			if offset.X * offset.X + offset.Z * offset.Z < 110 * 110 and math.abs(offset.Y) < 40 then
				table.insert(all, instance)
			end
		end
	end
	if #all <= limit then
		return all
	end
	local picked: { BasePart } = {}
	local stride = #all / limit
	for index = 1, limit do
		table.insert(picked, all[math.floor((index - 1) * stride) + 1])
	end
	return picked
end

-- A random direction on the top half of a ball, scaled to sit on its surface.
local function onTop(ctx: Ctx, leaf: BasePart, scale: number): Vector3
	local angle = ctx.rng:NextNumber() * math.pi * 2
	local lift = 0.2 + ctx.rng:NextNumber() * 0.8
	local flat = math.sqrt(1 - lift * lift)
	local direction = Vector3.new(math.cos(angle) * flat, lift, math.sin(angle) * flat)
	return leaf.Position + direction * (leaf.Size.X / 2) * scale
end

-- ===== WINTER =====

local function snowman(ctx: Ctx, base: Vector3)
	local yaw = CFrame.new(base) * CFrame.Angles(0, ctx.rng:NextNumber() * math.pi * 2, 0)
	local function at(x: number, y: number, z: number): CFrame
		return yaw * CFrame.new(x, y, z)
	end
	newPart(ctx, "SnowmanBody", Vector3.new(4.4, 4.0, 4.4), at(0, 1.9, 0), SNOW, Enum.Material.Snow, Enum.PartType.Ball)
	newPart(ctx, "SnowmanChest", Vector3.new(3.2, 3.0, 3.2), at(0, 4.8, 0), SNOW, Enum.Material.Snow, Enum.PartType.Ball)
	newPart(ctx, "SnowmanHead", Vector3.new(2.3, 2.2, 2.3), at(0, 7.0, 0), SNOW, Enum.Material.Snow, Enum.PartType.Ball)
	newPart(ctx, "SnowmanNose", Vector3.new(0.35, 0.35, 1.3), at(0, 7.0, 1.5), Color3.fromRGB(240, 130, 40), Enum.Material.SmoothPlastic)
	for _, side in { -0.5, 0.5 } do
		newPart(ctx, "SnowmanEye", Vector3.new(0.35, 0.35, 0.35), at(side, 7.5, 1.05), Color3.fromRGB(30, 30, 35), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	end
	newPart(ctx, "SnowmanHat", Vector3.new(1.6, 1.6, 1.6), at(0, 8.6, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(190, 50, 60), Enum.Material.Fabric, Enum.PartType.Cylinder)
end

local function snowOnHouses(ctx: Ctx)
	local span, rise = 9.9, 6
	local slope = math.sqrt(span * span + rise * rise)
	local angle = math.atan2(rise, span)
	for _, house in HOUSES do
		if not room(ctx, 6) then
			return
		end
		local x, z = ctx.cx + house.x, ctx.cz + house.z
		if house.tall then
			-- a flat roof deck with parapets: snow along the parapet tops
			for _, side in { -1, 1 } do
				newPart(ctx, "SnowParapet", Vector3.new(20.4, 0.5, 1.4), CFrame.new(x, ctx.h + 15.25, z + side * 8.5), SNOW, Enum.Material.Snow)
			end
			for _, side in { -1, 1 } do
				newPart(ctx, "SnowParapet", Vector3.new(1.4, 0.5, 18.4), CFrame.new(x + side * 9.5, ctx.h + 15.25, z), SNOW, Enum.Material.Snow)
			end
		else
			-- a pitched roof: a white slab lying on each side
			for _, side in { -1, 1 } do
				local roof = CFrame.new(x, ctx.h + 14.55, z + side * span / 2) * CFrame.Angles(side * angle, 0, 0)
				newPart(ctx, "SnowRoof", Vector3.new(22.8, 0.5, slope + 0.4), roof * CFrame.new(0, 0.72, 0), SNOW, Enum.Material.Snow)
			end
		end
		newPart(ctx, "SnowChimney", Vector3.new(3.3, 0.6, 3.3), CFrame.new(x + 6, ctx.h + 19.3, z - 4), SNOW, Enum.Material.Snow)
	end
end

local function stringLights(ctx: Ctx)
	local colours = { Color3.fromRGB(255, 80, 80), Color3.fromRGB(255, 210, 90), Color3.fromRGB(90, 220, 120), Color3.fromRGB(100, 170, 255) }
	for _, row in STRING_ROWS do
		if not room(ctx, 18) then
			return
		end
		local previous: Vector3? = nil
		for index = 0, 8 do
			local t = index / 8
			local sag = 2.2 * (1 - (2 * t - 1) ^ 2)
			local point = Vector3.new(ctx.cx - 14 + 28 * t, ctx.h + 9.5 - sag, ctx.cz + row)
			local bulb = newPart(ctx, "StringBulb", Vector3.new(0.7, 0.7, 0.7), CFrame.new(point), colours[index % #colours + 1], Enum.Material.Neon, Enum.PartType.Ball)
			if index % 4 == 2 then
				local glow = Instance.new("PointLight")
				glow.Range = 9
				glow.Brightness = 0.8
				glow.Color = bulb.Color
				glow.Parent = bulb
			end
			if previous then
				local length = (point - previous).Magnitude
				newPart(ctx, "StringWire", Vector3.new(0.15, 0.15, length), CFrame.lookAt((point + previous) / 2, point), Color3.fromRGB(30, 30, 35), Enum.Material.SmoothPlastic)
			end
			previous = point
		end
	end
end

local function buildWinter(ctx: Ctx)
	-- white ground patches
	local made = 0
	for _ = 1, 70 do
		if made >= 30 or not room(ctx, 8) then
			break
		end
		local diameter = 7 + ctx.rng:NextNumber() * 9
		local spot = pickSpot(ctx, diameter / 2, 8, 86)
		if spot then
			newPart(ctx, "SnowPatch", Vector3.new(0.25, diameter, diameter), CFrame.new(spot + Vector3.new(0, 0.13, 0)) * CFrame.Angles(0, 0, math.pi / 2), SNOW, Enum.Material.Snow, Enum.PartType.Cylinder)
			made += 1
		end
	end
	-- snowmen
	for _ = 1, 6 do
		if not room(ctx, 70) then
			break
		end
		local spot = pickSpot(ctx, 4, 20, 84)
		if spot then
			snowman(ctx, spot)
		end
	end
	snowOnHouses(ctx)
	-- frosted trees: a snow cap on top of each leaf ball
	for _, leaf in treeLeaves(ctx, 40) do
		if not room(ctx, 30) then
			break
		end
		local size = leaf.Size
		newPart(ctx, "SnowCap", Vector3.new(size.X * 0.85, size.Y * 0.5, size.Z * 0.85), CFrame.new(leaf.Position + Vector3.new(0, size.Y * 0.33, 0)), SNOW, Enum.Material.Snow, Enum.PartType.Ball)
	end
	stringLights(ctx)
	-- falling snow over the whole village: ONE emitter
	local fall = skyEmitter(ctx, "SnowFall", Vector3.new(ctx.cx, ctx.h + 55, ctx.cz), Vector3.new(190, 1, 190))
	fall.Color = ColorSequence.new(Color3.new(1, 1, 1))
	fall.Size = NumberSequence.new(0.5)
	fall.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.85, 0.2), NumberSequenceKeypoint.new(1, 1) })
	fall.LightEmission = 0.3
	fall.Lifetime = NumberRange.new(9, 11)
	fall.Speed = NumberRange.new(5, 7)
	fall.Acceleration = Vector3.new(0.6, 0, 0.3)
	fall.RotSpeed = NumberRange.new(-60, 60)
	fall.Rate = 90
end

-- ===== SPRING =====

local function buildSpring(ctx: Ctx)
	local blossoms = { Color3.fromRGB(255, 170, 205), Color3.fromRGB(255, 205, 225), Color3.fromRGB(255, 245, 250), Color3.fromRGB(240, 140, 190) }
	for _, leaf in treeLeaves(ctx, 24) do
		if not room(ctx, 30) then
			break
		end
		for _ = 1, 3 do
			local size = 1.1 + ctx.rng:NextNumber() * 0.9
			newPart(ctx, "Blossom", Vector3.new(size, size, size), CFrame.new(onTop(ctx, leaf, 0.95)), blossoms[ctx.rng:NextInteger(1, #blossoms)], Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		end
	end
	for _ = 1, 3 do -- flower beds (these are solid, so only on clear ground)
		if not room(ctx, 40) then
			break
		end
		local spot = pickSpot(ctx, 7, 20, 84)
		if spot then
			Detail.flowerBed(ctx.folder, spot, Vector3.xAxis, 8, 3, ctx.rng)
		end
	end
	for _ = 1, 22 do -- loose flowers
		if not room(ctx, 4) then
			break
		end
		local spot = pickSpot(ctx, 1.5, 14, 86)
		if spot then
			newPart(ctx, "SpringStem", Vector3.new(0.2, 1.2, 0.2), CFrame.new(spot + Vector3.new(0, 0.6, 0)), Color3.fromRGB(70, 150, 70), Enum.Material.Grass)
			newPart(ctx, "SpringFlower", Vector3.new(1, 0.6, 1), CFrame.new(spot + Vector3.new(0, 1.3, 0)), blossoms[ctx.rng:NextInteger(1, #blossoms)], Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		end
	end
	local petals = skyEmitter(ctx, "PetalFall", Vector3.new(ctx.cx, ctx.h + 40, ctx.cz), Vector3.new(170, 1, 170))
	petals.Color = ColorSequence.new(Color3.fromRGB(255, 180, 210))
	petals.Size = NumberSequence.new(0.45)
	petals.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	petals.Lifetime = NumberRange.new(8, 11)
	petals.Speed = NumberRange.new(2, 4)
	petals.Acceleration = Vector3.new(1.5, 0, 0.8)
	petals.RotSpeed = NumberRange.new(-90, 90)
	petals.Rate = 30
end

-- ===== SUMMER =====

local function sunflower(ctx: Ctx, base: Vector3)
	local height = 3.4 + ctx.rng:NextNumber() * 1.6
	local yaw = CFrame.new(base + Vector3.new(0, height, 0)) * CFrame.Angles(0, ctx.rng:NextNumber() * math.pi * 2, 0)
	newPart(ctx, "SunflowerStem", Vector3.new(0.3, height, 0.3), CFrame.new(base + Vector3.new(0, height / 2, 0)), Color3.fromRGB(70, 140, 55), Enum.Material.Grass)
	newPart(ctx, "SunflowerPetals", Vector3.new(2.4, 2.4, 0.4), yaw * CFrame.new(0, 0, 0.2), Color3.fromRGB(255, 205, 40), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	newPart(ctx, "SunflowerHeart", Vector3.new(1.1, 1.1, 0.5), yaw * CFrame.new(0, 0, 0.45), Color3.fromRGB(100, 60, 30), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
end

local function umbrella(ctx: Ctx, base: Vector3)
	newPart(ctx, "UmbrellaPole", Vector3.new(0.3, 7, 0.3), CFrame.new(base + Vector3.new(0, 3.5, 0)), Color3.fromRGB(230, 230, 235), Enum.Material.SmoothPlastic)
	newPart(ctx, "UmbrellaTop", Vector3.new(0.5, 8, 8), CFrame.new(base + Vector3.new(0, 7, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(235, 70, 70), Enum.Material.Fabric, Enum.PartType.Cylinder)
	newPart(ctx, "UmbrellaStripe", Vector3.new(0.55, 4.5, 4.5), CFrame.new(base + Vector3.new(0, 7, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(250, 250, 245), Enum.Material.Fabric, Enum.PartType.Cylinder)
end

local function buildSummer(ctx: Ctx)
	for _ = 1, 14 do
		if not room(ctx, 3) then
			break
		end
		local spot = pickSpot(ctx, 2, 14, 86)
		if spot then
			sunflower(ctx, spot)
		end
	end
	for _ = 1, 3 do
		if not room(ctx, 40) then
			break
		end
		local spot = pickSpot(ctx, 7, 20, 84)
		if spot then
			Detail.flowerBed(ctx.folder, spot, Vector3.zAxis, 8, 3, ctx.rng)
		end
	end
	for _ = 1, 3 do
		if not room(ctx, 3) then
			break
		end
		local spot = pickSpot(ctx, 5, 24, 82)
		if spot then
			umbrella(ctx, spot)
		end
	end
	Detail.fireflies(ctx.folder, Vector3.new(ctx.cx, ctx.h + 5, ctx.cz - 62), Vector3.new(80, 8, 24))
	Detail.fireflies(ctx.folder, Vector3.new(ctx.cx, ctx.h + 5, ctx.cz + 76), Vector3.new(80, 8, 14))
end

-- ===== AUTUMN =====

local function buildAutumn(ctx: Ctx)
	local leaves = { Color3.fromRGB(235, 130, 40), Color3.fromRGB(205, 70, 40), Color3.fromRGB(240, 185, 60), Color3.fromRGB(170, 90, 40) }
	for _, leaf in treeLeaves(ctx, 24) do
		if not room(ctx, 30) then
			break
		end
		for _ = 1, 3 do
			local size = leaf.Size.X * (0.4 + ctx.rng:NextNumber() * 0.2)
			newPart(ctx, "AutumnLeaves", Vector3.new(size, size * 0.8, size), CFrame.new(onTop(ctx, leaf, 0.7)), leaves[ctx.rng:NextInteger(1, #leaves)], Enum.Material.Grass, Enum.PartType.Ball)
		end
	end
	for _ = 1, 10 do -- pumpkins
		if not room(ctx, 3) then
			break
		end
		local spot = pickSpot(ctx, 2, 16, 86)
		if spot then
			local size = 1.8 + ctx.rng:NextNumber() * 1.2
			newPart(ctx, "Pumpkin", Vector3.new(size * 1.2, size, size * 1.2), CFrame.new(spot + Vector3.new(0, size / 2, 0)), Color3.fromRGB(240, 120, 30), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
			newPart(ctx, "PumpkinStem", Vector3.new(0.35, 0.7, 0.35), CFrame.new(spot + Vector3.new(0, size + 0.2, 0)), Color3.fromRGB(80, 120, 50), Enum.Material.Wood)
		end
	end
	for _ = 1, 14 do -- piles of leaves
		if not room(ctx, 3) then
			break
		end
		local spot = pickSpot(ctx, 3, 14, 86)
		if spot then
			local colour = leaves[ctx.rng:NextInteger(1, #leaves)]
			newPart(ctx, "LeafPile", Vector3.new(5, 1.2, 5), CFrame.new(spot + Vector3.new(0, 0.3, 0)), colour, Enum.Material.Grass, Enum.PartType.Ball)
			newPart(ctx, "LeafPile", Vector3.new(3, 1, 3), CFrame.new(spot + Vector3.new(1.2, 0.6, 0.8)), colour:Lerp(Color3.new(1, 1, 1), 0.15), Enum.Material.Grass, Enum.PartType.Ball)
		end
	end
	for _ = 1, 4 do -- hay bales
		if not room(ctx, 2) then
			break
		end
		local spot = pickSpot(ctx, 3, 20, 84)
		if spot then
			newPart(ctx, "HayBale", Vector3.new(3.4, 3.4, 3.4), CFrame.new(spot + Vector3.new(0, 1.7, 0)) * CFrame.Angles(0, ctx.rng:NextNumber() * math.pi, 0), Color3.fromRGB(225, 190, 90), Enum.Material.Grass, Enum.PartType.Cylinder)
		end
	end
	Detail.leaves(ctx.folder, Vector3.new(ctx.cx - 70, ctx.h + 22, ctx.cz), Color3.fromRGB(235, 130, 40))
	Detail.leaves(ctx.folder, Vector3.new(ctx.cx + 70, ctx.h + 22, ctx.cz + 10), Color3.fromRGB(205, 70, 40))
	Detail.leaves(ctx.folder, Vector3.new(ctx.cx, ctx.h + 24, ctx.cz + 60), Color3.fromRGB(240, 185, 60))
end

local builders: { [string]: (Ctx) -> () } = {
	winter = buildWinter,
	spring = buildSpring,
	summer = buildSummer,
	autumn = buildAutumn,
}

-- Dress the village for a season (removes the old decoration first). Also used by the Studio debug command to try the others.
function SeasonThemeSystem.apply(id: string): boolean
	local season = SeasonConfig.byId(id)
	local build = builders[id]
	local territory = Territories.byId.npc_village
	if not season or not build or not territory then
		return false
	end
	Workspace:SetAttribute("SeasonId", season.id)
	Workspace:SetAttribute("SeasonName", season.name)
	local old = Workspace:FindFirstChild(FOLDER_NAME)
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = Workspace
	local ctx: Ctx = { folder = folder, cx = territory.x, cz = territory.z, h = territory.height, rng = Random.new(4410) }
	local ok, err = pcall(build, ctx)
	if not ok then
		warn("[mog-wars] season decoration failed: " .. tostring(err))
	end
	return ok
end

function SeasonThemeSystem.init()
	local season = SeasonConfig.currentSeason()
	Workspace:SetAttribute("SeasonId", season.id)
	Workspace:SetAttribute("SeasonName", season.name)
end

function SeasonThemeSystem.start()
	task.spawn(function()
		-- the map is built by PlaceholderMap.start; wait until its zones exist, then a moment for the terrain to settle
		local waited = 0
		while #CollectionService:GetTagged("Zone") == 0 and waited < 30 do
			task.wait(0.5)
			waited += 0.5
		end
		task.wait(1)
		SeasonThemeSystem.apply(SeasonConfig.currentSeason().id)
	end)
end

return SeasonThemeSystem
