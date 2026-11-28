--!strict
-- Shared DETAIL helpers (see ART.md): cobble paths, flower beds, bushes, rocks, lantern posts, barrels, crates, fireflies and
-- falling leaves. Everything is anchored, non-colliding where it could snag a player, and the counts are small so a whole
-- island stays light. All positions are world positions; pass a Random for repeatable results.

local Workspace = game:GetService("Workspace")

local Detail = {}

local FLOWERS = {
	Color3.fromRGB(235, 70, 80), Color3.fromRGB(250, 210, 60), Color3.fromRGB(240, 130, 190),
	Color3.fromRGB(170, 120, 240), Color3.fromRGB(250, 250, 245), Color3.fromRGB(255, 150, 60),
}
local GREENS = { Color3.fromRGB(95, 175, 65), Color3.fromRGB(130, 195, 75), Color3.fromRGB(70, 145, 70), Color3.fromRGB(150, 205, 85) }

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?, collide: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = collide == true
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

-- The ground under (x, z) if it is real terrain facing up (so nothing is placed on roofs or walls).
function Detail.ground(x: number, z: number, fromY: number): Vector3?
	local result = Workspace:Raycast(Vector3.new(x, fromY + 40, z), Vector3.new(0, -120, 0))
	if result and result.Instance == Workspace.Terrain and result.Normal.Y > 0.85 then
		return result.Position
	end
	return nil
end

