--!strict
-- War Island as real Terrain: a sand beach ring, grass on top, a few hills, dirt paths from each base toward the
-- middle, and water all around. Also sets the bright daytime lighting. Static terrain costs almost nothing on phones.
-- The ground surface is at y = 0, so every flag, ramp and landmark height in Territories.luau stays valid.
-- NOTE: Lighting.Technology cannot be set from a script. Set it to "Future" once in Studio (Lighting > Technology).

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local MapLayout = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("MapLayout"))

local IslandTerrain = {}

local SAND_RADIUS = 215
local GRASS_RADIUS = 198
local WATER_HALF = 480 -- stays clear of Training Island, which starts at x = 570

-- Where hills may stand: near the rim, clear of every landmark and base.
local HILLS = {
	{ x = -190, z = 0, radius = 18 },
	{ x = 190, z = 10, radius = 18 },
	{ x = 55, z = 188, radius = 16 },
	{ x = -60, z = -188, radius = 16 },
	{ x = 188, z = -70, radius = 12 },
	{ x = -190, z = 80, radius = 12 },
}

function IslandTerrain.build()
	local terrain = Workspace.Terrain
	terrain:Clear()
	-- water first, then the island on top of it
	terrain:FillBlock(CFrame.new(0, -5, 0), Vector3.new(WATER_HALF * 2, 7, WATER_HALF * 2), Enum.Material.Water) -- surface at y = -1.5
	terrain:FillCylinder(CFrame.new(0, -4, 0), 8, SAND_RADIUS, Enum.Material.Sand) -- y from -8 to 0
	terrain:FillCylinder(CFrame.new(0, -3, 0), 6, GRASS_RADIUS, Enum.Material.Grass) -- y from -6 to 0
	for _, hill in HILLS do
		terrain:FillBall(Vector3.new(hill.x, -hill.radius * 0.45, hill.z), hill.radius, Enum.Material.Grass)
		terrain:FillBall(Vector3.new(hill.x, -hill.radius * 0.45 - hill.radius * 0.6, hill.z), hill.radius * 0.8, Enum.Material.Rock) -- a rocky foot
	end
	-- dirt paths from each base to the middle, and across the north to the Train portal
	local function path(ax: number, az: number, bx: number, bz: number)
		local from, to = Vector3.new(ax, -0.5, az), Vector3.new(bx, -0.5, bz)
		local middle = (from + to) / 2
		local cframe = CFrame.lookAt(middle, to)
		terrain:FillBlock(cframe, Vector3.new(9, 1, (to - from).Magnitude), Enum.Material.Ground)
	end
	for _, base in MapLayout.bases do
		path(base.x, base.z, 0, 0)
	end
	local portal = MapLayout.warPortals[1]
	path(MapLayout.bases[1].x, MapLayout.bases[1].z, portal.x, portal.z)
	path(MapLayout.bases[2].x, MapLayout.bases[2].z, portal.x, portal.z)
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
