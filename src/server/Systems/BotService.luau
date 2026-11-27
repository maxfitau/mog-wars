--!strict
-- Bots that fill a war. Server only. Bots are NOT Players: they never appear in Roblox's player list, never
-- count in player numbers, never earn points or boxes, and never appear on any ranking.
--  * When fewer than Config.bots.minFighters real players are fighting on War Island, the server adds ONE bot a
--    second until the war is full, spread across factions. As real players join, it removes ONE bot a second.
--  * Bots run between zones, stand in them (so they capture and push back like anyone else) and can be shoved.
--    When a bot meets a player in a zone they can start a mog-off; MogOffSystem makes the bot tap at a
--    human-like speed that depends on the player's rank (see BotRules).
--  * A "Mogling Jeff" style name tag floats above every Mogling (the fillers are called Moglings; the word "bot" is never shown).
-- CaptureSystem reads the bots through BotService.list(); it gives this module its zone list through
-- BotService.setZoneSource (so the two modules never require each other).

local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BotRules = require(Shared:WaitForChild("BotRules"))
local Config = require(Shared:WaitForChild("EconomyConfig"))
local FactionRules = require(Shared:WaitForChild("FactionRules"))
local Features = require(Shared:WaitForChild("Features"))
local MapLayout = require(Shared:WaitForChild("MapLayout"))

export type Bot = {
	id: number, -- negative, so it can never clash with a player's user id
	name: string,
	faction: number,
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	aura: number,
	penaltyUntil: number, -- pushes at reduced power until this server time (after a shove or a lost mog-off)
	target: BasePart?,
	route: { Waypoint }?, -- waypoints still to walk through on the way to the target
	routeIndex: number,
	thinkAt: number,
	moveAt: number,
	pathing: boolean, -- a pathfinding request is running
	dashAt: number, -- next time this Mogling may dash toward its flag
	holdUntil: number, -- combat (strafing, taking cover) drives the movement until this server time
}

export type Waypoint = { x: number, z: number, y: number, jump: boolean? }
export type ZoneView = {
	part: BasePart,
	x: number,
	z: number,
	y: number, -- how high the flag's ground is
	size: number,
	owner: number,
	value: number,
	route: { Waypoint }?, -- ramp waypoints to walk through to reach a raised flag
}

local NAMES = { "Jeff", "Brad", "Chadley", "Kevin", "Nova", "Zed", "Pixel", "Turbo", "Sprout", "Mango", "Pip", "Ziggy", "Bolt", "Ember", "Fuzz", "Gizmo" }

local BotService = {}

local bots: { Bot } = {}
local nextId = 0
local spawning = false
local zoneSource: (() -> { ZoneView })? = nil
local rng = Random.new()
local warnedModel = false

local function random(): number
	return rng:NextNumber()
end

function BotService.setZoneSource(source: () -> { ZoneView })
	zoneSource = source
end

function BotService.isAlive(bot: Bot): boolean
	return bot.model.Parent ~= nil and bot.humanoid.Health > 0 and bot.root.Parent ~= nil
end

-- All bots that are in the game and alive.
function BotService.list(): { Bot }
	local alive: { Bot } = {}
	for _, bot in bots do
		if BotService.isAlive(bot) then
			table.insert(alive, bot)
		end
	end
	return alive
end

-- A faction's home base position: the real SpawnLocation marked HomeBase if there is one, else the layout.
local function baseOf(faction: number): (number, number, number)
	for _, child in Workspace:GetChildren() do
		if child:IsA("SpawnLocation") and child:GetAttribute("HomeBase") == faction then
			return child.Position.X, child.Position.Z, child.Position.Y
		end
	end
	local fallback = MapLayout.bases[faction]
	return if fallback then fallback.x else 0, if fallback then fallback.z else 0, MapLayout.baseIslandHeight
end

local function baseSpot(faction: number, slot: number): Vector3
	local x, z, y = baseOf(faction)
	return Vector3.new(x + ((slot % 5) - 2) * 3, y + 4, z + 8)
end