-- A path of uneven cobblestones from `from` to `to` (flat, at their height), `width` wide.
function Detail.cobblePath(parent: Instance, from: Vector3, to: Vector3, width: number, rng: Random)
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local length = flat.Magnitude
	if length < 1 then
		return
	end
	local direction = flat.Unit
	local side = direction:Cross(Vector3.yAxis)
	local tone = { Color3.fromRGB(150, 142, 134), Color3.fromRGB(165, 150, 135), Color3.fromRGB(130, 124, 120), Color3.fromRGB(176, 160, 138) }
	local rows = math.ceil(length / 3.2)
	local columns = math.ceil(width / 3.2)
	for row = 0, rows - 1 do
		for column = 0, columns - 1 do
			local along = (row + 0.5) * 3.2 + (rng:NextNumber() - 0.5) * 0.6 + (column % 2) * 1.2
			local across = (column + 0.5 - columns / 2) * 3.2 + (rng:NextNumber() - 0.5) * 0.5
			if along < length then
				local centre = from + direction * along + side * across + Vector3.new(0, 0.12, 0)
				local size = Vector3.new(2.7 + rng:NextNumber() * 0.5, 0.45, 2.7 + rng:NextNumber() * 0.5)
				part(parent, "Cobble", size, CFrame.new(centre) * CFrame.Angles(0, rng:NextNumber() * math.pi, 0), tone[rng:NextInteger(1, #tone)], Enum.Material.Cobblestone)
			end
		end
	end
end

function Detail.bush(parent: Instance, position: Vector3, scale: number, rng: Random)
	local base = GREENS[rng:NextInteger(1, #GREENS)]
	for index = 1, 3 do
		local offset = Vector3.new((rng:NextNumber() - 0.5) * 2 * scale, 0, (rng:NextNumber() - 0.5) * 2 * scale)
		local size = (2.4 + rng:NextNumber() * 1.2) * scale
		part(parent, "Bush", Vector3.new(size, size * 0.85, size), CFrame.new(position + offset + Vector3.new(0, size * 0.35, 0)), base:Lerp(Color3.new(0, 0.3, 0), index * 0.06), Enum.Material.Grass, Enum.PartType.Ball)
	end
	if rng:NextNumber() < 0.5 then -- a few berries or blossoms
		for _ = 1, 3 do
			part(parent, "Blossom", Vector3.new(0.6, 0.6, 0.6), CFrame.new(position + Vector3.new((rng:NextNumber() - 0.5) * 3 * scale, 1.6 * scale + rng:NextNumber(), (rng:NextNumber() - 0.5) * 3 * scale)), FLOWERS[rng:NextInteger(1, #FLOWERS)], Enum.Material.Marble, Enum.PartType.Ball)
		end
	end
end

-- A raised stone-edged flower bed, `length` along `along`, `depth` across, full of flowers of several colours.
function Detail.flowerBed(parent: Instance, centre: Vector3, along: Vector3, length: number, depth: number, rng: Random)
	local frame = CFrame.lookAt(centre, centre + along)
	part(parent, "BedSoil", Vector3.new(depth, 0.9, length), frame * CFrame.new(0, 0.45, 0), Color3.fromRGB(96, 66, 44), Enum.Material.Mud, nil, true)
	for _, sign in { -1, 1 } do
		part(parent, "BedEdge", Vector3.new(0.9, 1.4, length + 1.8), frame * CFrame.new(sign * (depth / 2 + 0.2), 0.7, 0), Color3.fromRGB(150, 142, 134), Enum.Material.Cobblestone, nil, true)
	end
	for _, sign in { -1, 1 } do
		part(parent, "BedEnd", Vector3.new(depth + 1.8, 1.4, 0.9), frame * CFrame.new(0, 0.7, sign * (length / 2 + 0.2)), Color3.fromRGB(150, 142, 134), Enum.Material.Cobblestone, nil, true)
	end
	local count = math.clamp(math.floor(length * depth / 3.5), 4, 16)
	for _ = 1, count do
		local at = frame * CFrame.new((rng:NextNumber() - 0.5) * (depth - 1), 0.9, (rng:NextNumber() - 0.5) * (length - 1))
		local height = 1.2 + rng:NextNumber() * 1.1
		part(parent, "Stem", Vector3.new(0.18, height, 0.18), at * CFrame.new(0, height / 2, 0), Color3.fromRGB(70, 140, 60), Enum.Material.Grass)
		local colour = FLOWERS[rng:NextInteger(1, #FLOWERS)]
		part(parent, "Flower", Vector3.new(0.95, 0.5, 0.95), at * CFrame.new(0, height, 0), colour, Enum.Material.Marble, Enum.PartType.Ball)
	end
end

function Detail.rocks(parent: Instance, position: Vector3, rng: Random, count: number)
	for _ = 1, count do
		local size = 0.8 + rng:NextNumber() * 2
		part(parent, "Pebble", Vector3.new(size * 1.3, size, size), CFrame.new(position + Vector3.new((rng:NextNumber() - 0.5) * 5, size * 0.3, (rng:NextNumber() - 0.5) * 5)) * CFrame.Angles(rng:NextNumber(), rng:NextNumber() * 3, rng:NextNumber()), Color3.fromRGB(125 + rng:NextInteger(0, 30), 118 + rng:NextInteger(0, 25), 110 + rng:NextInteger(0, 20)), Enum.Material.Rock, Enum.PartType.Ball)
	end
end

-- A lantern post: a dark wood pole, an iron bracket and a glowing amber lantern with a warm light.
function Detail.lanternPost(parent: Instance, position: Vector3, withLight: boolean?)
	part(parent, "LanternPole", Vector3.new(0.7, 7, 0.7), CFrame.new(position + Vector3.new(0, 3.5, 0)), Color3.fromRGB(70, 50, 36), Enum.Material.Wood, nil, true)
	part(parent, "LanternArm", Vector3.new(2.2, 0.35, 0.35), CFrame.new(position + Vector3.new(1, 6.7, 0)), Color3.fromRGB(50, 46, 50), Enum.Material.Metal)
	local lamp = part(parent, "Lantern", Vector3.new(1.4, 1.9, 1.4), CFrame.new(position + Vector3.new(2, 6, 0)), Color3.fromRGB(255, 190, 90), Enum.Material.Neon, Enum.PartType.Ball)
	if withLight ~= false then
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 190, 90)
		light.Range = 20
		light.Brightness = 1.2
		light.Parent = lamp
	end
end

function Detail.barrel(parent: Instance, position: Vector3, rng: Random)
	local frame = CFrame.new(position + Vector3.new(0, 1.5, 0))
	local barrel = part(parent, "Barrel", Vector3.new(3, 3.4, 3), frame * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(150 + rng:NextInteger(0, 20), 100, 58), Enum.Material.Wood, Enum.PartType.Cylinder, true)
	barrel.Size = Vector3.new(3.2, 3, 3)
	for _, offset in { -0.9, 0.9 } do
		part(parent, "BarrelBand", Vector3.new(0.3, 3.15, 3.15), frame * CFrame.new(0, offset, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(60, 56, 60), Enum.Material.Metal, Enum.PartType.Cylinder)
	end
end

function Detail.crateStack(parent: Instance, position: Vector3, rng: Random)
	local count = rng:NextInteger(1, 3)
	for index = 1, count do
		local size = 3 + rng:NextNumber() * 0.6
		local frame = CFrame.new(position + Vector3.new((index - 1) * 0.4, (index - 0.5) * 3.2, 0)) * CFrame.Angles(0, rng:NextNumber() * 0.6, 0)
		part(parent, "Crate", Vector3.new(size, 3.1, size), frame, Color3.fromRGB(176, 128, 74), Enum.Material.WoodPlanks, nil, true)
		part(parent, "CrateStrap", Vector3.new(size + 0.15, 0.4, size + 0.15), frame * CFrame.new(0, 0.9, 0), Color3.fromRGB(110, 76, 46), Enum.Material.Wood)
	end
end

-- A few slow glowing fireflies drifting around a point.
function Detail.fireflies(parent: Instance, position: Vector3, size: Vector3)
	local anchor = part(parent, "FireflyEmitter", size, CFrame.new(position), Color3.new(1, 1, 1), Enum.Material.Neon)
	anchor.Transparency = 1
	local emitter = Instance.new("ParticleEmitter")
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 240, 130))
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new(0.35)
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.1), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(4, 7)
	emitter.Speed = NumberRange.new(0.5, 1.5)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 5
	emitter.Parent = anchor
end

-- Soft leaves drifting down from above a point (tree or bush season).
function Detail.leaves(parent: Instance, position: Vector3, colour: Color3)
	local anchor = part(parent, "LeafEmitter", Vector3.new(14, 1, 14), CFrame.new(position), colour, Enum.Material.Neon)
	anchor.Transparency = 1
	local emitter = Instance.new("ParticleEmitter")
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.Color = ColorSequence.new(colour)
	emitter.Size = NumberSequence.new(0.5)
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(5, 8)
	emitter.Speed = NumberRange.new(1, 2)
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.Acceleration = Vector3.new(1.5, -1, 0.5)
	emitter.RotSpeed = NumberRange.new(-80, 80)
	emitter.Rate = 3
	emitter.Parent = anchor
end

-- Flowers and grass tufts scattered on real ground in a ring (islands' rims), capped at `count`.
function Detail.tuftRing(parent: Instance, centre: Vector3, innerRadius: number, outerRadius: number, count: number, rng: Random)
	for _ = 1, count do
		local angle = rng:NextNumber() * math.pi * 2
		local radius = innerRadius + rng:NextNumber() * (outerRadius - innerRadius)
		local spot = Detail.ground(centre.X + math.cos(angle) * radius, centre.Z + math.sin(angle) * radius, centre.Y)
		if spot then
			if rng:NextNumber() < 0.55 then
				local colour = FLOWERS[rng:NextInteger(1, #FLOWERS)]
				part(parent, "Stem", Vector3.new(0.2, 1.1, 0.2), CFrame.new(spot + Vector3.new(0, 0.5, 0)), Color3.fromRGB(70, 140, 60), Enum.Material.Grass)
				part(parent, "Flower", Vector3.new(0.9, 0.5, 0.9), CFrame.new(spot + Vector3.new(0, 1.1, 0)), colour, Enum.Material.Marble, Enum.PartType.Ball)
			else
				part(parent, "Tuft", Vector3.new(1.2, 1.3, 1.2), CFrame.new(spot + Vector3.new(0, 0.5, 0)), GREENS[rng:NextInteger(1, #GREENS)], Enum.Material.Grass, Enum.PartType.Ball)
			end
		end
	end
end

return Detail
