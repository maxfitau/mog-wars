--!strict
-- Simple placeholder scenery for the six territories, built from blocks, cylinders and ramps. Detailed art
-- comes later. Positions come from src/shared/Territories.luau; the shapes here are loose decoration around
-- those positions (the flags themselves are built by PlaceholderMap). Nothing here needs any asset id.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Territories = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Territories"))
local Builder = require(script.Parent:WaitForChild("Builder"))

local SPARKLES = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local STONE = Color3.fromRGB(125, 125, 140)
local PURPLE = Color3.fromRGB(140, 60, 210)
local ROCK = Color3.fromRGB(150, 110, 90)

local TIER_COLORS = {
	gold = Color3.fromRGB(240, 170, 20),
	diamond = Color3.fromRGB(50, 170, 235),
	ultra = Color3.fromRGB(170, 70, 235),
}

-- Real materials instead of plain plastic, chosen from each part's name (anything not listed stays as it is).
local MATERIALS: { { string, Enum.Material } } = {
	{ "Tower", Enum.Material.Cobblestone }, { "CastleWall", Enum.Material.Cobblestone }, { "Merlon", Enum.Material.Cobblestone },
	{ "Jaw", Enum.Material.Slate }, { "UpperHead", Enum.Material.Slate }, { "Nose", Enum.Material.Slate }, { "Brow", Enum.Material.Slate },
	{ "Banner", Enum.Material.Fabric }, { "HeadRamp", Enum.Material.Concrete },
	{ "Cliff", Enum.Material.Rock }, { "Ramp", Enum.Material.WoodPlanks }, { "Bridge", Enum.Material.WoodPlanks },
	{ "Rope", Enum.Material.Fabric }, { "Stripe", Enum.Material.Concrete }, { "TopPlatform", Enum.Material.Concrete },
	{ "Leg", Enum.Material.Slate }, { "Torso", Enum.Material.Slate }, { "Arm", Enum.Material.Slate }, { "Head", Enum.Material.Slate },
	{ "PanLeg", Enum.Material.Rock }, { "RockWall", Enum.Material.Rock }, { "Pan", Enum.Material.Metal },
	{ "DeadTree", Enum.Material.Wood }, { "BrainPad", Enum.Material.SmoothPlastic },
}

