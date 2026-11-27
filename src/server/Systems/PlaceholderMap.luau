--!strict
-- Placeholder map built by code from src/shared/MapLayout.luau, in two islands in one place:
--   War Island: a baseplate, four corner home bases, six territories (ten capture flags) with simple
--   scenery and signs, and a portal to Training Island at the top edge.
--   Training Island: one platform far away with all the treadmills, the shop, a portal back to the war,
--   and empty reserved space for the prestige altar and the Mog Arena plots (nothing is built there yet).
-- Skipped if the place already has a part tagged "Zone" (a real map replaces this one).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FactionRules = require(Shared:WaitForChild("FactionRules"))
local MapLayout = require(Shared:WaitForChild("MapLayout"))
local Territories = require(Shared:WaitForChild("Territories"))
local TerritoryScenery = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("TerritoryScenery"))

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

-- One clear sign per place: a real board on a post standing in the world (not a floating label), so signs
-- never pile up on top of each other on screen. The board faces `facing` so it can be read from there.
local function makeSign(name: string, text: string, base: Vector3, facing: Vector3, width: number, height: number, color: Color3)
	local postHeight = 5
	local post = makePart(name .. "Post", Vector3.new(1, postHeight, 1), base + Vector3.new(0, postHeight / 2, 0), Color3.fromRGB(60, 50, 80))
	post.CanCollide = false
	local boardPosition = base + Vector3.new(0, postHeight + height / 2, 0)
	local board = makePart(name, Vector3.new(width, height, 1), boardPosition, color)
	board.CFrame = CFrame.lookAt(boardPosition, Vector3.new(facing.X, boardPosition.Y, facing.Z))
	board.CanCollide = false
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeColor3 = Color3.fromRGB(35, 25, 60)
	label.TextStrokeTransparency = 0
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.Parent = gui
end

-- A glowing pad. Walking into it sends you to `destination` ("training" or "war"); TravelSystem does the move.
local function makePortal(name: string, x: number, z: number, size: number, color: Color3, destination: string)
	local pad = makePart(name, Vector3.new(size, 1, size), Vector3.new(x, 0.5, z), color)
	pad.CanCollide = false
	pad.CanQuery = false
	pad.Material = Enum.Material.Neon
	pad.Transparency = 0.2
	pad:SetAttribute("Destination", destination)
	CollectionService:AddTag(pad, "Portal")
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

	-- The flags: one glowing zone per flag, tagged "Zone". CaptureSystem runs one capture bar per flag and groups
	-- them into territories by the "Territory" attribute. Each flag also gets a tall see-through pillar of light
	-- ("Beacon") and a point light so a child can spot it from across the map; CaptureSystem recolours them.
	for _, entry in Territories.allFlags() do
		local territory, flag = entry.territory, entry.flag
		local glow = Color3.fromRGB(0, 235, 255) -- bright cyan until someone owns it
		local zone = makePart(Territories.partName(territory, entry.index), Vector3.new(flag.size, 1, flag.size), Vector3.new(flag.x, flag.y + 0.5, flag.z), glow)
		zone.CanCollide = false -- players walk straight onto it
		zone.CanQuery = false -- paintballs pass through
		zone.Transparency = 0.15
		zone.Material = Enum.Material.Neon -- glows
		zone:SetAttribute("Value", Territories.tiers[territory.tier].value)
		zone:SetAttribute("Territory", territory.id)
		zone:SetAttribute("TerritoryName", territory.name)
		zone:SetAttribute("FlagName", flag.name)
		zone:SetAttribute("FlagIndex", entry.index)
		zone:SetAttribute("FlagCount", #territory.flags)

		local beacon = makePart("Beacon", Vector3.new(3, 70, 3), Vector3.new(flag.x, flag.y + 35.5, flag.z), glow)
		beacon.CanCollide = false
		beacon.CanQuery = false
		beacon.CanTouch = false
		beacon.Transparency = 0.55
		beacon.Material = Enum.Material.Neon
		beacon.Parent = zone

		local light = Instance.new("PointLight")
		light.Color = glow
		light.Brightness = 3
		light.Range = 30
		light.Parent = zone
		CollectionService:AddTag(zone, "Zone")
	end

	-- The six territories' scenery and name signs (simple placeholder shapes).
	TerritoryScenery.build()

	-- The portal to Training Island, at the top (north) edge. One sign beside it.
	for index, portal in MapLayout.warPortals do
		makePortal("Portal_Train_" .. index, portal.x, portal.z, portal.size, Color3.fromRGB(255, 170, 40), "training")
		makeSign(
			"Sign_Train_" .. index,
			"TRAIN",
			Vector3.new(portal.x + 18, 0, portal.z),
			Vector3.new(portal.x + 18, 0, portal.z + 40), -- faces south, toward the map
			16,
			5,
			Color3.fromRGB(255, 150, 20)
		)
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
	end
	-- ONE sign for the whole treadmill row, in front of it, facing the arrival spot (south)
	local signX, signZ = at(0, 62)
	makeSign("Sign_TrainingArea", "TRAINING AREA", Vector3.new(signX, 0, signZ), Vector3.new(signX, 0, signZ + 40), 30, 6, Color3.fromRGB(70, 150, 255))

	local shopX, shopZ = at(island.shop.x, island.shop.z)
	local kiosk = makePart("ShopKiosk", Vector3.new(island.shop.size, 8, island.shop.size), Vector3.new(shopX, 4, shopZ), Color3.fromRGB(70, 180, 100))
	kiosk.Material = Enum.Material.SmoothPlastic
	-- the kiosk's own face is its sign (the south face, toward the arrival spot)
	local kioskGui = Instance.new("SurfaceGui")
	kioskGui.Face = Enum.NormalId.Back
	kioskGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	kioskGui.PixelsPerStud = 40
	kioskGui.Parent = kiosk
	local kioskLabel = Instance.new("TextLabel")
	kioskLabel.Size = UDim2.new(1, 0, 1, 0)
	kioskLabel.BackgroundTransparency = 1
	kioskLabel.TextColor3 = Color3.new(1, 1, 1)
	kioskLabel.TextStrokeColor3 = Color3.fromRGB(35, 25, 60)
	kioskLabel.TextStrokeTransparency = 0
	kioskLabel.Font = Enum.Font.FredokaOne
	kioskLabel.TextScaled = true
	kioskLabel.Text = "SHOP"
	kioskLabel.Parent = kioskGui

	local backX, backZ = at(island.returnPortal.x, island.returnPortal.z)
	makePortal("Portal_BackToWar", backX, backZ, island.returnPortal.size, Color3.fromRGB(70, 200, 110), "war")
	-- one sign beside the return portal, facing the arrival spot so you can read it as you land
	local arriveX, arriveZ = at(island.arrival.x, island.arrival.z)
	makeSign("Sign_BackToWar", "BACK TO WAR", Vector3.new(backX - 16, 0, backZ - 4), Vector3.new(arriveX, 0, arriveZ - 30), 20, 5, Color3.fromRGB(60, 190, 100))
	-- The reserved areas (prestige altar, Mog Arena plots) are deliberately left empty.
	print("[mog-wars] map built: War Island (6 territories, 10 flags) and Training Island")
end

return PlaceholderMap
