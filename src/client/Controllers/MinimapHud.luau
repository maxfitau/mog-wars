--!strict
-- THE MINIMAP. A small rounded map in the top-right corner (below the Roblox top bar; Roblox's own player list is hidden so they
-- do not overlap) showing the islands coloured by owner (white = neutral), flags, you (an arrow), teammates (dots), your
-- current mission flag (a pulsing ring), supply drops and the meteor. Tap it (phone) or press M (PC) to open a big map
-- with the territory names; tap or M again to close. You can keep moving while it is open. A "map control" bar on top shows
-- each team's share of the territories with a crown on the leader. Display only: it reads attributes and parts the server
-- already publishes.

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

local MinimapHud = {}

local player = Players.LocalPlayer
local HALF = MapLayout.baseplateSize / 2 + 40 -- world studs from the middle to the map's edge

type View = { frame: Frame, size: number, big: boolean, dots: { Frame }, update: () -> () }

local function factionColour(id: number): Color3
	local faction = FactionRules.factions[id]
	return if faction then Color3.fromRGB(table.unpack(faction.rgb)) else Color3.new(1, 1, 1)
end

-- Territory owners from the flags the server publishes.
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

local function round(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

local function makeView(parent: Instance, size: number, big: boolean): View
	local frame = Instance.new("Frame")
	frame.Name = if big then "BigMap" else "MiniMap"
	frame.Size = UDim2.fromOffset(size, size)
	frame.BackgroundColor3 = Color3.fromRGB(24, 34, 70)
	frame.BackgroundTransparency = 0.08
	frame.ClipsDescendants = true
	frame.Parent = parent
	round(frame, if big then 22 else 16)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 205, 60)
	stroke.Thickness = 2.5
	stroke.Parent = frame

	local function toMap(x: number, z: number): UDim2
		return UDim2.fromOffset((x + HALF) / (HALF * 2) * size, (z + HALF) / (HALF * 2) * size)
	end
	local function disc(name: string, x: number, z: number, radius: number, colour: Color3, transparency: number?): Frame
		local pixels = math.max(4, radius / (HALF * 2) * size * 2)
		local part = Instance.new("Frame")
		part.Name = name
		part.AnchorPoint = Vector2.new(0.5, 0.5)
		part.Size = UDim2.fromOffset(pixels, pixels)
		part.Position = toMap(x, z)
		part.BackgroundColor3 = colour
		part.BackgroundTransparency = transparency or 0
		part.BorderSizePixel = 0
		part.Parent = frame
		round(part, 999)
		return part
	end

	-- islands (they recolour with the owner) and the four team spawn islands
	local islandFrames: { [string]: Frame } = {}
	for index, base in MapLayout.bases do
		local spawn = disc("Spawn" .. index, base.x, base.z, MapLayout.baseIslandRadius, factionColour(index), 0.25)
		spawn.ZIndex = 1
	end
	for _, territory in Territories.list do
		if territory.radius > 0 then
			local island = disc(territory.id, territory.x, territory.z, territory.radius, Color3.new(1, 1, 1), 0.15)
			island.ZIndex = 2
			islandFrames[territory.id] = island
			if big then
				local label = Instance.new("TextLabel")
				label.AnchorPoint = Vector2.new(0.5, 0.5)
				label.Position = toMap(territory.x, territory.z + territory.radius * 0.62)
				label.Size = UDim2.fromOffset(150, 20)
				label.BackgroundTransparency = 1
				label.Font = Enum.Font.GothamBlack
				label.TextSize = 14
				label.TextColor3 = Color3.new(1, 1, 1)
				label.TextStrokeTransparency = 0.2
				label.Text = string.upper(territory.name)
				label.ZIndex = 9
				label.Parent = frame
			end
		else
			local cave = disc(territory.id, territory.x - 38, territory.z + 38, 22, Color3.new(1, 1, 1), 0.1) -- the cave, drawn beside the Gate
			cave.ZIndex = 3
			islandFrames[territory.id] = cave
			if big then
				local label = Instance.new("TextLabel")
				label.AnchorPoint = Vector2.new(0.5, 0.5)
				label.Position = toMap(territory.x - 38, territory.z + 70)
				label.Size = UDim2.fromOffset(150, 20)
				label.BackgroundTransparency = 1
				label.Font = Enum.Font.GothamBlack
				label.TextSize = 12
				label.TextColor3 = Color3.fromRGB(255, 220, 150)
				label.TextStrokeTransparency = 0.2
				label.Text = string.upper(territory.name)
				label.ZIndex = 9
				label.Parent = frame
			end
		end
		for _, flag in territory.flags do
			local dotSize = if big then 9 else 6
			local dot = Instance.new("Frame")
			dot.AnchorPoint = Vector2.new(0.5, 0.5)
			dot.Size = UDim2.fromOffset(dotSize, dotSize)
			dot.Position = toMap(flag.x, flag.z)
			dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			dot.BorderSizePixel = 0
			dot.Rotation = 45
			dot.ZIndex = 6
			dot.Parent = frame
			local flagStroke = Instance.new("UIStroke")
			flagStroke.Color = Color3.fromRGB(20, 20, 30)
			flagStroke.Thickness = 1.5
			flagStroke.Parent = dot
		end
	end

	-- the mission ring, the meteor, you and your team
	local ring = Instance.new("Frame")
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Size = UDim2.fromOffset(if big then 26 else 18, if big then 26 else 18)
	ring.BackgroundTransparency = 1
	ring.Visible = false
	ring.ZIndex = 8
	ring.Parent = frame
	round(ring, 999)
	local ringStroke = Instance.new("UIStroke")
	ringStroke.Color = Color3.fromRGB(255, 215, 60)
	ringStroke.Thickness = 3
	ringStroke.Parent = ring
	local function icon(text: string, colour: Color3): TextLabel
		local label = Instance.new("TextLabel")
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Size = UDim2.fromOffset(22, 22)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBlack
		label.TextSize = if big then 22 else 16
		label.Text = text
		label.TextColor3 = colour
		label.TextStrokeTransparency = 0
		label.ZIndex = 10
		label.Visible = false
		label.Parent = frame
		return label
	end
	local meteorIcon = icon("☄", Color3.fromRGB(215, 140, 255))
	local arrow = icon("▲", Color3.new(1, 1, 1))
	arrow.ZIndex = 12
	local crateIcons: { TextLabel } = {}
	for index = 1, 4 do
		crateIcons[index] = icon("▣", Color3.fromRGB(90, 220, 230))
	end
	local mates: { Frame } = {}
	for index = 1, 15 do
		local mate = Instance.new("Frame")
		mate.AnchorPoint = Vector2.new(0.5, 0.5)
		mate.Size = UDim2.fromOffset(if big then 8 else 5, if big then 8 else 5)
		mate.BorderSizePixel = 0
		mate.ZIndex = 7
		mate.Visible = false
		mate.Parent = frame
		round(mate, 999)
		mates[index] = mate
	end

	local view: View = { frame = frame, size = size, big = big, dots = {}, update = function() end }
	view.update = function()
		local ownerOf = owners()
		for id, island in islandFrames do
			local owner = ownerOf[id] or 0
			island.BackgroundColor3 = if owner ~= 0 then factionColour(owner) else Color3.new(1, 1, 1)
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
			ring.Size = UDim2.fromOffset((if big then 26 else 18) + 4 * math.sin(os.clock() * 6), (if big then 26 else 18) + 4 * math.sin(os.clock() * 6))
		end
		local eventPos = Workspace:GetAttribute("EventPos")
		meteorIcon.Visible = typeof(eventPos) == "Vector3" and Workspace:GetAttribute("EventName") == "meteor"
		if typeof(eventPos) == "Vector3" then
			meteorIcon.Position = toMap(eventPos.X, eventPos.Z)
		end
		local used = 0
		for _, child in Workspace:GetChildren() do
			if child:IsA("Model") and (child.Name == "SupplyCrate" or child.Name == "GoldSupplyCrate") and used < #crateIcons then
				local crate = child:FindFirstChild("Crate")
				if crate and crate:IsA("BasePart") then
					used += 1
					local label = crateIcons[used]
					label.Visible = true
					label.Position = toMap(crate.Position.X, crate.Position.Z)
					label.TextColor3 = if child.Name == "GoldSupplyCrate" then Color3.fromRGB(255, 205, 50) else Color3.fromRGB(90, 220, 230)
				end
			end
		end
		for index = used + 1, #crateIcons do
			crateIcons[index].Visible = false
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