local function applyMaterials(folder: Folder)
	for _, part in folder:GetDescendants() do
		if part:IsA("BasePart") and part.Material == Enum.Material.Plastic then
			if string.find(part.Name, "Ramp$") then
				part.Material = Enum.Material.WoodPlanks
			end
			for _, entry in MATERIALS do
				if part.Material ~= Enum.Material.Plastic then
					break
				end
				if string.sub(part.Name, 1, #entry[1]) == entry[1] then
					part.Material = entry[2]
					break
				end
			end
		end
	end
end

local TerritoryScenery = {}

local function solid(part: Part): Part
	part.CanCollide = true
	return part
end

local function decor(part: Part): Part
	part.CanCollide = false
	return part
end

local function sparkles(folder: Folder, name: string, position: Vector3, color: Color3, rate: number)
	local emitter = Builder.emitter(name, position, SPARKLES, color, folder)
	emitter.Rate = rate
	emitter.Lifetime = NumberRange.new(1, 2)
	emitter.Speed = NumberRange.new(2, 5)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new(1.4, 0)
	emitter.Transparency = NumberSequence.new(0.1, 1)
	emitter.LightEmission = 0.7
end

local function steam(folder: Folder, name: string, position: Vector3)
	local emitter = Builder.emitter(name, position, SMOKE, Color3.fromRGB(245, 245, 245), folder)
	emitter.Rate = 6
	emitter.Lifetime = NumberRange.new(3, 4)
	emitter.Speed = NumberRange.new(3, 5)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Size = NumberSequence.new(4, 10)
	emitter.Transparency = NumberSequence.new(0.5, 1)
end

-- ---------- Centre: Gigachad Gate. A giant stone face (square jaw, sunglasses); its mouth is the gate ----------
local function gigachadGate(folder: Folder, territory: Territories.Territory)
	local cx, cz = territory.x, territory.z
	local function block(name: string, x: number, y: number, z: number, sx: number, sy: number, sz: number, color: Color3)
		return solid(Builder.part(name, Vector3.new(sx, sy, sz), Vector3.new(cx + x, y, cz + z), color, folder))
	end
	local face = Color3.fromRGB(150, 150, 165)
	-- the head: two jaw blocks with a 14-wide mouth tunnel between them, and the upper head across the top
	block("JawLeft", -12.5, 10, 0, 11, 20, 40, face)
	block("JawRight", 12.5, 10, 0, 11, 20, 40, face)
	block("UpperHead", 0, 27, 0, 36, 14, 40, face) -- its top is 34 high: the flag platform
	-- the face is on the south side (z = +20): sunglasses, nose, brow and a square chin
	decor(Builder.part("Sunglasses", Vector3.new(32, 5, 1), Vector3.new(cx, 26, cz + 20.5), Color3.fromRGB(15, 15, 20), folder))
	decor(Builder.part("GlassesBridge", Vector3.new(4, 1.2, 1.2), Vector3.new(cx, 27, cz + 21), Color3.fromRGB(15, 15, 20), folder))
	block("Nose", 0, 20, 22, 5, 9, 4, Color3.fromRGB(135, 135, 150))
	decor(Builder.part("Brow", Vector3.new(34, 2, 2), Vector3.new(cx, 30, cz + 21), Color3.fromRGB(110, 110, 125), folder))
	decor(Builder.part("MouthDark", Vector3.new(14, 11, 0.4), Vector3.new(cx, 5.5, cz + 20.2), Color3.fromRGB(20, 15, 25), folder))
	-- two towers beside the head (flags at their bases), each with a purple banner
	for _, side in { -1, 1 } do
		block("Tower", side * 30, 14, -14, 10, 28, 10, STONE)
		decor(Builder.part("Banner", Vector3.new(5, 14, 0.5), Vector3.new(cx + side * 30, 17, cz - 8.6), PURPLE, folder))
		decor(Builder.part("BannerHead", Vector3.new(4, 14, 0.5), Vector3.new(cx + side * 17, 22, cz + 20.4), PURPLE, folder))
	end
	-- stone castle walls running out from each tower, with battlement blocks along the top
	for _, side in { -1, 1 } do
		block("CastleWall", side * 52, 9, -14, 30, 18, 4, STONE)
		for index = 0, 5 do
			block("Merlon", side * (40 + index * 5.6), 19.5, -14, 3, 3, 4, STONE)
		end
	end
	-- a long ramp up the back of the head from the north edge of the map
	Builder.ramp("HeadRamp", Vector3.new(cx, 0, cz - 135), Vector3.new(cx, 34, cz - 22), 10, Color3.fromRGB(165, 165, 180), folder)
end

-- ---------- Inner ring: Rizz Ravine, two cliffs, a rope bridge and a giant pink heart ----------
local function rizzRavine(folder: Folder, territory: Territories.Territory)
	local cx, cz = territory.x, territory.z
	decor(Builder.part("RavineFloor", Vector3.new(48, 0.3, 20), Vector3.new(cx, 0.15, cz), Color3.fromRGB(35, 28, 40), folder))
	solid(Builder.part("NorthCliff", Vector3.new(48, 5, 24), Vector3.new(cx, 2.5, cz - 22), ROCK, folder))
	solid(Builder.part("SouthCliff", Vector3.new(48, 5, 24), Vector3.new(cx, 2.5, cz + 22), ROCK, folder))
	Builder.ramp("NorthRamp", Vector3.new(cx, 0, cz - 55), Vector3.new(cx, 5, cz - 34), 10, ROCK, folder)
	Builder.ramp("SouthRamp", Vector3.new(cx, 0, cz + 58), Vector3.new(cx, 5, cz + 34), 10, ROCK, folder)
	solid(Builder.part("BridgePlanks", Vector3.new(6, 0.6, 20), Vector3.new(cx, 4.7, cz), Color3.fromRGB(150, 110, 60), folder))
	decor(Builder.part("RopeLeft", Vector3.new(0.3, 0.3, 20), Vector3.new(cx - 3, 7, cz), Color3.fromRGB(200, 180, 130), folder))
	decor(Builder.part("RopeRight", Vector3.new(0.3, 0.3, 20), Vector3.new(cx + 3, 7, cz), Color3.fromRGB(200, 180, 130), folder))
	-- the giant heart above the middle of the bridge: two balls and a tilted block make the point
	local pink = Color3.fromRGB(255, 80, 160)
	local height = 22
	decor(Builder.ball("HeartLeft", Vector3.new(22, 22, 14), Vector3.new(cx - 8, height + 6, cz), pink, folder))
	decor(Builder.ball("HeartRight", Vector3.new(22, 22, 14), Vector3.new(cx + 8, height + 6, cz), pink, folder))
	local point = Builder.part("HeartPoint", Vector3.new(15, 15, 14), Vector3.new(cx, height - 1, cz), pink, folder)
	point.CFrame = CFrame.new(cx, height - 1, cz) * CFrame.Angles(0, 0, math.rad(45))
	point.CanCollide = false
	for index, offset in { { -10, 8 }, { 10, 8 }, { 0, -4 }, { 0, 18 } } do
		sparkles(folder, "HeartSparkles" .. index, Vector3.new(cx + offset[1], height + offset[2], cz), Color3.fromRGB(255, 190, 235), 14)
	end
end

-- ---------- Inner ring: Locked-In Lighthouse. The lamp is a giant golden padlock shining a beam ----------
local function lighthouse(folder: Folder, territory: Territories.Territory)
	local top = territory.flags[2].y
	local stripeHeight = (top - 1.5) / 4
	for index = 0, 3 do
		local color = if index % 2 == 0 then Color3.fromRGB(215, 55, 55) else Color3.fromRGB(240, 240, 240)
		solid(Builder.cylinder("Stripe" .. index, 12, stripeHeight, Vector3.new(territory.x, stripeHeight * (index + 0.5), territory.z), color, folder))
	end
	solid(Builder.part("TopPlatform", Vector3.new(22, 1.5, 22), Vector3.new(territory.x, top - 0.75, territory.z), Color3.fromRGB(240, 230, 200), folder))
	-- the golden padlock: a body, a U-shaped shackle and a keyhole
	local gold = Color3.fromRGB(255, 200, 40)
	local lockY = top + 9
	local body = Builder.part("PadlockBody", Vector3.new(14, 11, 7), Vector3.new(territory.x, lockY, territory.z), gold, folder)
	body.Material = Enum.Material.Metal
	body.CanCollide = false
	for _, side in { -1, 1 } do
		decor(Builder.cylinder("ShackleSide", 2.4, 8, Vector3.new(territory.x + side * 4.5, lockY + 9, territory.z), gold, folder))
	end
	local shackleTop = decor(Builder.cylinder("ShackleTop", 2.4, 12.6, Vector3.new(territory.x, lockY + 13, territory.z), gold, folder))
	shackleTop.CFrame = CFrame.new(territory.x, lockY + 13, territory.z) -- lies along X, joining the two sides
	decor(Builder.part("Keyhole", Vector3.new(2.2, 4, 0.4), Vector3.new(territory.x - 0.0, lockY, territory.z + 3.7), Color3.fromRGB(30, 25, 20), folder))
	-- the beam: a long glowing bar shining east, toward the middle of the map, plus a light
	local beam = Builder.part("Beam", Vector3.new(5, 5, 110), Vector3.new(territory.x + 55, lockY, territory.z), Color3.fromRGB(255, 245, 160), folder)
	beam.CFrame = CFrame.lookAt(Vector3.new(territory.x + 55, lockY, territory.z), Vector3.new(territory.x + 120, lockY, territory.z))
	beam.Material = Enum.Material.Neon
	beam.Transparency = 0.6
	beam.CanCollide = false
	beam.CanQuery = false
	local pivot = Vector3.new(territory.x, lockY, territory.z)
	local angle = 0
	task.spawn(function()
		while beam.Parent do
			task.wait(0.1) -- 10 small steps a second: one part, cheap
			angle += math.rad(4)
			local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
			beam.CFrame = CFrame.lookAt(pivot + direction * 55, pivot + direction * 120)
		end
	end)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 240, 150)
	light.Range = 45
	light.Brightness = 2
	light.Parent = body
	Builder.ramp("LighthouseRamp", Vector3.new(-155, 0, territory.z), Vector3.new(territory.x - 11, top, territory.z), 10, Color3.fromRGB(190, 170, 140), folder)
