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
local Features = require(Shared:WaitForChild("Features"))
local Territories = require(Shared:WaitForChild("Territories"))
local IslandTerrain = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("IslandTerrain"))
local Cover = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("Cover"))
local SkyKit = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("SkyKit"))
local Common = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("Places"):WaitForChild("Common"))
local SkyLinks = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("SkyLinks"))
local Builder = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("Builder"))
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

	IslandTerrain.lighting()
	IslandTerrain.build() -- clears the terrain and sets the colours; every island builds its own ground
	SkyKit.cloudSea() -- the endless cloud sea far below

	-- The four team spawn islands, low and near the corners: a grassy island each, the team's SpawnLocation, and banners
	-- in the team colour. Players start here (and come back here after a fall).
	local baseHeight, baseRadius = MapLayout.baseIslandHeight, MapLayout.baseIslandRadius
	for index, faction in FactionRules.factions do
		local base = MapLayout.bases[index]
		SkyKit.island(base.x, base.z, baseHeight, baseRadius, 36)
		SkyKit.vines(Workspace, base.x, base.z, baseHeight, baseRadius, 8)
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "Base_" .. faction.name
		spawn.Size = Vector3.new(MapLayout.baseSize, 1, MapLayout.baseSize)
		spawn.Position = Vector3.new(base.x, baseHeight + 0.5, base.z)
		spawn.Anchored = true
		spawn.Neutral = false
		spawn.TeamColor = BrickColor.new(faction.brickColor)
		spawn.Color = FactionRules.color(faction)
		spawn:SetAttribute("HomeBase", faction.id)
		spawn.Parent = Workspace
		for _, corner in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
			local px, pz = base.x + corner[1] * (baseRadius - 12), base.z + corner[2] * (baseRadius - 12)
			local pole = Builder.cylinder("BannerPole", 0.8, 14, Vector3.new(px, baseHeight + 7, pz), Color3.fromRGB(110, 78, 48), Workspace)
			pole.Material = Enum.Material.Wood
			local cloth = Builder.part("BannerCloth", Vector3.new(5, 8, 0.3), Vector3.new(px + 2.8, baseHeight + 9.5, pz), FactionRules.color(faction), Workspace)
			cloth.Material = Enum.Material.Fabric
			cloth.CanCollide = false
			cloth.CanQuery = false
		end
	end

	-- Rope bridges join the islands so that every island is reachable in about 20 seconds. Speed pads sit on them
	-- (+50 percent speed for 3 seconds); MovementSystem makes the pads work.
	local islands: { [string]: { x: number, z: number, y: number, r: number } } = {}
	for index, base in MapLayout.bases do
		islands["base" .. index] = { x = base.x, z = base.z, y = baseHeight, r = baseRadius }
	end
	for _, territory in Territories.list do
		if territory.radius > 0 then
			islands[territory.id] = { x = territory.x, z = territory.z, y = territory.height, r = territory.radius }
		end
	end
	local links = {
		{ "base1", "npc_village" }, { "base2", "rizz_ravine" }, { "base3", "cooked_canyon" }, { "base4", "brainrot_bog" },
		{ "npc_village", "locked_in_lighthouse" }, { "brainrot_bog", "locked_in_lighthouse" }, { "cooked_canyon", "rizz_ravine" },
		{ "locked_in_lighthouse", "gigachad_gate" }, { "rizz_ravine", "gigachad_gate" }, { "npc_village", "gigachad_gate" },
		{ "brainrot_bog", "gigachad_gate" }, { "cooked_canyon", "gigachad_gate" },
	}
	local bridges = Instance.new("Folder")
	bridges.Name = "Bridges"
	bridges.Parent = Workspace
	for _, link in links do
		local a, b = islands[link[1]], islands[link[2]]
		if a and b then
			local flat = Vector3.new(b.x - a.x, 0, b.z - a.z).Unit
			local from = Vector3.new(a.x, a.y, a.z) + flat * (a.r - 4)
			local to = Vector3.new(b.x, b.y, b.z) - flat * (b.r - 4)
			SkyKit.bridge(bridges, from, to, 10)
			local stashId = if link[1] == "base1" then "bridge_west" elseif link[1] == "cooked_canyon" and link[2] == "rizz_ravine" then "bridge_east" else nil
			if stashId then
				-- a hidden stash on a little platform hanging beside the middle of the bridge, a short drop from the deck
				local middle = from:Lerp(to, 0.5)
				local side = Vector3.new(-flat.Z, 0, flat.X)
				local ledge = Builder.part("HiddenLedge", Vector3.new(8, 1, 8), middle + side * 9 - Vector3.new(0, 7, 0), Color3.fromRGB(150, 105, 62), bridges)
				ledge.Material = Enum.Material.WoodPlanks
				Common.stash(bridges, ledge.Position + Vector3.new(0, 0.5, 0), link[1], stashId)
			end
			if Features.speedPads then
				for _, t in { 0.33, 0.66 } do
					local middle = from:Lerp(to, t)
					local pad = makePart("SpeedPad", Vector3.new(7, 0.4, 10), middle + Vector3.new(0, 0.2, 0), Color3.fromRGB(70, 220, 255))
					pad.CFrame = CFrame.lookAt(middle + Vector3.new(0, 0.2, 0), to + Vector3.new(0, 0.2, 0))
					pad.Material = Enum.Material.Neon
					pad.CanCollide = false
					pad.CanQuery = false
					pad.Transparency = 0.15
					pad.Parent = bridges
					CollectionService:AddTag(pad, "SpeedPad")
				end
			end
		end
	end
	SkyKit.decor() -- circling airships and floating mini rocks
	if Features.launchPads or Features.ziplines then
		SkyLinks.build(islands, Features.launchPads, Features.ziplines) -- launch pads and ziplines between the islands
	end

	-- The flags: one glowing zone per flag, tagged "Zone". CaptureSystem runs one capture bar per flag and groups
	-- them into territories by the "Territory" attribute. Each flag also gets a tall see-through pillar of light
	-- ("Beacon") and a point light so a child can spot it from across the map; CaptureSystem recolours them.
	for _, entry in Territories.allFlags() do
		local territory, flag = entry.territory, entry.flag
		local glow = Color3.fromRGB(0, 235, 255) -- bright cyan until someone owns it
		local zone = makePart(Territories.partName(territory, entry.index), Vector3.new(flag.size, 1, flag.size), Vector3.new(flag.x, flag.y + 0.5, flag.z), glow)
		zone.CanCollide = false -- players walk straight onto it
		zone.CanQuery = false -- aura blasts pass through
		zone.Transparency = 1 -- the zone part is only the invisible capture area; the circle below is what you see
		zone:SetAttribute("Value", Territories.tiers[territory.tier].value)
		zone:SetAttribute("Territory", territory.id)
		zone:SetAttribute("TerritoryName", territory.name)
		zone:SetAttribute("FlagName", flag.name)
		zone:SetAttribute("FlagIndex", entry.index)
		zone:SetAttribute("FlagCount", #territory.flags)

		-- the round capture circle: a white ring, a dark base, and a fill that grows from the middle as it is captured
		local function disc(name: string, diameter: number, thickness: number, lift: number, color: Color3, transparency: number): Part
			local part = Builder.cylinder(name, diameter, thickness, Vector3.new(flag.x, flag.y + lift, flag.z), color, zone)
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Transparency = transparency
			part.Material = Enum.Material.SmoothPlastic
			return part
		end
		disc("Ring", flag.size, 0.2, 0.1, Color3.new(1, 1, 1), 0.1)
		disc("Base", flag.size * 0.9, 0.25, 0.14, Color3.fromRGB(60, 50, 95), 0.45)
		disc("Fill", 0.1, 0.3, 0.2, Color3.new(1, 1, 1), 1)

		-- the flag pole with a cloth flag that takes the owner's colour
		local poleHeight = flag.pole or 16
		local pole = Builder.cylinder("Pole", 0.7, poleHeight, Vector3.new(flag.x, flag.y + poleHeight / 2, flag.z), Color3.fromRGB(235, 235, 240), zone)
		pole.Material = Enum.Material.Metal
		pole.CanCollide = false
		pole.CanQuery = false
		local cloth = Builder.part("Cloth", Vector3.new(7, 4.5, 0.25), Vector3.new(flag.x + 3.7, flag.y + poleHeight - 2.4, flag.z), Color3.new(1, 1, 1), zone)
		cloth.Material = Enum.Material.Fabric
		cloth.CanCollide = false
		cloth.CanQuery = false
		local knob = Builder.ball("PoleTop", Vector3.new(1.4, 1.4, 1.4), Vector3.new(flag.x, flag.y + poleHeight + 0.3, flag.z), Color3.fromRGB(255, 205, 60), zone)
		knob.CanCollide = false
		knob.CanQuery = false

		-- one thin beam per flag, only visible while it is neutral or contested
		local beamHeight = flag.beam or 45
		local beacon = makePart("Beacon", Vector3.new(0.9, beamHeight, 0.9), Vector3.new(flag.x, flag.y + beamHeight / 2, flag.z), Color3.new(1, 1, 1))
		beacon.CanCollide = false
		beacon.CanQuery = false
		beacon.CanTouch = false
		beacon.Transparency = 0.5
		beacon.Material = Enum.Material.Neon
		beacon.Parent = zone
		CollectionService:AddTag(zone, "Zone")
	end

	-- The six territories' scenery and floating name signs, and cover for Mog fights.
	TerritoryScenery.build()
	Cover.build()

	if not Features.trainingIsland then
		print("[mog-wars] map built: War Island (6 territories, 10 flags); Training Island is switched off")
		return
	end

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
