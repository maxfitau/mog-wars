--!strict
-- War Island as real Terrain: a sand beach ring, grass on top, a few hills, dirt paths from each base toward the
-- middle, and water all around. Also sets the bright daytime lighting. Static terrain costs almost nothing on phones.
-- The ground surface is at y = 0, so every flag, ramp and landmark height in Territories.luau stays valid.
-- NOTE: Lighting.Technology cannot be set from a script. Set it to "Future" once in Studio (Lighting > Technology).

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")


local IslandTerrain = {}

local TerrainKit = require(script.Parent:WaitForChild("TerrainKit"))

local SAND_RADIUS = 355
local GRASS_RADIUS = 340
local DEPTH = 24
local WATER_HALF = 560 -- stays clear of Training Island, which starts at x = 670

-- Dirt paths: from each base to its nearest territory, and on to the Gate in the middle. Laid flat on the ground.
IslandTerrain.paths = {
	{ { -225, -225 }, { -100, -170 } }, -- base 1 to NPC Village
	{ { 225, -225 }, { 215, -70 } }, -- base 2 to Rizz Ravine
	{ { 225, 225 }, { 120, 190 } }, -- base 3 to Cooked Canyon
	{ { -225, 225 }, { -110, 190 } }, -- base 4 to Brainrot Bog
	{ { -100, -170 }, { 0, 0 } },
	{ { 215, -70 }, { 0, 0 } },
	{ { 120, 190 }, { 0, 0 } },
	{ { -185, 45 }, { 0, 0 } },
	{ { -110, 190 }, { -185, 45 } },
	{ { -225, -225 }, { 0, -312 } },
	{ { 225, -225 }, { 0, -312 } },
}

-- Hills near the rim, clear of every landmark and base (wide and low, so they are easy to walk up).
local HILLS = {
	{ x = -300, z = 0, base = 55, height = 22 },
	{ x = 300, z = 40, base = 55, height = 22 },
	{ x = 60, z = 300, base = 50, height = 18 },
	{ x = -60, z = -300, base = 50, height = 18 },
	{ x = 310, z = -120, base = 40, height = 14 },
	{ x = -310, z = 120, base = 40, height = 14 },
}

function IslandTerrain.build()
	local terrain = Workspace.Terrain
	terrain:Clear()
	TerrainKit.colors()
	-- water first, then the island on top of it
	terrain:FillBlock(CFrame.new(0, -DEPTH / 2 - 0.75, 0), Vector3.new(WATER_HALF * 2, DEPTH - 1.5, WATER_HALF * 2), Enum.Material.Water) -- surface at y = -1.5
	TerrainKit.cylinder(0, -DEPTH, 0, SAND_RADIUS, DEPTH, Enum.Material.Sand) -- the beach
	TerrainKit.cylinder(0, -DEPTH + 2, 0, GRASS_RADIUS, DEPTH - 2, Enum.Material.Grass)
	for _, hill in HILLS do
		TerrainKit.dome(hill.x, hill.z, hill.base, hill.height, Enum.Material.Grass)
	end
	for _, path in IslandTerrain.paths do
		local from, to = Vector3.new(path[1][1], -0.75, path[1][2]), Vector3.new(path[2][1], -0.75, path[2][2])
		local middle = (from + to) / 2
		terrain:FillBlock(CFrame.lookAt(middle, to), Vector3.new(10, 1.5, (to - from).Magnitude), Enum.Material.Ground)
	end
end

function IslandTerrain.lighting()
	Lighting.ClockTime = 14
	Lighting.Brightness = 3
	Lighting.Ambient = Color3.fromRGB(120, 130, 150)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 150, 170)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.FogEnd = 100000 -- no grey fog
	Lighting.FogStart = 100000
	for _, child in Lighting:GetChildren() do
		if child:IsA("Atmosphere") or child:IsA("BloomEffect") or child:IsA("ColorCorrectionEffect") or child:IsA("SunRaysEffect") then
			child:Destroy()
		end
	end
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.22 -- soft
	atmosphere.Offset = 0.25
	atmosphere.Color = Color3.fromRGB(190, 215, 245)
	atmosphere.Decay = Color3.fromRGB(255, 235, 200)
	atmosphere.Glare = 0
	atmosphere.Haze = 0
	atmosphere.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.35
	bloom.Size = 24
	bloom.Threshold = 1.8
	bloom.Parent = Lighting
	local color = Instance.new("ColorCorrectionEffect")
	color.Saturation = 0.2 -- bright, cartoon colours
	color.Contrast = 0.05
	color.Parent = Lighting
	local sun = Instance.new("SunRaysEffect")
	sun.Intensity = 0.05
	sun.Spread = 0.6
	sun.Parent = Lighting
	local sky = Lighting:FindFirstChildOfClass("Sky")
	if not sky then
		sky = Instance.new("Sky") -- Roblox's own default sky textures are used when none are set
		sky.Parent = Lighting
	end
	-- water: clear and bright
	local terrain = Workspace.Terrain
	terrain.WaterColor = Color3.fromRGB(70, 185, 235)
	terrain.WaterTransparency = 0.6
	terrain.WaterWaveSize = 0.15
	terrain.WaterWaveSpeed = 8
	terrain.WaterReflectance = 0.2
end

return IslandTerrain