end

-- ---------- Outer ring: NPC Village. A giant blocky grey NPC statue, blank face, "..." bubble ----------
local function npcVillage(folder: Folder, territory: Territories.Territory)
	local cx, cz = territory.x, territory.z
	local grey = Color3.fromRGB(150, 150, 158)
	local dark = Color3.fromRGB(110, 110, 118)
	local top = territory.flags[1].y
	solid(Builder.part("LegLeft", Vector3.new(6, 10, 6), Vector3.new(cx - 4, 5, cz), dark, folder))
	solid(Builder.part("LegRight", Vector3.new(6, 10, 6), Vector3.new(cx + 4, 5, cz), dark, folder))
	solid(Builder.part("Torso", Vector3.new(16, 12, 8), Vector3.new(cx, 16, cz), grey, folder))
	decor(Builder.part("ArmLeft", Vector3.new(4, 12, 4), Vector3.new(cx - 10, 16, cz), dark, folder))
	decor(Builder.part("ArmRight", Vector3.new(4, 12, 4), Vector3.new(cx + 10, 16, cz), dark, folder))
	solid(Builder.part("Head", Vector3.new(12, 10, 12), Vector3.new(cx, 27, cz), Color3.fromRGB(190, 190, 198), folder)) -- a blank face
	solid(Builder.part("HeadPlatform", Vector3.new(18, 1, 18), Vector3.new(cx, top - 0.5, cz), Color3.fromRGB(170, 170, 180), folder))
	-- the speech bubble: a white squashed ball beside the head with three dots on it
	local bubble = Builder.ball("SpeechBubble", Vector3.new(22, 13, 3), Vector3.new(cx + 18, 36, cz + 8), Color3.new(1, 1, 1), folder)
	bubble.CanCollide = false
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = bubble
	local dots = Instance.new("TextLabel")
	dots.Size = UDim2.new(1, 0, 1, 0)
	dots.BackgroundTransparency = 1
	dots.TextColor3 = Color3.fromRGB(35, 25, 60)
	dots.Font = Enum.Font.FredokaOne
	dots.TextScaled = true
	dots.Text = "..."
	dots.Parent = gui
	decor(Builder.ball("BubbleTail", Vector3.new(4, 4, 2), Vector3.new(cx + 9, 31, cz + 8), Color3.new(1, 1, 1), folder))
	-- four small cube houses around the statue
	for index, offset in { { -30, -25 }, { 30, -25 }, { -30, 30 }, { 30, 30 } } do
		local hx, hz = cx + offset[1], cz + offset[2]
		local wall = solid(Builder.part("House" .. index, Vector3.new(9, 8, 9), Vector3.new(hx, 4, hz), Color3.fromRGB(235, 220, 185), folder))
		wall.Material = Enum.Material.WoodPlanks
		local roof = solid(Builder.part("HouseRoof" .. index, Vector3.new(11, 2, 11), Vector3.new(hx, 9, hz), Color3.fromRGB(200, 80, 70), folder))
		roof.Material = Enum.Material.Slate
		decor(Builder.part("HouseDoor" .. index, Vector3.new(2.4, 4, 0.3), Vector3.new(hx, 2, hz + 4.6), Color3.fromRGB(110, 70, 45), folder))
	end
	Builder.ramp("StatueRamp", Vector3.new(cx - 85, 0, cz), Vector3.new(cx - 9, top, cz), 10, Color3.fromRGB(175, 175, 185), folder)
