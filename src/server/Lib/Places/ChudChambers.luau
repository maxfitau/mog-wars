--!strict
-- Chud Chambers (Diamond): a cave hanging UNDER the Gigachad Gate island. A great hall with a giant grumpy stone face
-- carved into the north wall (glowing eyes, scowl, a beard of hanging roots, an occasional "..." bubble) leads to two
-- chambers: the Snack Hoard (a mountain of crisp packets and cans, flag 1 on top) and the Gamer Throne (a glowing chair
-- facing a wall of screens, flag 2 behind the throne). Entrances: spiral stairs and a drop from the castle courtyard,
-- and a rope ladder from the island's edge (a walkway then leads in through a north tunnel).
-- Moment (every ~2 minutes): the torches flicker, the face groans "bro...", and a gentle wind pushes players toward the exits.
-- Secret: a narrow tunnel behind a snack pile with a small Aura Stash. Two cave-dweller NPCs wander about.
-- Look: dim warm torchlight and glowing mushrooms, to contrast with the bright sky above. Everything is built relative to
-- the cave floor (the territory's height), carved out of the Gate island's rock.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ambience = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Ambience"))
local AmbientNpc = require(script.Parent.Parent:WaitForChild("AmbientNpc"))
local Common = require(script.Parent:WaitForChild("Common"))
local Kit = require(script.Parent.Parent:WaitForChild("Kit"))
local TerrainKit = require(script.Parent.Parent:WaitForChild("TerrainKit"))
local MovementSystem = require(script.Parent.Parent.Parent:WaitForChild("Systems"):WaitForChild("MovementSystem"))

local STONE = Color3.fromRGB(128, 122, 134)
local DARK = Color3.fromRGB(80, 76, 88)
local WOOD = Color3.fromRGB(120, 84, 52)
local METAL = Color3.fromRGB(58, 58, 70)
local FLAME = Color3.fromRGB(255, 160, 70)
local SNACK_COLORS = { Color3.fromRGB(215, 60, 60), Color3.fromRGB(240, 200, 60), Color3.fromRGB(70, 120, 220), Color3.fromRGB(240, 140, 50) }

local function tilt(part: Part, rx: number, ry: number, rz: number)
	part.CFrame = CFrame.new(part.Position) * CFrame.Angles(rx, ry, rz)
end

return function(folder: Folder, territory: any)
	local k = Kit.new(folder, territory.x, territory.z, territory.height)
	local rng = Random.new(404)

	-- carve the cave out of the island's rock: the hall, two chambers with tunnels, the entry shaft and a north tunnel
	TerrainKit.carve(0, 0, 4, 80, 30, 88) -- hall
	TerrainKit.carve(-68, 0, 0, 32, 24, 56) -- Snack Hoard
	TerrainKit.carve(68, 0, 0, 32, 24, 56) -- Gamer Throne
	TerrainKit.carve(-48, 0, 0, 16, 12, 16)
	TerrainKit.carve(48, 0, 0, 16, 12, 16)
	TerrainKit.carve(-26, 0, 42, 12, 72, 12) -- the shaft up to the castle courtyard
	TerrainKit.carve(28, 0, -70, 8, 12, 60) -- the north tunnel out to the rope ladder
	TerrainKit.carve(-68, 0, -36, 4, 8, 16) -- the secret tunnel ...
	TerrainKit.carve(-68, 0, -48, 8, 8, 8) -- ... and its little room

	-- entrance 1: spiral stairs down the courtyard shaft (with an open hole in the middle to drop through)
	k:spiral("ChudStair", -26, 42, 3, 5.4, 0, 70, 5, 0, 1, Color3.fromRGB(150, 110, 70), Enum.Material.WoodPlanks)
	for _, side in { -1, 1 } do
		k:box("HatchFrame", -26, 70, 42 + side * 6.6, 14, 0.8, 1.2, WOOD, Enum.Material.WoodPlanks, { collide = false })
		k:box("HatchFrame", -26 + side * 6.6, 70, 42, 1.2, 0.8, 14, WOOD, Enum.Material.WoodPlanks, { collide = false })
	end
	k:lift("ChudChute", { { -26, 71, 42 }, { -26, 1, 42 } }, true) -- the DROP CHUTE: a gentle bubble ride down the shaft
	local door = k:box("HatchDoor", -26, 72, 35, 11, 0.6, 6, WOOD, Enum.Material.WoodPlanks, { collide = false })
	tilt(door, math.rad(-72), 0, 0)
	-- entrance 2: a rope ladder from the island's edge down to a walkway, and the walkway to the north tunnel
	k:box("LadderWalk", 28, -1, -114, 6, 1, 40, Color3.fromRGB(150, 105, 62), Enum.Material.WoodPlanks)
	k:truss("RopeLadder", 28, 0, -132, 72, 28, -126, 1)
	k:box("LadderTopPlank", 28, 69, -128, 6, 1, 8, Color3.fromRGB(150, 105, 62), Enum.Material.WoodPlanks)
	for _, side in { -1, 1 } do
		k:box("LadderRope", 28 + side * 1.6, 0, -132, 0.3, 72, 0.3, Color3.fromRGB(235, 220, 190), Enum.Material.Fabric, { collide = false })
	end

	-- THE FACE on the north wall: a giant, grumpy, cartoon stone face
	k:box("FaceSlab", 0, 2, -37, 56, 26, 6, STONE, Enum.Material.Slate, { cover = true })
	local browL = k:box("BrowL", -11, 21, -33.5, 20, 3.4, 3.5, DARK, Enum.Material.Slate, { collide = false })
	local browR = k:box("BrowR", 11, 21, -33.5, 20, 3.4, 3.5, DARK, Enum.Material.Slate, { collide = false })
	tilt(browL, 0, 0, math.rad(-20)) -- a scowl: the brows slope down toward the nose
	tilt(browR, 0, 0, math.rad(20))
	local eyeLights: { PointLight } = {}
	for _, side in { -1, 1 } do
		local eye = k:ball("Eye", side * 10, 14, -34, 9, 6, 2.5, Color3.fromRGB(255, 150, 40), Enum.Material.Neon, { collide = false })
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(255, 150, 60)
		glow.Range = 26
		glow.Brightness = 1.4
		glow.Parent = eye
		table.insert(eyeLights, glow)
		k:ball("Pupil", side * 10, 15, -32.6, 3, 3, 1, Color3.fromRGB(25, 15, 15), Enum.Material.SmoothPlastic, { collide = false })
	end
	k:box("Nose", 0, 9, -33, 6, 11, 5, STONE, Enum.Material.Slate, { collide = false })
	k:box("Mouth", 0, 6.5, -33.6, 16, 1.8, 2, Color3.fromRGB(25, 15, 20), Enum.Material.Slate, { collide = false })
	local lipL = k:box("MouthCorner", -9.5, 5.6, -33.6, 5, 1.6, 2, Color3.fromRGB(25, 15, 20), Enum.Material.Slate, { collide = false })
	local lipR = k:box("MouthCorner", 9.5, 5.6, -33.6, 5, 1.6, 2, Color3.fromRGB(25, 15, 20), Enum.Material.Slate, { collide = false })
	tilt(lipL, 0, 0, math.rad(35)) -- the corners turn down: a frown
	tilt(lipR, 0, 0, math.rad(-35))
	for index = -9, 9 do
		local length = 5 + (math.abs(index) * 7) % 4
		k:box("BeardRoot", index * 2.5, 6.5 - length, -34, 0.8, length, 0.8, Color3.fromRGB(88, 62, 40), Enum.Material.Wood, { collide = false }) -- a beard of hanging roots
	end
	local voice = k:box("FaceVoice", 0, 24, -31, 1, 1, 1, STONE, nil, { collide = false, transparency = 1 })
	local bubble = Instance.new("BillboardGui")
	bubble.Size = UDim2.new(0, 220, 0, 56)
	bubble.StudsOffset = Vector3.new(0, 2, 0)
	bubble.MaxDistance = 90
	bubble.Enabled = false
	bubble.Adornee = voice
	bubble.Parent = voice
	local bubbleLabel = Instance.new("TextLabel")
	bubbleLabel.Size = UDim2.new(1, 0, 1, 0)
	bubbleLabel.BackgroundColor3 = Color3.new(1, 1, 1)
	bubbleLabel.Font = Enum.Font.FredokaOne
	bubbleLabel.TextScaled = true
	bubbleLabel.TextColor3 = Color3.fromRGB(35, 25, 60)
	bubbleLabel.Text = "..."
	bubbleLabel.Parent = bubble
	local bubbleCorner = Instance.new("UICorner")
	bubbleCorner.CornerRadius = UDim.new(0, 16)
	bubbleCorner.Parent = bubbleLabel

	-- torches (their lights flicker in the moment) and glowing mushrooms: dim, warm and a little strange
	local torchLights: { PointLight } = {}
	local torchSpots = {
		{ -39, -20 }, { -39, 16 }, { 39, -20 }, { 39, 16 }, { -34, -38.5 }, { 14, -38.5 }, { -20, 46 }, { 20, 46 },
		{ -50, -22 }, { -50, 22 }, { 50, -22 }, { 50, 22 }, { -82, -20 }, { -82, 20 }, { 82, -26 }, { 82, 26 },
	}
	for _, spot in torchSpots do
		k:box("TorchBracket", spot[1], 6, spot[2], 0.6, 3, 0.6, WOOD, Enum.Material.Wood, { collide = false })
		local flame = k:ball("TorchFlame", spot[1], 8.6, spot[2], 1.8, 2.4, 1.8, FLAME, Enum.Material.Neon, { collide = false })
		local light = Instance.new("PointLight")
		light.Color = FLAME
		light.Range = 24
		light.Brightness = 1.3
		light.Parent = flame
		table.insert(torchLights, light)
	end
	for index = 1, 18 do
		local x = (rng:NextNumber() * 2 - 1) * 82
		local z = (rng:NextNumber() * 2 - 1) * 44
		local colour = if index % 2 == 0 then Color3.fromRGB(80, 235, 230) else Color3.fromRGB(255, 120, 220)
		k:cyl("MushroomStem", x, 0, z, 0.8, 2, Color3.fromRGB(230, 225, 210), Enum.Material.SmoothPlastic, { collide = false })
		local cap = k:ball("MushroomCap", x, 1.6, z, 3.2, 2, 3.2, colour, Enum.Material.Neon, { collide = false })
		local glow = Instance.new("PointLight")
		glow.Color = colour
		glow.Range = 10
		glow.Brightness = 0.7
		glow.Parent = cap
	end
	for index = 1, 14 do
		local length = 4 + rng:NextNumber() * 6
		k:box("Stalactite", (rng:NextNumber() * 2 - 1) * 36, 30 - length, (rng:NextNumber() * 2 - 1) * 36, 2.4, length, 2.4, DARK, Enum.Material.Rock, { collide = false })
		if index % 3 == 0 then
			k:box("HangingRoot", (rng:NextNumber() * 2 - 1) * 34, 30 - length * 1.3, (rng:NextNumber() * 2 - 1) * 34, 0.7, length * 1.3, 0.7, Color3.fromRGB(88, 62, 40), Enum.Material.Wood, { collide = false })
		end
	end

	-- SNACK HOARD: a mountain of crisp packets and cans, flag on top. Layers are 1.2 studs high, so you can walk up it.
	for layer = 0, 7 do
		local colour = SNACK_COLORS[layer % 4 + 1]
		k:cyl("SnackLayer", -68, layer * 1.2, 0, 28 - 3 * layer, 1.2, colour, if layer % 2 == 0 then Enum.Material.Metal else Enum.Material.Foil)
	end
	for index = 1, 36 do
		local angle = rng:NextNumber() * math.pi * 2
		local layer = rng:NextInteger(0, 6)
		local reach = (28 - 3 * layer) / 2 * (0.3 + rng:NextNumber() * 0.65)
		local top = (layer + 1) * 1.2
		local colour = SNACK_COLORS[rng:NextInteger(1, 4)]
		if index % 2 == 0 then
			k:cyl("Can", -68 + math.cos(angle) * reach, top, math.sin(angle) * reach, 1.4, 2.4, colour, Enum.Material.Metal, { collide = false })
		else
			k:box("CrispPacket", -68 + math.cos(angle) * reach, top, math.sin(angle) * reach, 2.4, 0.5, 3.2, colour, Enum.Material.Foil, { collide = false, rotY = angle })
		end
	end
	for _, pile in { { -80, -14 }, { -80, 14 }, { -56, 22 }, { -56, -22 } } do
		k:box("SnackPile", pile[1], 0, pile[2], 7, 4.5, 5, SNACK_COLORS[rng:NextInteger(1, 4)], Enum.Material.Foil, { cover = true, rotY = rng:NextNumber() })
	end
	k:box("MiniFridge", -81, 0, 22, 4, 7, 4, Color3.fromRGB(235, 235, 240), Enum.Material.Metal, { cover = true })
	k:box("SecretPile", -74, 0, -25, 8, 6, 4, SNACK_COLORS[1], Enum.Material.Foil, { cover = true }) -- hides the secret tunnel's mouth, just to its side
	Common.stash(folder, k:at(-68, 0, -48), territory.id)

	-- GAMER THRONE: a glowing chair facing a wall of screens; the flag is behind the throne
	k:box("ScreenBacking", 83, 2, 0, 1, 16, 34, METAL, Enum.Material.Metal)
	local palette = { Color3.fromRGB(60, 140, 255), Color3.fromRGB(180, 90, 255), Color3.fromRGB(70, 230, 150), Color3.fromRGB(255, 90, 120), Color3.fromRGB(240, 240, 255) }
	for column = 0, 5 do
		for row = 0, 2 do
			k:box("Screen", 82.2, 4 + row * 3.8, -12.5 + column * 5, 0.5, 3.2, 4.4, palette[(column + row) % #palette + 1], Enum.Material.Neon, { collide = false })
		end
	end
	k:box("ThroneBase", 70, 0, 0, 7, 1.5, 7, METAL, Enum.Material.Metal)
	k:box("ThroneSeat", 70, 1.5, 0, 6, 1.2, 6, Color3.fromRGB(35, 35, 48), Enum.Material.Fabric)
	k:box("ThroneBack", 66.8, 1.5, 0, 1.4, 10, 6.6, Color3.fromRGB(35, 35, 48), Enum.Material.Fabric)
	k:box("ThroneArm", 70, 2.7, -3.4, 5, 1.6, 0.9, METAL, Enum.Material.Metal)
	k:box("ThroneArm", 70, 2.7, 3.4, 5, 1.6, 0.9, METAL, Enum.Material.Metal)
	local trim = k:box("ThroneGlow", 66.1, 1.5, 0, 0.4, 10, 6.8, Color3.fromRGB(70, 230, 255), Enum.Material.Neon, { collide = false })
	local trimLight = Instance.new("PointLight")
	trimLight.Color = Color3.fromRGB(70, 230, 255)
	trimLight.Range = 30
	trimLight.Brightness = 1.6
	trimLight.Parent = trim
	k:box("Desk", 77, 0, 0, 3, 3.4, 16, Color3.fromRGB(70, 52, 40), Enum.Material.Wood, { cover = true })
	k:box("Keyboard", 76, 3.4, 0, 1.4, 0.3, 5, Color3.fromRGB(70, 230, 150), Enum.Material.Neon, { collide = false })
	for index, z in { -12, -8, 8, 12 } do
		k:cyl("EnergyCan", 77, 3.4, z, 1.2, 2.2, SNACK_COLORS[index], Enum.Material.Metal, { collide = false })
	end
	for _, z in { -14, 14 } do
		k:ball("Beanbag", 60, 0, z, 6, 3.6, 6, Color3.fromRGB(150, 90, 200), Enum.Material.Fabric, { cover = true })
	end
	for index, z in { -9, -3, 3, 9 } do
		k:box("Cable", 74, 0.05, z, 16, 0.3, 0.3, palette[index], Enum.Material.Neon, { collide = false })
	end

	-- two cave dwellers who think this is normal
	AmbientNpc.spawn(folder, k:at(-22, 0, 14), {
		lines = { "touch grass? never heard of it", "it's not a phase", "bro is NOT mewing", "...", "do not look at the face" },
		waypoints = { k:at(-22, 0, 14), k:at(-10, 0, 26), k:at(14, 0, 18), k:at(-30, 0, -10) },
		speed = 3.5,
	})
	AmbientNpc.spawn(folder, k:at(-56, 0, 6), {
		lines = { "it's not a phase", "one more snack and I'm out", "that flag is lowkey mid", "...", "gamer throne is taken, sorry" },
		waypoints = { k:at(-56, 0, 6), k:at(-48, 0, -4), k:at(-60, 0, 18) },
		speed = 3,
	})

	-- the moment, every ~2 minutes: torches flicker, the face groans "bro...", and a gentle wind pushes players to the exits
	task.spawn(function()
		while folder.Parent do
			task.wait(115 + math.random() * 10)
			bubbleLabel.Text = "bro..."
			bubble.Enabled = true
			local exits = { k:at(-26, 70, 42), k:at(28, 0, -96) }
			for _ = 1, 20 do
				for _, light in torchLights do
					light.Brightness = 0.2 + math.random() * 1.5
				end
				for _, glow in eyeLights do
					glow.Brightness = 0.6 + math.random() * 1.6
				end
				for _, player in Players:GetPlayers() do
					local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
					if root and root:IsA("BasePart") then
						local p = root.Position
						local inside = math.abs(p.X - territory.x) < 92 and p.Z - territory.z > -60 and p.Z - territory.z < 52 and p.Y > territory.height - 2 and p.Y < territory.height + 32
						if inside then
							local nearest = exits[1]
							for _, exit in exits do
								if (exit - p).Magnitude < (nearest - p).Magnitude then
									nearest = exit
								end
							end
							local flat = Vector3.new(nearest.X - p.X, 0, nearest.Z - p.Z)
							if flat.Magnitude > 2 then
								MovementSystem.push(player, flat.Unit * 7)
							end
						end
					end
				end
				task.wait(0.3)
			end
			for _, light in torchLights do
				light.Brightness = 1.3
			end
			bubble.Enabled = false
			bubbleLabel.Text = "..."
		end
	end)
	-- now and then the face just says "..."
	task.spawn(function()
		while folder.Parent do
			task.wait(22 + math.random() * 20)
			if not bubble.Enabled then
				bubbleLabel.Text = "..."
				bubble.Enabled = true
				task.wait(3)
				bubble.Enabled = false
			end
		end
	end)

	Common.ambience(folder, k:at(0, 8, 0), Ambience.chud_chambers, 0.4)
end
