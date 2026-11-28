--!strict
-- Small helpers for shaping Terrain (hills, cliffs, ponds, caves). Terrain works in 4-stud voxels, so keep sizes
-- and positions in multiples of 4 for clean edges (especially for carved rooms). y values are heights above the
-- ground (y = 0 is the island surface; the island is 24 studs deep so rooms can be carved underground).

local Workspace = game:GetService("Workspace")

local TerrainKit = {}

-- Everything below is placed relative to a BASE HEIGHT, so a territory module can build on its own floating island:
-- call TerrainKit.setBase(islandTopHeight) first and then use y = 0 for "the island surface".
TerrainKit.base = 0

function TerrainKit.setBase(y: number)
	TerrainKit.base = y
end

local WATER_SURFACE = -1.5

local function terrain(): Terrain
	return Workspace.Terrain
end

-- A box of terrain whose BOTTOM is at y0.
function TerrainKit.block(x: number, y0: number, z: number, sx: number, sy: number, sz: number, material: Enum.Material)
	terrain():FillBlock(CFrame.new(x, TerrainKit.base + y0 + sy / 2, z), Vector3.new(sx, sy, sz), material)
end

-- A flat-topped round column of terrain whose BOTTOM is at y0.
function TerrainKit.cylinder(x: number, y0: number, z: number, radius: number, height: number, material: Enum.Material)
	terrain():FillCylinder(CFrame.new(x, TerrainKit.base + y0 + height / 2, z), height, radius, material)
end

-- A smooth dome: `height` tall, `baseRadius` wide at the ground. Wide domes make gentle, walkable hills.
function TerrainKit.dome(x: number, z: number, baseRadius: number, height: number, material: Enum.Material)
	local radius = (baseRadius * baseRadius + height * height) / (2 * height)
	terrain():FillBall(Vector3.new(x, TerrainKit.base + height - radius, z), radius, material)
end

-- Dig out a box (air). Used for caves, secret rooms and trenches.
function TerrainKit.carve(x: number, y0: number, z: number, sx: number, sy: number, sz: number)
	terrain():FillBlock(CFrame.new(x, TerrainKit.base + y0 + sy / 2, z), Vector3.new(sx, sy, sz), Enum.Material.Air)
end

-- A round pond: dug `depth` deep and filled with water up to just below the ground.
function TerrainKit.pond(x: number, z: number, radius: number, depth: number)
	terrain():FillCylinder(CFrame.new(x, TerrainKit.base - depth / 2, z), depth, radius, Enum.Material.Air)
	local waterHeight = depth + WATER_SURFACE
	terrain():FillCylinder(CFrame.new(x, TerrainKit.base - depth + waterHeight / 2, z), waterHeight, radius, Enum.Material.Water)
end

-- Bright, cartoon terrain colours (each material has one colour for the whole map).
function TerrainKit.colors()
	local colors: { [Enum.Material]: Color3 } = {
		[Enum.Material.Grass] = Color3.fromRGB(112, 178, 86), -- a natural, softer green
		[Enum.Material.LeafyGrass] = Color3.fromRGB(88, 150, 70),
		[Enum.Material.Salt] = Color3.fromRGB(255, 176, 208), -- Rizz Ravine's pink grass
		[Enum.Material.Sand] = Color3.fromRGB(245, 220, 150),
		[Enum.Material.Ground] = Color3.fromRGB(160, 112, 72),
		[Enum.Material.Rock] = Color3.fromRGB(125, 120, 140),
		[Enum.Material.Limestone] = Color3.fromRGB(248, 150, 195),
		[Enum.Material.Sandstone] = Color3.fromRGB(200, 90, 58),
		[Enum.Material.Mud] = Color3.fromRGB(95, 160, 60),
		[Enum.Material.CrackedLava] = Color3.fromRGB(255, 125, 30),
		[Enum.Material.Cobblestone] = Color3.fromRGB(150, 150, 168),
		[Enum.Material.Basalt] = Color3.fromRGB(80, 68, 92),
		[Enum.Material.Slate] = Color3.fromRGB(112, 112, 128),
	}
	for material, color in colors do
		pcall(function()
			terrain():SetMaterialColor(material, color)
		end)
	end
end

return TerrainKit
