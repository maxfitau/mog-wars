--!strict
-- THE MINIMAP, drawn only with shapes (no text glyphs that could render as blank squares). Top-right under the mission bar's row, up to
-- 260 px, rounded with a gold border:
--   each territory is an island blob filled with the owner's colour (white = neutral) and a ring in its tier colour
--   (gold / diamond blue / ultra purple); the four team spawn islands are team-coloured squares in the corners; flags are white
--   diamonds; you are a white arrow pointing where you face; teammates are small dots; your mission territory has a pulsing dashed
--   yellow ring; the meteor and supply drops are small drawn icons.
-- A "map control" bar above it splits each team's share of the territories, with a drawn crown over the leader. Tap the map or press M
-- to open a big centred map with the names under each island (and Chud Chambers marked under Gigachad Gate); you can keep moving.
-- Two small toggles under it switch the music and the sound effects. Display only.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Territories = require(Shared:WaitForChild("Territories"))
local FactionRules = require(Shared:WaitForChild("FactionRules"))
local MapLayout = require(Shared:WaitForChild("MapLayout"))
local SoundController = require(script.Parent:WaitForChild("SoundController"))

local MinimapHud = {}

local player = Players.LocalPlayer
local HALF = MapLayout.baseplateSize / 2 + 40

local NAVY = Color3.fromRGB(34, 36, 66)
local BORDER = Color3.fromRGB(255, 205, 60)
local NEUTRAL = Color3.fromRGB(232, 232, 238)
local TIER = { gold = Color3.fromRGB(255, 200, 60), diamond = Color3.fromRGB(90, 175, 255), ultra = Color3.fromRGB(185, 95, 255) }

type View = { frame: Frame, update: () -> () }

local function factionColour(id: number): Color3
	local faction = FactionRules.factions[id]
	return if faction then FactionRules.color(faction) else NEUTRAL
end

local function owners(): { [string]: number }
	local result: { [string]: number } = {}
	for _, zone in CollectionService:GetTagged("Zone") do
		local id = zone:GetAttribute("Territory")
		local owner = zone:GetAttribute("TerritoryOwner")
		if type(id) == "string" and result[id] == nil then
			result[id] = if type(owner) == "number" then owner else 0
		end
	end
	return result
end

