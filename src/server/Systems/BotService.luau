--!strict
-- Bots that fill a war. Server only. Bots are NOT Players: they never appear in Roblox's player list, never
-- count in player numbers, never earn points or boxes, and never appear on any ranking.
--  * When fewer than Config.bots.minFighters real players are fighting on War Island, the server adds ONE bot a
--    second until the war is full, spread across factions. As real players join, it removes ONE bot a second.
--  * Bots run between zones, stand in them (so they capture and push back like anyone else) and can be shoved.
--    When a bot meets a player in a zone they can start a mog-off; MogOffSystem makes the bot tap at a
--    human-like speed that depends on the player's rank (see BotRules).
--  * A small "BOT" tag floats above every bot.
-- CaptureSystem reads the bots through BotService.list(); it gives this module its zone list through
-- BotService.setZoneSource (so the two modules never require each other).

local CollectionService = game:GetService("CollectionService")
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
	thinkAt: number,
	moveAt: number,
}

export type ZoneView = { part: BasePart, x: number, z: number, size: number, owner: number, value: number }

local NAMES = { "Rex", "Blaze", "Nova", "Zed", "Kodo", "Pixel", "Turbo", "Sprout", "Echo", "Mango", "Pip", "Ziggy", "Bolt", "Ember", "Fuzz", "Gizmo" }

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
local function baseOf(faction: number): (number, number)
	for _, child in Workspace:GetChildren() do
		if child:IsA("SpawnLocation") and child:GetAttribute("HomeBase") == faction then
			return child.Position.X, child.Position.Z
		end
	end
	local fallback = MapLayout.bases[faction]
	return if fallback then fallback.x else 0, if fallback then fallback.z else 0
end

local function baseSpot(faction: number, slot: number): Vector3
	local x, z = baseOf(faction)
	return Vector3.new(x + ((slot % 5) - 2) * 3, 4, z + 8)
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

local function createModel(): Model?
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

local function addTag(model: Model, faction: number)
	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		local gui = Instance.new("BillboardGui")
		gui.Name = "BotTag"
		gui.Size = UDim2.new(0, 56, 0, 22)
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
		label.Text = "BOT"
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
	model.Name = "Bot_" .. name
	humanoid.DisplayName = name
	humanoid.WalkSpeed = Config.bots.walkSpeed
	model:SetAttribute("IsBot", true)
	model:SetAttribute("Faction", faction)
	CollectionService:AddTag(model, "Bot")
	addTag(model, faction)
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
		thinkAt = 0,
		moveAt = 0,
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

local function jitteredPoint(zone: BasePart): Vector3
	local reach = zone.Size.X * 0.35
	return Vector3.new(zone.Position.X + (random() * 2 - 1) * reach, 4, zone.Position.Z + (random() * 2 - 1) * reach)
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
			elseif bot.humanoid.WalkSpeed > 0 then -- (a stunned bot has walk speed 0)
				if now >= bot.thinkAt or not bot.target then
					local index = BotRules.chooseZone(bot.faction, bot.root.Position.X, bot.root.Position.Z, flat, assigned, random)
					if index and views[index] then
						bot.target = views[index].part
						assigned[index] = (assigned[index] or 0) + 1
					end
					bot.thinkAt = now + 6 + random() * 6
					bot.moveAt = 0
				end
				local target = bot.target
				if target and now >= bot.moveAt then
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