end

-- ---------- Outer ring: Brainrot Bog. A giant pink brain half-sunk in bubbling green goo ----------
local function brainrotBog(folder: Folder, territory: Territories.Territory)
	local cx, cz = territory.x, territory.z
	local top = territory.flags[1].y
	local pool = Builder.cylinder("SwampPool", 64, 0.4, Vector3.new(cx, 0.2, cz), Color3.fromRGB(70, 190, 60), folder)
	pool.Material = Enum.Material.Mud
	pool.Transparency = 0
	pool.CanCollide = false
	-- the brain: two big hemispheres with darker folds, mostly under the goo (you can walk through it)
	local pink = Color3.fromRGB(255, 130, 175)
	local folds = Color3.fromRGB(235, 95, 150)
	decor(Builder.ball("BrainLeft", Vector3.new(30, 26, 34), Vector3.new(cx - 8, 3, cz), pink, folder))
	decor(Builder.ball("BrainRight", Vector3.new(30, 26, 34), Vector3.new(cx + 8, 3, cz), pink, folder))
	for index, offset in { { -14, -8 }, { -4, 6 }, { 6, -10 }, { 14, 4 }, { 0, -2 } } do
		decor(Builder.ball("Fold" .. index, Vector3.new(9, 6, 9), Vector3.new(cx + offset[1], 14, cz + offset[2]), folds, folder))
	end
	-- a flat pad at the top (where the flag is stuck in the brain) and a ramp up to it
	solid(Builder.part("BrainPad", Vector3.new(18, 1, 18), Vector3.new(cx, top - 0.5, cz), Color3.fromRGB(215, 85, 140), folder))
	Builder.ramp("BrainRamp", Vector3.new(cx - 45, 0, cz), Vector3.new(cx - 9, top, cz), 10, Color3.fromRGB(205, 95, 140), folder)
	local spots = { { -24, 14 }, { 22, -18 }, { 18, 18 }, { -20, -18 }, { 28, 4 }, { -28, -4 } }
	for index, offset in spots do
		local emitter = Builder.emitter("Bubbles" .. index, Vector3.new(cx + offset[1], 0.6, cz + offset[2]), SPARKLES, Color3.fromRGB(120, 255, 90), folder)
		emitter.Rate = 6
		emitter.Lifetime = NumberRange.new(1, 2)
		emitter.Speed = NumberRange.new(2, 4)
		emitter.SpreadAngle = Vector2.new(15, 15)
		emitter.EmissionDirection = Enum.NormalId.Top
		emitter.Size = NumberSequence.new(1.6, 0)
		emitter.Transparency = NumberSequence.new(0.2, 1)
		emitter.LightEmission = 0.6
	end
	local tx, tz = cx + 30, cz - 26
	decor(Builder.part("DeadTreeTrunk", Vector3.new(2.5, 16, 2.5), Vector3.new(tx, 8, tz), Color3.fromRGB(80, 55, 35), folder))
	for index, tilt in { 35, -40, 20 } do
		local branch = Builder.part("DeadTreeBranch" .. index, Vector3.new(1, 8, 1), Vector3.new(tx, 12 + index * 1.5, tz), Color3.fromRGB(70, 48, 30), folder)
		branch.CFrame = CFrame.new(tx, 12 + index * 1.5, tz) * CFrame.Angles(math.rad(tilt), math.rad(index * 90), math.rad(tilt))
		branch.CanCollide = false
	end
