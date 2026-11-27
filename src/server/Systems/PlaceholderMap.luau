--!strict
-- Placeholder map built by code from src/shared/MapLayout.luau, in two islands in one place:
--   War Island: a baseplate, four faction home bases, the capture zones and a portal by each base.
--   Training Island: one platform far away with all the treadmills, the shop, a portal back to the war,
--   and empty reserved space for the prestige altar and the Mog Arena plots (nothing is built there yet).
-- Skipped if the place already has a part tagged "Zone" (a real map replaces this one).

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

local function addSign(part: BasePart, text: string, color: Color3, height: number)
	local sign = Instance.new("BillboardGui")
	sign.Name = "Sign"
	sign.Size = UDim2.new(0, 220, 0, 52)
	sign.StudsOffset = Vector3.new(0, height, 0)
	sign.AlwaysOnTop = true
	sign.Adornee = part
	sign.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.3
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.Parent = sign
end

-- A glowing pad. Walking into it sends you to `destination` ("training" or "war"); TravelSystem does the move.
local function makePortal(name: string, x: number, z: number, size: number, color: Color3, destination: string, text: string)
	local pad = makePart(name, Vector3.new(size, 1, size), Vector3.new(x, 0.5, z), color)
	pad.CanCollide = false
	pad.Material = Enum.Material.Neon
	pad.Transparency = 0.2
	pad:SetAttribute("Destination", destination)
	CollectionService:AddTag(pad, "Portal")
	addSign(pad, text, Color3.new(1, 1, 1), 6)
end

function PlaceholderMap.init() end

function PlaceholderMap.start()
	if #CollectionService:GetTagged("Zone") > 0 then
		return
	end

	-- Studio's Baseplate template adds its own "Baseplate" and "SpawnLocation". They would overlap this map
	-- and send players to the wrong place, so they are removed from this running game (not from your file).
	for _, name in { "Baseplate", "SpawnLocation" } do
		local old = Workspace:FindFirstChild(name)
		if old then
			old:Destroy()
		end
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
		zone.Material = Enum.Material.Neon -- glows, so a new player can spot it from far away
		zone:SetAttribute("Value", spec.value)
		CollectionService:AddTag(zone, "Zone")
	end

	-- A portal beside each home base: walk in to go to Training Island.
	for index, portal in MapLayout.warPortals do
		makePortal("Portal_Train_" .. index, portal.x, portal.z, portal.size, Color3.fromRGB(255, 170, 40), "training", "TRAIN")
	end

	-- Training Island: one platform, far from the war. Positions in MapLayout are local to its centre.
	local island = MapLayout.trainingIsland
	local function at(localX: number, localZ: number): (number, number)
		return island.x + localX, island.z + localZ
	end
	makePart("TrainingIsland", Vector3.new(island.size, 2, island.size), Vector3.new(island.x, -1, island.z), Color3.fromRGB(110, 150, 120))

	for index, mill in island.treadmills do
		local x, z = at(mill.x, mill.z)
		local belt = makePart("Treadmill_" .. index, Vector3.new(mill.width, 1, mill.length), Vector3.new(x, 0.5, z), Color3.fromRGB(60, 60, 70))
		belt.Material = Enum.Material.Metal
		belt:SetAttribute("BeltPush", mill.push)
		CollectionService:AddTag(belt, "Treadmill")
		if index == 1 then
			addSign(belt, "Training Area", Color3.fromRGB(255, 220, 90), 8)
		end
	end

	local shopX, shopZ = at(island.shop.x, island.shop.z)
	local kiosk = makePart("ShopKiosk", Vector3.new(island.shop.size, 8, island.shop.size), Vector3.new(shopX, 4, shopZ), Color3.fromRGB(70, 180, 100))
	kiosk.Material = Enum.Material.SmoothPlastic
	addSign(kiosk, "SHOP", Color3.new(1, 1, 1), 7)

	local backX, backZ = at(island.returnPortal.x, island.returnPortal.z)
	makePortal("Portal_BackToWar", backX, backZ, island.returnPortal.size, Color3.fromRGB(70, 200, 110), "war", "BACK TO WAR")
	-- The reserved areas (prestige altar, Mog Arena plots) are deliberately left empty.
	print("[mog-wars] map built: War Island and Training Island")
end

return PlaceholderMap