local function humanStats(): (number, { [number]: number }, number, number)
	local humans = 0
	local perFaction: { [number]: number } = {}
	local rankSum = 0
	for _, player in Players:GetPlayers() do
		local faction = player:GetAttribute("Faction")
		if type(faction) == "number" and player:GetAttribute("Island") ~= "training" then
			humans += 1
			perFaction[faction] = (perFaction[faction] or 0) + 1
			local rank = player:GetAttribute("Rank")
			rankSum += if type(rank) == "number" then rank else 1
		end
	end
	return humans, perFaction, if humans > 0 then rankSum / humans else 1, #Players:GetPlayers()
end

-- A simple blocky body (R6 layout: Head, Torso, arms, legs, joints) built entirely from parts and Roblox's built-in head
-- shape: nothing is downloaded, so there is no avatar asset to fail to load.
local function buildBlockyBody(): Model
	local model = Instance.new("Model")
	local function part(name: string, size: Vector3, color: Color3): Part
		local item = Instance.new("Part")
		item.Name = name
		item.Size = size
		item.Color = color
		item.Material = Enum.Material.SmoothPlastic
		item.TopSurface = Enum.SurfaceType.Smooth
		item.BottomSurface = Enum.SurfaceType.Smooth
		item.Parent = model
		return item
	end
	local skin = Color3.fromRGB(205, 220, 190)
	local root = part("HumanoidRootPart", Vector3.new(2, 2, 1), skin)
	root.Transparency = 1
	local torso = part("Torso", Vector3.new(2, 2, 1), Color3.fromRGB(120, 130, 150))
	local head = part("Head", Vector3.new(2, 1, 1), skin)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	mesh.Parent = head
	local face = Instance.new("Decal")
	face.Name = "face"
	face.Texture = "rbxasset://textures/face.png"
	face.Face = Enum.NormalId.Front
	face.Parent = head
	local armR = part("Right Arm", Vector3.new(1, 2, 1), skin)
	local armL = part("Left Arm", Vector3.new(1, 2, 1), skin)
	local legR = part("Right Leg", Vector3.new(1, 2, 1), Color3.fromRGB(80, 70, 90))
	local legL = part("Left Leg", Vector3.new(1, 2, 1), Color3.fromRGB(80, 70, 90))
	local function joint(name: string, part0: Part, part1: Part, c0: CFrame, c1: CFrame)
		local motor = Instance.new("Motor6D")
		motor.Name = name
		motor.Part0 = part0
		motor.Part1 = part1
		motor.C0 = c0
		motor.C1 = c1
		motor.Parent = part0
	end
	local quarter = math.pi / 2
	joint("RootJoint", root, torso, CFrame.Angles(-quarter, 0, math.pi), CFrame.Angles(-quarter, 0, math.pi))
	joint("Neck", torso, head, CFrame.new(0, 1, 0), CFrame.new(0, -0.5, 0))
	joint("Right Shoulder", torso, armR, CFrame.new(1, 0.5, 0) * CFrame.Angles(0, quarter, 0), CFrame.new(-0.5, 0.5, 0) * CFrame.Angles(0, quarter, 0))
	joint("Left Shoulder", torso, armL, CFrame.new(-1, 0.5, 0) * CFrame.Angles(0, -quarter, 0), CFrame.new(0.5, 0.5, 0) * CFrame.Angles(0, -quarter, 0))
	joint("Right Hip", torso, legR, CFrame.new(1, -1, 0) * CFrame.Angles(0, quarter, 0), CFrame.new(0.5, 1, 0) * CFrame.Angles(0, quarter, 0))
	joint("Left Hip", torso, legL, CFrame.new(-1, -1, 0) * CFrame.Angles(0, -quarter, 0), CFrame.new(-0.5, 1, 0) * CFrame.Angles(0, -quarter, 0))
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.Parent = model
	model.PrimaryPart = root
	return model
end