-- The "map control" bar: each team's share of the territories as a coloured split bar, with a crown over the leader.
local function makeBar(parent: Instance, width: number): () -> ()
	local holder = Instance.new("Frame")
	holder.Name = "MapControl"
	holder.Size = UDim2.fromOffset(width, 16)
	holder.BackgroundColor3 = Color3.fromRGB(235, 235, 240)
	holder.BorderSizePixel = 0
	holder.ClipsDescendants = true
	holder.Parent = parent
	round(holder, 8)
	local segments: { Frame } = {}
	for faction = 1, FactionRules.count() do
		local segment = Instance.new("Frame")
		segment.BackgroundColor3 = factionColour(faction)
		segment.BorderSizePixel = 0
		segment.Size = UDim2.new(0, 0, 1, 0)
		segment.Parent = holder
		segments[faction] = segment
	end
	local crown = Instance.new("TextLabel")
	crown.Size = UDim2.fromOffset(20, 16)
	crown.AnchorPoint = Vector2.new(0.5, 1)
	crown.BackgroundTransparency = 1
	crown.Text = "♛"
	crown.TextSize = 16
	crown.TextColor3 = Color3.fromRGB(255, 215, 60)
	crown.Font = Enum.Font.GothamBlack
	crown.TextStrokeTransparency = 0
	crown.Visible = false
	crown.Parent = parent
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
			segments[faction].Size = UDim2.fromOffset(share * width, 16)
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
			crown.Position = UDim2.new(0, before + (counts[best] or 0) / math.max(total, 1) * width / 2, 0, -2)
		end
	end