end

-- ---------- Outer ring: Cooked Canyon. A giant frying pan with a fried egg over the lava river ----------
local function cookedCanyon(folder: Folder, territory: Territories.Territory)
	local cx, cz = territory.x, territory.z
	local top = territory.flags[1].y
	local red = Color3.fromRGB(175, 65, 40)
	-- the lava river runs north to south under the pan; red rock walls close in the canyon at both ends
	local lava = Builder.part("LavaRiver", Vector3.new(14, 0.4, 90), Vector3.new(cx + 18, 0.2, cz), Color3.fromRGB(255, 110, 20), folder)
	lava.Material = Enum.Material.Neon
	lava.CanCollide = false
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 120, 30)
	glow.Range = 35
	glow.Brightness = 2
	glow.Parent = lava
	solid(Builder.part("RockWallNorth", Vector3.new(70, 16, 6), Vector3.new(cx, 8, cz - 50), red, folder))
	solid(Builder.part("RockWallSouth", Vector3.new(70, 16, 6), Vector3.new(cx, 8, cz + 50), red, folder))
	-- the pan: a wide dark disc held up on rock pillars, with a long handle
	local iron = Color3.fromRGB(45, 45, 52)
	for index, offset in { { -16, -16 }, { 16, -16 }, { -16, 16 }, { 16, 16 } } do
		solid(Builder.part("PanLeg" .. index, Vector3.new(4, top - 1, 4), Vector3.new(cx + offset[1], (top - 1) / 2, cz + offset[2]), red, folder))
	end
	solid(Builder.cylinder("Pan", 56, 2, Vector3.new(cx, top - 1, cz), iron, folder))
	solid(Builder.part("PanHandle", Vector3.new(34, 2, 6), Vector3.new(cx + 42, top - 1, cz), Color3.fromRGB(70, 50, 40), folder))
	-- the fried egg: a wobbly white blob with a big yellow yolk in the middle, where the flag is
	decor(Builder.ball("EggWhite", Vector3.new(44, 3, 40), Vector3.new(cx - 2, top + 0.6, cz), Color3.new(1, 1, 1), folder))
	decor(Builder.ball("EggWhiteLobe", Vector3.new(24, 3, 24), Vector3.new(cx + 18, top + 0.6, cz + 12), Color3.new(1, 1, 1), folder))
	decor(Builder.ball("Yolk", Vector3.new(18, 9, 18), Vector3.new(cx, top + 3, cz), Color3.fromRGB(255, 205, 30), folder))
	for index, offset in { { -10, -8 }, { 6, 10 }, { 14, -6 } } do
		steam(folder, "Steam" .. index, Vector3.new(cx + offset[1], top + 5, cz + offset[2]))
	end
	Builder.ramp("PanRamp", Vector3.new(cx - 47, 0, cz), Vector3.new(cx - 22, top, cz), 10, red, folder)