local function rounded(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

local function box(parent: Instance, size: Vector2, colour: Color3, z: number?): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Size = UDim2.fromOffset(size.X, size.Y)
	f.BackgroundColor3 = colour
	f.BorderSizePixel = 0
	f.ZIndex = z or 1
	f.Parent = parent
	return f
end

local function outline(frame: GuiObject, colour: Color3, thickness: number)
	local stroke = Instance.new("UIStroke")
	stroke.Color = colour
	stroke.Thickness = thickness
	stroke.Parent = frame
	return stroke
end

local function makeView(parent: Instance, size: number, big: boolean): View
	local frame = Instance.new("Frame")
	frame.Name = if big then "BigMap" else "MiniMap"
	frame.Size = UDim2.fromOffset(size, size)
	frame.BackgroundColor3 = NAVY
	frame.BorderSizePixel = 0
	frame.ClipsDescendants = true
	frame.Parent = parent
	rounded(frame, if big then 26 else 22)
	outline(frame, BORDER, if big then 4 else 3)

	local function toMap(x: number, z: number): UDim2
		return UDim2.fromOffset((x + HALF) / (HALF * 2) * size, (z + HALF) / (HALF * 2) * size)
	end
	local function pixels(studs: number): number
		return studs / (HALF * 2) * size
	end
	local function disc(x: number, z: number, radiusStuds: number, colour: Color3, z_: number): Frame
		local d = math.max(5, pixels(radiusStuds) * 2)
		local f = box(frame, Vector2.new(d, d), colour, z_)
		f.Position = toMap(x, z)
		rounded(f, 999)
		return f
	end

	-- the four team spawn islands: team-coloured rounded squares in the corners
	for index, base in MapLayout.bases do
		local side = math.max(8, pixels(MapLayout.baseIslandRadius) * 2 * 0.9)
		local square = box(frame, Vector2.new(side, side), factionColour(index), 1)
		square.Position = toMap(base.x, base.z)
		rounded(square, math.floor(side * 0.3))
		square.BackgroundTransparency = 0.05
	end

	-- territories: an island blob (a main disc and two lobes) in the owner's colour, with a ring in the tier colour
	local blobs: { [string]: { Frame } } = {}
	local caveMarkers: { [string]: Frame } = {}
	for _, territory in Territories.list do
		if territory.radius > 0 then
			local parts: { Frame } = {}
			local lobeA = disc(territory.x + territory.radius * 0.55, territory.z - territory.radius * 0.3, territory.radius * 0.55, NEUTRAL, 2)
			local lobeB = disc(territory.x - territory.radius * 0.5, territory.z + territory.radius * 0.38, territory.radius * 0.5, NEUTRAL, 2)
			local main = disc(territory.x, territory.z, territory.radius * 0.85, NEUTRAL, 3)
			outline(main, TIER[territory.tier] or BORDER, if big then 4 else 3)
			parts = { main, lobeA, lobeB }
			blobs[territory.id] = parts
			if big then
				local label = Instance.new("TextLabel")
				label.AnchorPoint = Vector2.new(0.5, 0)
				label.Position = toMap(territory.x, territory.z + territory.radius * 0.95)
				label.Size = UDim2.fromOffset(150, 16)
				label.BackgroundTransparency = 1
				label.Font = Enum.Font.GothamBlack
				label.TextSize = 13
				label.TextColor3 = Color3.new(1, 1, 1)
				label.TextStrokeTransparency = 0.2
				label.Text = string.upper(territory.name)
				label.ZIndex = 9
				label.Parent = frame
			end
		else
			-- the cave under the Gate: a small dark arch beside it
			local arch = box(frame, Vector2.new(math.max(9, pixels(34)), math.max(9, pixels(26))), NEUTRAL, 4)
			arch.Position = toMap(territory.x + 20, territory.z + 52)
			rounded(arch, 999)
			outline(arch, TIER[territory.tier] or BORDER, 2)
			caveMarkers[territory.id] = arch
			if big then
				local label = Instance.new("TextLabel")
				label.AnchorPoint = Vector2.new(0.5, 0)
				label.Position = toMap(territory.x + 20, territory.z + 52 + 20)
				label.Size = UDim2.fromOffset(150, 14)
				label.BackgroundTransparency = 1
				label.Font = Enum.Font.GothamBlack
				label.TextSize = 11
				label.TextColor3 = Color3.fromRGB(255, 225, 160)
				label.TextStrokeTransparency = 0.2
				label.Text = string.upper(territory.name)
				label.ZIndex = 9
				label.Parent = frame
			end
		end
		for _, flag in territory.flags do
			local dot = box(frame, Vector2.new(if big then 9 else 6, if big then 9 else 6), Color3.new(1, 1, 1), 6)
			dot.Position = toMap(flag.x, flag.z)
			dot.Rotation = 45
			outline(dot, Color3.fromRGB(25, 25, 40), 1.5)
		end
	end

	-- the mission ring: twelve yellow dashes round the territory, turning and pulsing
	local ring = Instance.new("Frame")
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.BackgroundTransparency = 1
	ring.Size = UDim2.fromOffset(if big then 54 else 38, if big then 54 else 38)
	ring.ZIndex = 8
	ring.Visible = false
	ring.Parent = frame
	for index = 1, 12 do
		local angle = (index - 0.5) / 12 * math.pi * 2
		local dash = Instance.new("Frame")
		dash.AnchorPoint = Vector2.new(0.5, 0.5)
		dash.Size = UDim2.fromOffset(if big then 7 else 5, 3)
		dash.Position = UDim2.fromScale(0.5 + 0.5 * math.cos(angle), 0.5 + 0.5 * math.sin(angle))
		dash.Rotation = math.deg(angle) + 90
		dash.BackgroundColor3 = Color3.fromRGB(255, 220, 70)
		dash.BorderSizePixel = 0
		dash.ZIndex = 8
		dash.Parent = ring
	end

	-- the meteor: a purple ball with an orange tail
	local meteor = Instance.new("Frame")
	meteor.AnchorPoint = Vector2.new(0.5, 0.5)
	meteor.Size = UDim2.fromOffset(18, 18)
	meteor.BackgroundTransparency = 1
	meteor.ZIndex = 10
	meteor.Visible = false
	meteor.Parent = frame
	local tail = box(meteor, Vector2.new(12, 4), Color3.fromRGB(255, 150, 60), 10)
	tail.Position = UDim2.fromScale(0.25, 0.7)
	tail.Rotation = 35
	local ball = box(meteor, Vector2.new(10, 10), Color3.fromRGB(190, 100, 255), 11)
	ball.Position = UDim2.fromScale(0.65, 0.35)
	rounded(ball, 999)
	outline(ball, Color3.new(1, 1, 1), 1.5)

	-- you: a white arrow (a round body and a pointed tip) that turns with the camera
	local arrow = Instance.new("Frame")
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.Size = UDim2.fromOffset(if big then 22 else 16, if big then 22 else 16)
	arrow.BackgroundTransparency = 1
	arrow.ZIndex = 12
	arrow.Visible = false
	arrow.Parent = frame
	local tip = box(arrow, Vector2.new(9, 9), Color3.new(1, 1, 1), 12)
	tip.Position = UDim2.fromScale(0.5, 0.2)
	tip.Rotation = 45
	outline(tip, Color3.fromRGB(25, 25, 40), 1.2)
	local body = box(arrow, Vector2.new(10, 10), Color3.new(1, 1, 1), 13)
	body.Position = UDim2.fromScale(0.5, 0.62)
	rounded(body, 999)
	outline(body, Color3.fromRGB(25, 25, 40), 1.2)

	-- supply drops: a small crate (square with a cross), gold for a gold drop
	local crates: { { holder: Frame, square: Frame } } = {}
	for index = 1, 4 do
		local holder = Instance.new("Frame")
		holder.AnchorPoint = Vector2.new(0.5, 0.5)
		holder.Size = UDim2.fromOffset(12, 12)
		holder.BackgroundTransparency = 1
		holder.ZIndex = 10
		holder.Visible = false
		holder.Parent = frame
		local square = box(holder, Vector2.new(10, 10), Color3.fromRGB(90, 220, 230), 10)
		square.Position = UDim2.fromScale(0.5, 0.5)
		outline(square, Color3.fromRGB(25, 25, 40), 1.2)
		local crossH = box(square, Vector2.new(10, 2), Color3.fromRGB(25, 25, 40), 11)
		crossH.Position = UDim2.fromScale(0.5, 0.5)
		local crossV = box(square, Vector2.new(2, 10), Color3.fromRGB(25, 25, 40), 11)
		crossV.Position = UDim2.fromScale(0.5, 0.5)
		crates[index] = { holder = holder, square = square }
	end
	local mates: { Frame } = {}
	for index = 1, 15 do
		local mate = box(frame, Vector2.new(if big then 8 else 5, if big then 8 else 5), NEUTRAL, 7)
		mate.Visible = false
		rounded(mate, 999)
		outline(mate, Color3.new(1, 1, 1), 1)
		mates[index] = mate
	end

	local view: View = { frame = frame, update = function() end }
	view.update = function()
		local ownerOf = owners()
		for id, parts in blobs do
			local owner = ownerOf[id] or 0
			local colour = if owner ~= 0 then factionColour(owner) else NEUTRAL
			for _, piece in parts do
				piece.BackgroundColor3 = colour
			end
		end
		for id, marker in caveMarkers do
			local owner = ownerOf[id] or 0
			marker.BackgroundColor3 = if owner ~= 0 then factionColour(owner) else NEUTRAL
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			arrow.Visible = true
			arrow.Position = toMap(root.Position.X, root.Position.Z)
			local camera = Workspace.CurrentCamera
			if camera then
				arrow.Rotation = math.deg(math.atan2(camera.CFrame.LookVector.X, -camera.CFrame.LookVector.Z))
			end
		else
			arrow.Visible = false
		end
		local mission = player:GetAttribute("MissionPos")
		ring.Visible = typeof(mission) == "Vector3"
		if typeof(mission) == "Vector3" then
			ring.Position = toMap(mission.X, mission.Z)
			local base = if big then 54 else 38
			local pulse = base + 6 * math.sin(os.clock() * 6)
			ring.Size = UDim2.fromOffset(pulse, pulse)
			ring.Rotation = os.clock() * 30 % 360
		end
		local eventPos = Workspace:GetAttribute("EventPos")
		meteor.Visible = typeof(eventPos) == "Vector3" and Workspace:GetAttribute("EventName") == "meteor"
		if typeof(eventPos) == "Vector3" then
			meteor.Position = toMap(eventPos.X, eventPos.Z)
		end
		local used = 0
		for _, child in Workspace:GetChildren() do
			if child:IsA("Model") and (child.Name == "SupplyCrate" or child.Name == "GoldSupplyCrate") and used < #crates then
				local crate = child:FindFirstChild("Crate")
				if crate and crate:IsA("BasePart") then
					used += 1
					crates[used].holder.Visible = true
					crates[used].holder.Position = toMap(crate.Position.X, crate.Position.Z)
					crates[used].square.BackgroundColor3 = if child.Name == "GoldSupplyCrate" then Color3.fromRGB(255, 205, 50) else Color3.fromRGB(90, 220, 230)
				end
			end
		end
		for index = used + 1, #crates do
			crates[index].holder.Visible = false
		end
		local myFaction = player:GetAttribute("Faction")
		local shown = 0
		for _, other in Players:GetPlayers() do
			local theirRoot = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
			if other ~= player and other:GetAttribute("Faction") == myFaction and theirRoot and theirRoot:IsA("BasePart") and shown < #mates then
				shown += 1
				mates[shown].Visible = true
				mates[shown].Position = toMap(theirRoot.Position.X, theirRoot.Position.Z)
				mates[shown].BackgroundColor3 = factionColour(if type(myFaction) == "number" then myFaction else 0)
			end
		end
		for index = shown + 1, #mates do
			mates[index].Visible = false
		end
	end
	return view
end

-- The map-control bar: each team's share of the territories, with a drawn crown over the leader.
local function makeBar(parent: Instance, width: number): () -> ()
	local holder = Instance.new("Frame")
	holder.Name = "MapControl"
	holder.Size = UDim2.fromOffset(width, 14)
	holder.Position = UDim2.fromOffset(0, 8)
	holder.BackgroundColor3 = NEUTRAL
	holder.BorderSizePixel = 0
	holder.ClipsDescendants = true
	holder.Parent = parent
	rounded(holder, 7)
	local segments: { Frame } = {}
	for faction = 1, FactionRules.count() do
		local segment = Instance.new("Frame")
		segment.BackgroundColor3 = factionColour(faction)
		segment.BorderSizePixel = 0
		segment.Size = UDim2.new(0, 0, 1, 0)
		segment.Parent = holder
		segments[faction] = segment
	end
	local crown = Instance.new("Frame") -- a drawn crown: a gold band and three points
	crown.Size = UDim2.fromOffset(16, 10)
	crown.AnchorPoint = Vector2.new(0.5, 1)
	crown.BackgroundTransparency = 1
	crown.Visible = false
	crown.ZIndex = 5
	crown.Parent = parent
	local gold = Color3.fromRGB(255, 205, 60)
	local band = box(crown, Vector2.new(14, 4), gold, 5)
	band.Position = UDim2.fromScale(0.5, 0.85)
	for index = -1, 1 do
		local point = box(crown, Vector2.new(5, 5), gold, 5)
		point.Position = UDim2.fromScale(0.5 + index * 0.3, 0.25)
		point.Rotation = 45
	end
	return function()
		local counts: { [number]: number } = {}
		local total = 0
		for _, owner in owners() do
			total += 1
			if owner ~= 0 then
				counts[owner] = (counts[owner] or 0) + 1
			end
		end
		local best, bestCount = 0, 0
		local x = 0
		for faction = 1, FactionRules.count() do
			local share = if total > 0 then (counts[faction] or 0) / total else 0
			segments[faction].Position = UDim2.fromOffset(x, 0)
			segments[faction].Size = UDim2.fromOffset(share * width, 14)
			x += share * width
			if (counts[faction] or 0) > bestCount then
				best, bestCount = faction, counts[faction] or 0
			end
		end
		crown.Visible = best ~= 0
		if best ~= 0 then
			local before = 0
			for faction = 1, best - 1 do
				before += (counts[faction] or 0) / math.max(total, 1) * width
			end
			crown.Position = UDim2.new(0, 8 + math.max(0, before + (counts[best] or 0) / math.max(total, 1) * width / 2 - 8), 0, 8)
		end
	end
end

-- a small on/off toggle (drawn: a pill with a coloured light), for music and sound effects
local function toggle(parent: Instance, text: string, position: UDim2, get: () -> boolean, set: (boolean) -> ())
	local button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(60, 18)
	button.Position = position
	button.BackgroundColor3 = NAVY
	button.Font = Enum.Font.GothamBlack
	button.TextSize = 10
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Text = "      " .. text
	button.Parent = parent
	rounded(button, 9)
	outline(button, BORDER, 1.5)
	local light = box(button, Vector2.new(8, 8), Color3.fromRGB(110, 230, 120), 2)
	light.Position = UDim2.new(0, 11, 0.5, 0)
	rounded(light, 999)
	button.Activated:Connect(function()
		set(not get())
		light.BackgroundColor3 = if get() then Color3.fromRGB(110, 230, 120) else Color3.fromRGB(230, 90, 90)
	end)
end

function MinimapHud.init()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false) -- the minimap lives where the player list would be
	end)
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local S = math.clamp(math.min(260, viewport.X * 0.31, viewport.Y - 230), 130, 260)
	local gui = Instance.new("ScreenGui")
	gui.Name = "MinimapHud"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 8
	gui.Parent = player:WaitForChild("PlayerGui")

	local small = Instance.new("Frame")
	small.Name = "Corner"
	small.AnchorPoint = Vector2.new(1, 0)
	small.Position = UDim2.new(1, -12, 0, 112) -- below the top-centre block and level with the mission bar's row, never under it
	small.Size = UDim2.fromOffset(S, S + 70)
	small.BackgroundTransparency = 1
	small.Parent = gui
	local updateSmallBar = makeBar(small, S)
	local smallView = makeView(small, S, false)
	smallView.frame.Position = UDim2.fromOffset(0, 26)
	local hint = Instance.new("TextLabel")
	hint.Position = UDim2.fromOffset(0, 28 + S)
	hint.Size = UDim2.fromOffset(S, 14)
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.GothamBold
	hint.TextSize = 11
	hint.TextColor3 = Color3.new(1, 1, 1)
	hint.TextStrokeTransparency = 0.4
	hint.Text = "M - tap to expand"
	hint.Parent = small
	toggle(small, "MUSIC", UDim2.fromOffset(0, 44 + S), SoundController.isMusicOn, SoundController.setMusic)
	toggle(small, "SFX", UDim2.fromOffset(66, 44 + S), SoundController.isSfxOn, SoundController.setSfx)

	local bigSize = math.clamp(math.min(540, viewport.X - 40, viewport.Y - 120), 260, 540)
	local big = Instance.new("Frame")
	big.Name = "Expanded"
	big.AnchorPoint = Vector2.new(0.5, 0.5)
	big.Position = UDim2.fromScale(0.5, 0.54)
	big.Size = UDim2.fromOffset(bigSize, bigSize + 40)
	big.BackgroundTransparency = 1
	big.Visible = false
	big.Parent = gui
	local updateBigBar = makeBar(big, bigSize)
	local bigView = makeView(big, bigSize, true)
	bigView.frame.Position = UDim2.fromOffset(0, 30)

	local function flip()
		big.Visible = not big.Visible
	end
	for _, view in { smallView, bigView } do
		local tap = Instance.new("TextButton")
		tap.Size = UDim2.fromScale(1, 1)
		tap.BackgroundTransparency = 1
		tap.Text = ""
		tap.ZIndex = 20
		tap.Parent = view.frame
		tap.Activated:Connect(flip)
	end
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.M then
			flip()
		end
	end)

	local since = 0
	RunService.Heartbeat:Connect(function(dt)
		since += dt
		if since < 0.1 then
			return
		end
		since = 0
		smallView.update()
		updateSmallBar()
		if big.Visible then
			bigView.update()
			updateBigBar()
		end
	end)
end

function MinimapHud.start() end

return MinimapHud
