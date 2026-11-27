--!strict
-- Slice 1 placeholder map: a baseplate, one spawn and one capture zone, all made by code so no Studio
-- editing is needed. Skipped if the place already has a part tagged "Zone" (a real map replaces this).

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local PlaceholderMap = {}

local function makePart(name: string, size: Vector3, position: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Color = color
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = Workspace
	return part
end

function PlaceholderMap.init() end

function PlaceholderMap.start()
	if #CollectionService:GetTagged("Zone") > 0 then
		return
	end

	makePart("Baseplate", Vector3.new(200, 2, 200), Vector3.new(0, -1, 0), Color3.fromRGB(90, 100, 110))

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Position = Vector3.new(0, 0.5, 60)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Parent = Workspace

	local zone = makePart("Zone", Vector3.new(30, 1, 30), Vector3.new(0, 0.5, -20), Color3.fromRGB(200, 200, 200))
	zone.CanCollide = false -- players walk straight onto it
	zone.Transparency = 0.3
	CollectionService:AddTag(zone, "Zone")
end

return PlaceholderMap