end

local builders: { [string]: (Folder, Territories.Territory) -> () } = {
	gigachad_gate = gigachadGate,
	rizz_ravine = rizzRavine,
	locked_in_lighthouse = lighthouse,
	npc_village = npcVillage,
	brainrot_bog = brainrotBog,
	cooked_canyon = cookedCanyon,
}

-- Build the scenery and one name sign for every territory.
function TerritoryScenery.build()
	local root = Instance.new("Folder")
	root.Name = "TerritoryScenery"
	root.Parent = Workspace
	for _, territory in Territories.list do
		local folder = Instance.new("Folder")
		folder.Name = territory.id
		folder.Parent = root
		local build = builders[territory.id]
		if build then
			build(folder, territory)
		end
		applyMaterials(folder)
		-- one floating name sign per territory, coloured by tier, readable from across the map
		local top = 0
		for _, flag in territory.flags do
			top = math.max(top, flag.y)
		end
		local anchor = Builder.part("SignAnchor", Vector3.new(1, 1, 1), Vector3.new(territory.x, math.max(top + 24, 46), territory.z), Color3.new(1, 1, 1), folder)
		anchor.Transparency = 1
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		local tier = Territories.tiers[territory.tier]
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.new(0, 260, 0, 70)
		gui.MaxDistance = 450
		gui.AlwaysOnTop = false
		gui.Parent = anchor
		local panel = Instance.new("Frame")
		panel.Size = UDim2.new(1, 0, 1, 0)
		panel.BackgroundColor3 = TIER_COLORS[territory.tier] or Color3.new(1, 1, 1)
		panel.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 18)
		corner.Parent = panel
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.new(1, 1, 1)
		stroke.Thickness = 4
		stroke.Parent = panel
		local nameLabel = Instance.new("TextLabel")
		nameLabel.BackgroundTransparency = 1
		nameLabel.Size = UDim2.new(1, -12, 0.62, 0)
		nameLabel.Position = UDim2.new(0, 6, 0, 2)
		nameLabel.Font = Enum.Font.FredokaOne
		nameLabel.TextScaled = true
		nameLabel.TextColor3 = Color3.new(1, 1, 1)
		nameLabel.TextStrokeColor3 = Color3.fromRGB(35, 25, 60)
		nameLabel.TextStrokeTransparency = 0
		nameLabel.Text = territory.name
		nameLabel.Parent = panel
		local tierLabel = Instance.new("TextLabel")
		tierLabel.BackgroundTransparency = 1
		tierLabel.Size = UDim2.new(1, -12, 0.3, 0)
		tierLabel.Position = UDim2.new(0, 6, 0.66, 0)
		tierLabel.Font = Enum.Font.FredokaOne
		tierLabel.TextScaled = true
		tierLabel.TextColor3 = Color3.fromRGB(35, 25, 60)
		tierLabel.Text = ("%s  -  %d flag%s"):format(tier.label, #territory.flags, if #territory.flags == 1 then "" else "s")
		tierLabel.Parent = panel
	end
end

return TerritoryScenery
