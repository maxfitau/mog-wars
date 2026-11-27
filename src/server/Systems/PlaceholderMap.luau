--!strict
-- Placeholder map built by code from src/shared/MapLayout.luau: a baseplate, four faction home bases and the
-- capture zones. Skipped if the place already has a part tagged "Zone" (a real map replaces this one).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FactionRules = require(Shared:WaitForChild("FactionRules"))
local MapLayout = require(Shared:WaitForChild("MapLayout"))

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

	local plate = MapLayout.baseplateSize
	makePart("Baseplate", Vector3.new(plate, 2, plate), Vector3.new(0, -1, 0), Color3.fromRGB(90, 100, 110))

	-- One safe home base per faction. Spawn pads share the faction's team colour, so Roblox sends each player
	-- to their own base first; SpawnSystem then moves them to the front line during a war.
	for index, faction in FactionRules.factions do
		local base = MapLayout.bases[index]
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "Base_" .. faction.name
		spawn.Size = Vector3.new(MapLayout.baseSize, 1, MapLayout.baseSize)
		spawn.Position = Vector3.new(base.x, 0.5, base.z)
		spawn.Anchored = true
		spawn.Neutral = false
		spawn.TeamColor = BrickColor.new(faction.brickColor)
		spawn.Color = FactionRules.color(faction)
		spawn:SetAttribute("HomeBase", faction.id)
		spawn.Parent = Workspace
	end

	for _, spec in MapLayout.zones do
		local zone = makePart(
			spec.name,
			Vector3.new(spec.size, 1, spec.size),
			Vector3.new(spec.x, 0.5, spec.z),
			Color3.fromRGB(200, 200, 200)
		)
		zone.CanCollide = false -- players walk straight onto it
		zone.Transparency = 0.3
		zone:SetAttribute("Value", spec.value)
		CollectionService:AddTag(zone, "Zone")
	end
end

return PlaceholderMap
