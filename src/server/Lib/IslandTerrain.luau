--!strict
-- War Island as real Terrain: a sand beach ring, grass on top, a few hills, dirt paths from each base toward the
-- middle, and water all around. Also sets the bright daytime lighting. Static terrain costs almost nothing on phones.
-- The ground surface is at y = 0, so every flag, ramp and landmark height in Territories.luau stays valid.
-- NOTE: Lighting.Technology cannot be set from a script. Set it to "Future" once in Studio (Lighting > Technology).

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")


local IslandTerrain = {}

local TerrainKit = require(script.Parent:WaitForChild("TerrainKit"))

-- There is no big island any more: War Island is a sky of floating islands, each built by its own territory module (or by
-- PlaceholderMap for the team islands). All this does is clear the terrain and set the cartoon colours.
function IslandTerrain.build()
	Workspace.Terrain:Clear()
	TerrainKit.colors()
end

-- GOLDEN HOUR (from the reference images): a low warm sun, a hazy golden-olive atmosphere so far islands fade into it,
-- a warm colour grade, a soft bloom and sun rays, and a peach-white cloud sea far below.
-- NOTE: Lighting.Technology = Future cannot always be set from a script. We try; if Studio refuses, set it once by hand
-- (Lighting > Technology > Future) and save the place.
function IslandTerrain.lighting()
	local terrain = Workspace.Terrain
	pcall(function()
		(Lighting :: any).Technology = Enum.Technology.Future
	end)
	local decorationOff = pcall(function()
		terrain.Decoration = false -- no tall terrain grass blades: a short, soft green instead
	end)
	if not decorationOff or terrain.Decoration then
		warn("[mog-wars] Terrain.Decoration could not be turned off from a script. In Studio select Workspace > Terrain and untick Decoration (once, then save the place).")
	end
	Lighting.ClockTime = 16.5
	Lighting.GeographicLatitude = 25
	Lighting.Brightness = 3
	Lighting.Ambient = Color3.fromRGB(150, 132, 104)
	Lighting.OutdoorAmbient = Color3.fromRGB(172, 152, 118)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 222, 160)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.ShadowSoftness = 0.3
	Lighting.FogEnd = 100000
	Lighting.FogStart = 100000
	for _, child in Lighting:GetChildren() do
		if child:IsA("Atmosphere") or child:IsA("BloomEffect") or child:IsA("ColorCorrectionEffect") or child:IsA("SunRaysEffect") then
			child:Destroy()
		end
	end
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.2
	atmosphere.Color = Color3.fromRGB(255, 226, 152) -- soft golden haze
	atmosphere.Decay = Color3.fromRGB(255, 188, 92)
	atmosphere.Glare = 0.6
	atmosphere.Haze = 1.4
	atmosphere.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.4
	bloom.Size = 36
	bloom.Threshold = 1.0
	bloom.Parent = Lighting
	local color = Instance.new("ColorCorrectionEffect")
	color.TintColor = Color3.fromRGB(255, 243, 216) -- slightly warm
	color.Saturation = 0.2
	color.Contrast = 0.1
	color.Parent = Lighting
	local sun = Instance.new("SunRaysEffect")
	sun.Intensity = 0.15
	sun.Spread = 0.8
	sun.Parent = Lighting
	if not Lighting:FindFirstChildOfClass("Sky") then
		Instance.new("Sky").Parent = Lighting
	end
	terrain.WaterColor = Color3.fromRGB(88, 170, 205)
	terrain.WaterTransparency = 0.55
	terrain.WaterWaveSize = 0.15
	terrain.WaterWaveSpeed = 8
	terrain.WaterReflectance = 0.25
end

return IslandTerrain
