--!strict
-- Placeholder map built by code from src/shared/MapLayout.luau: a baseplate, four faction home bases, a
-- treadmill for the Training Arena beside each base, and the capture zones. Skipped if the place already has a part tagged "Zone" (a real map replaces this one).

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

	-- Training Arena: a treadmill belt by each base. The belt pushes along z; players walk against it.
	for index, spec in MapLayout.treadmills do
		local belt = makePart(
			"Treadmill_" .. index,
			Vector3.new(spec.width, 1, spec.length),
			Vector3.new(spec.x, 0.5, spec.z),
			Color3.fromRGB(60, 60, 70)
		)
		belt.Material = Enum.Material.Metal
		belt:SetAttribute("BeltPush", spec.push)
		CollectionService:AddTag(belt, "Treadmill")

		local sign = Instance.new("BillboardGui")
		sign.Name = "TrainingSign"
		sign.Size = UDim2.new(0, 180, 0, 40)
		sign.StudsOffset = Vector3.new(0, 7, 0)
		sign.AlwaysOnTop = true
		sign.Adornee = belt
		sign.Parent = belt
		local text = Instance.new("TextLabel")
		text.Size = UDim2.new(1, 0, 1, 0)
		text.BackgroundTransparency = 1
		text.TextColor3 = Color3.fromRGB(255, 220, 90)
		text.Font = Enum.Font.GothamBold
		text.TextScaled = true
		text.Text = "Training Arena"
		text.Parent = sign
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
		zone.Material = Enum.Material.Neon -- glows, so a new player can spot it from far away
		zone:SetAttribute("Value", spec.value)
		CollectionService:AddTag(zone, "Zone")
	end
end

return PlaceholderMap
