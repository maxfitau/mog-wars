--!strict
-- Slice 1 placeholder map: a baseplate, four faction home bases and five capture zones, all made by code so no Studio
-- editing is needed. Skipped if the place already has a part tagged "Zone" (a real map replaces this).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local FactionRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FactionRules"))

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

	-- One safe home base per faction, in the four corners. Spawn pads share the faction's team colour,
	-- so Roblox sends each player to their own base.
	local corners = { Vector3.new(-80, 0.5, -80), Vector3.new(80, 0.5, -80), Vector3.new(80, 0.5, 80), Vector3.new(-80, 0.5, 80) }
	for index, faction in FactionRules.factions do
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "Base_" .. faction.name
		spawn.Size = Vector3.new(16, 1, 16)
		spawn.Position = corners[index]
		spawn.Anchored = true
		spawn.Neutral = false
		spawn.TeamColor = BrickColor.new(faction.brickColor)
		spawn.Color = FactionRules.color(faction)
		spawn:SetAttribute("HomeBase", faction.id)
		spawn.Parent = Workspace
	end

	-- Four side zones (worth 1) and a centre zone (worth 2), all open ground between the bases.
	local zoneSpots = {
		{ name = "Zone_North", position = Vector3.new(0, 0.5, -60), value = 1 },
		{ name = "Zone_East", position = Vector3.new(60, 0.5, 0), value = 1 },
		{ name = "Zone_South", position = Vector3.new(0, 0.5, 60), value = 1 },
		{ name = "Zone_West", position = Vector3.new(-60, 0.5, 0), value = 1 },
		{ name = "Zone_Centre", position = Vector3.new(0, 0.5, 0), value = 2 },
	}
	for _, spot in zoneSpots do
		local size = if spot.value == 2 then Vector3.new(36, 1, 36) else Vector3.new(28, 1, 28)
		local zone = makePart(spot.name, size, spot.position, Color3.fromRGB(200, 200, 200))
		zone.CanCollide = false -- players walk straight onto it
		zone.Transparency = 0.3
		zone:SetAttribute("Value", spot.value)
		CollectionService:AddTag(zone, "Zone")
	end
end

return PlaceholderMap