-- Swing a Mogling's arms and legs while it walks (a simple procedural walk, no animation assets).
local function swingLimbs()
	local t = os.clock()
	for _, bot in bots do
		local torso = bot.model:FindFirstChild("Torso")
		if torso and bot.humanoid.Parent then
			local moving = bot.humanoid.MoveDirection.Magnitude > 0.1
			local swing = if moving then math.sin(t * 11) * 0.8 else 0
			local function set(name: string, angle: number)
				local motor = torso:FindFirstChild(name)
				if motor and motor:IsA("Motor6D") then
					motor.Transform = CFrame.Angles(0, 0, angle)
				end
			end
			set("Right Hip", swing)
			set("Left Hip", -swing)
			set("Right Shoulder", -swing)
			set("Left Shoulder", swing)
		end
	end
end

local function createModel(): Model?
	if Features.blockyMoglings then
		return buildBlockyBody()
	end
	local ok, result = pcall(function()
		return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	end)
	if ok and result then
		return result
	end
	if not warnedModel then
		warnedModel = true
		warn("[mog-wars] could not create a bot body: " .. tostring(result))
	end
	return nil
end

local function addTag(model: Model, faction: number, displayName: string)
	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		local gui = Instance.new("BillboardGui")
		gui.Name = "MoglingTag"
		gui.Size = UDim2.new(0, 130, 0, 24)
		gui.StudsOffset = Vector3.new(0, 3.4, 0) -- above the name that Roblox shows
		gui.MaxDistance = 60
		gui.Adornee = head
		gui.Parent = head
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundColor3 = Color3.fromRGB(35, 25, 60)
		label.BackgroundTransparency = 0.15
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.Text = displayName
		label.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = label
	end
	local info = FactionRules.byId(faction)
	if info then
		local highlight = Instance.new("Highlight")
		highlight.Name = "FactionOutline"
		highlight.FillColor = FactionRules.color(info)
		highlight.OutlineColor = FactionRules.color(info)
		highlight.FillTransparency = 0.75
		highlight.Parent = model
	end
end