end

function MinimapHud.init()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false) -- the minimap lives where the player list would be
	end)
	local gui = Instance.new("ScreenGui")
	gui.Name = "MinimapHud"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 8
	gui.Parent = player:WaitForChild("PlayerGui")

	local small = Instance.new("Frame") -- the corner widget: bar on top, map below
	small.Name = "Corner"
	small.AnchorPoint = Vector2.new(1, 0)
	small.Position = UDim2.new(1, -12, 0, 64)
	small.Size = UDim2.fromOffset(170, 196)
	small.BackgroundTransparency = 1
	small.Parent = gui
	local smallBarHolder = Instance.new("Frame")
	smallBarHolder.Size = UDim2.fromOffset(170, 22)
	smallBarHolder.Position = UDim2.fromOffset(0, 12)
	smallBarHolder.BackgroundTransparency = 1
	smallBarHolder.Parent = small
	local updateSmallBar = makeBar(smallBarHolder, 170)
	local smallView = makeView(small, 170, false)
	smallView.frame.Position = UDim2.fromOffset(0, 26)

	local big = Instance.new("Frame") -- the expanded map
	big.Name = "Expanded"
	big.AnchorPoint = Vector2.new(0.5, 0.5)
	big.Position = UDim2.fromScale(0.5, 0.52)
	big.Size = UDim2.fromOffset(560, 600)
	big.BackgroundTransparency = 1
	big.Visible = false
	big.Parent = gui
	local bigBarHolder = Instance.new("Frame")
	bigBarHolder.Size = UDim2.fromOffset(560, 28)
	bigBarHolder.Position = UDim2.fromOffset(0, 22)
	bigBarHolder.BackgroundTransparency = 1
	bigBarHolder.Parent = big
	local updateBigBar = makeBar(bigBarHolder, 560)
	local bigTitle = Instance.new("TextLabel")
	bigTitle.Size = UDim2.fromOffset(560, 20)
	bigTitle.BackgroundTransparency = 1
	bigTitle.Text = "MAP CONTROL  -  press M or tap to close"
	bigTitle.Font = Enum.Font.GothamBlack
	bigTitle.TextSize = 13
	bigTitle.TextColor3 = Color3.new(1, 1, 1)
	bigTitle.TextStrokeTransparency = 0.3
	bigTitle.Position = UDim2.fromOffset(0, 54)
	bigTitle.Parent = big
	local bigView = makeView(big, 540, true)
	bigView.frame.Position = UDim2.fromOffset(10, 56)
	bigView.frame.Position = UDim2.fromOffset(10, 78)
	big.Size = UDim2.fromOffset(560, 640)

	local function toggle()
		big.Visible = not big.Visible
	end
	-- tap the little map (phone) or press M (PC); neither blocks movement
	for _, view in { smallView, bigView } do
		local tap = Instance.new("TextButton")
		tap.Size = UDim2.fromScale(1, 1)
		tap.BackgroundTransparency = 1
		tap.Text = ""
		tap.ZIndex = 20
		tap.Parent = view.frame
		tap.Activated:Connect(toggle)
	end
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.M then
			toggle()
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