local function spawnBot(faction: number)
	local model = createModel()
	if not model then
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		model:Destroy()
		return
	end
	nextId -= 1
	local name = NAMES[(-nextId - 1) % #NAMES + 1]
	model.Name = "Mogling_" .. name
	humanoid.DisplayName = "Mogling " .. name
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None -- our own name tag is shown instead
	humanoid.WalkSpeed = Config.bots.walkSpeed
	model:SetAttribute("IsBot", true)
	model:SetAttribute("Faction", faction)
	CollectionService:AddTag(model, "Bot")
	addTag(model, faction, "Mogling " .. name)
	local bodyTorso = model:FindFirstChild("Torso")
	local factionInfo = FactionRules.byId(faction)
	if Features.blockyMoglings and bodyTorso and bodyTorso:IsA("BasePart") and factionInfo then
		bodyTorso.Color = FactionRules.color(factionInfo) -- a Mogling wears its team colour
	end
	model:PivotTo(CFrame.new(baseSpot(faction, -nextId)))
	model.Parent = Workspace
	pcall(function()
		root:SetNetworkOwner(nil) -- the server drives the bot
	end)

	local bot: Bot = {
		id = nextId,
		name = name,
		faction = faction,
		model = model,
		humanoid = humanoid,
		root = root,
		aura = 1,
		penaltyUntil = 0,
		target = nil,
		route = nil,
		routeIndex = 0,
		thinkAt = 0,
		moveAt = 0,
		holdUntil = 0,
		dashAt = 0,
		pathing = false,
	}
	table.insert(bots, bot)
	humanoid.Died:Connect(function()
		task.delay(2, function()
			for index, existing in bots do
				if existing == bot then
					table.remove(bots, index)
					break
				end
			end
			model:Destroy()
		end)
	end)
end

local function removeBot(bot: Bot)
	for index, existing in bots do
		if existing == bot then
			table.remove(bots, index)
			break
		end
	end
	bot.model:Destroy()
end

-- Add or remove at most ONE bot. Called once a second.
local function manage()
	local humans, perFaction, averageRank = humanStats()
	local wanted = if Features.bots then BotRules.desiredBots(humans, Config.bots.minFighters) else 0
	local alive = BotService.list()

	local botCounts: { [number]: number } = {}
	local totals: { [number]: number } = {}
	for id = 1, FactionRules.count() do
		totals[id] = perFaction[id] or 0
	end
	for _, bot in alive do
		botCounts[bot.faction] = (botCounts[bot.faction] or 0) + 1
		totals[bot.faction] = (totals[bot.faction] or 0) + 1
	end

	if #alive > wanted then
		local faction = BotRules.factionForRemoval(botCounts, totals, FactionRules.count())
		for _, bot in alive do
			if bot.faction == faction then
				removeBot(bot)
				break
			end
		end
	elseif #alive < wanted and not spawning then
		spawning = true
		local faction = BotRules.factionForAdd(totals, FactionRules.count())
		task.spawn(function()
			spawnBot(faction)
			spawning = false
		end)
	end

	local aura = BotRules.aura(averageRank, Config.bots)
	for _, bot in alive do
		bot.aura = aura
	end
end

-- Ask Roblox's pathfinding for a walking route to a flag (stairs, doors, jumps and all) and store it as the bot's route.
-- It runs in the background; the bot heads straight for the flag until the route arrives.
local function computeRoute(bot: Bot, destination: Vector3)
	if bot.pathing then
		return
	end
	bot.pathing = true
	task.spawn(function()
		local path = PathfindingService:CreatePath({ AgentRadius = 2.5, AgentHeight = 5, AgentCanJump = true, WaypointSpacing = 6 })
		local ok = pcall(function()
			path:ComputeAsync(bot.root.Position, destination)
		end)
		if ok and path.Status == Enum.PathStatus.Success then
			local list: { Waypoint } = {}
			for _, waypoint in path:GetWaypoints() do
				table.insert(list, { x = waypoint.Position.X, z = waypoint.Position.Z, y = waypoint.Position.Y, jump = waypoint.Action == Enum.PathWaypointAction.Jump })
			end
			if #list > 1 then
				bot.route = list
				bot.routeIndex = 2 -- the first waypoint is where the bot already stands
				bot.moveAt = 0
			end
		end
		bot.pathing = false
	end)
end

local function jitteredPoint(zone: BasePart): Vector3
	local reach = zone.Size.X * 0.35
	return Vector3.new(zone.Position.X + (random() * 2 - 1) * reach, zone.Position.Y + 3, zone.Position.Z + (random() * 2 - 1) * reach)
end

-- Decide where each bot runs. Called a few times a second.
local function think()
	local now = Workspace:GetServerTimeNow()
	local warOn = Workspace:GetAttribute("WarPhase") == "War"
	local views = if zoneSource then zoneSource() else {}
	local flat: { BotRules.ZoneView } = {}
	for _, view in views do
		table.insert(flat, { x = view.x, z = view.z, owner = view.owner, value = view.value })
	end
	local assigned: { [number]: number } = {}
	for _, bot in bots do
		if bot.target then
			for index, view in views do
				if view.part == bot.target then
					assigned[index] = (assigned[index] or 0) + 1
				end
			end
		end
	end

	for _, bot in bots do
		if BotService.isAlive(bot) then
			if not warOn then
				if now >= bot.moveAt then
					bot.humanoid:MoveTo(baseSpot(bot.faction, -bot.id))
					bot.moveAt = now + 4
				end
			elseif bot.humanoid.WalkSpeed > 0 and now >= bot.holdUntil then -- (a stunned bot has walk speed 0)
				if now >= bot.thinkAt or not bot.target then
					local index = BotRules.chooseZone(bot.faction, bot.root.Position.X, bot.root.Position.Z, flat, assigned, random)
					if index and views[index] then
						local view = views[index]
						bot.target = view.part
						assigned[index] = (assigned[index] or 0) + 1
						bot.route = nil
						bot.routeIndex = 0
						computeRoute(bot, Vector3.new(view.x, view.y + 3, view.z)) -- stairs, tunnels and rooftops included
					end
					bot.thinkAt = now + 6 + random() * 6
					bot.moveAt = 0
				end
				local target = bot.target
				if target and Features.dash and now >= bot.dashAt then -- Moglings dash toward far flags now and then
					local gap = Vector3.new(target.Position.X - bot.root.Position.X, 0, target.Position.Z - bot.root.Position.Z)
					if gap.Magnitude > 35 then
						bot.root.AssemblyLinearVelocity = gap.Unit * 60 + Vector3.new(0, bot.root.AssemblyLinearVelocity.Y, 0)
						bot.dashAt = now + 5 + random() * 5
					else
						bot.dashAt = now + 2
					end
				end
				local route = bot.route
				if route and bot.routeIndex > 0 then
					-- walk the waypoints in order, moving on when close to the current one
					local waypoint = route[bot.routeIndex]
					local flatDistance = math.sqrt((bot.root.Position.X - waypoint.x) ^ 2 + (bot.root.Position.Z - waypoint.z) ^ 2)
					if flatDistance < 5 then
						bot.routeIndex += 1
						if bot.routeIndex > #route then
							bot.routeIndex = 0
							bot.route = nil
						end
						bot.moveAt = 0
					elseif now >= bot.moveAt then
						if waypoint.jump then
							bot.humanoid.Jump = true
						end
						bot.humanoid:MoveTo(Vector3.new(waypoint.x, waypoint.y, waypoint.z))
						bot.moveAt = now + 1.5
					end
				elseif target and now >= bot.moveAt then
					bot.humanoid:MoveTo(jitteredPoint(target))
					bot.moveAt = now + 2.5 + random() * 1.5
				end
			end
		end
	end
end

-- A new war: every bot goes back to its base to start fresh.
function BotService.onWarStart()
	for _, bot in bots do
		if BotService.isAlive(bot) then
			bot.target = nil
			bot.route = nil
			bot.routeIndex = 0
			bot.thinkAt = 0
			bot.moveAt = 0
			bot.model:PivotTo(CFrame.new(baseSpot(bot.faction, -bot.id)))
			bot.root.AssemblyLinearVelocity = Vector3.zero
		end
	end
end

-- Push a bot back (a shove or a lost mog-off).
function BotService.knockback(bot: Bot, dx: number, dz: number, studs: number)
	if BotService.isAlive(bot) and dx == dx and dz == dz then
		local speed = math.clamp(studs, 0, 30) * 3.5
		bot.root.AssemblyLinearVelocity = Vector3.new(dx * speed, 25, dz * speed)
	end
end

-- Freeze a bot for a moment.
function BotService.stun(bot: Bot, seconds: number)
	if not BotService.isAlive(bot) then
		return
	end
	bot.humanoid.WalkSpeed = 0
	task.delay(seconds, function()
		if bot.humanoid.Parent then
			bot.humanoid.WalkSpeed = Config.bots.walkSpeed
		end
	end)
end

-- The bot's push is weakened until `untilTime` (a server time).
function BotService.weaken(bot: Bot, untilTime: number)
	bot.penaltyUntil = math.max(bot.penaltyUntil, untilTime)
end

-- A mogged bot pops back at its base (its body is never destroyed, so the war stays full).
function BotService.respawn(bot: Bot, seconds: number)
	if not BotService.isAlive(bot) then
		return
	end
	bot.target = nil
	bot.route = nil
	bot.routeIndex = 0
	bot.thinkAt = 0
	bot.moveAt = 0
	bot.model:PivotTo(CFrame.new(baseSpot(bot.faction, -bot.id)))
	bot.root.AssemblyLinearVelocity = Vector3.zero
	BotService.stun(bot, seconds)
end

-- Combat takes over a bot's movement for a moment (strafe or cover).
function BotService.moveTo(bot: Bot, point: Vector3, seconds: number)
	bot.holdUntil = Workspace:GetServerTimeNow() + seconds
	bot.humanoid:MoveTo(point)
end

function BotService.byId(id: number): Bot?
	for _, bot in bots do
		if bot.id == id then
			return bot
		end
	end
	return nil
end

function BotService.init() end

function BotService.start()
	task.spawn(function()
		while true do
			task.wait(0.1)
			swingLimbs()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(Config.bots.manageSeconds)
			local ok, err = pcall(manage)
			if not ok then
				warn("[mog-wars] BotService.manage error: " .. tostring(err))
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(Config.bots.thinkSeconds)
			local ok, err = pcall(think)
			if not ok then
				warn("[mog-wars] BotService.think error: " .. tostring(err))
			end
		end
	end)
end

return BotService
