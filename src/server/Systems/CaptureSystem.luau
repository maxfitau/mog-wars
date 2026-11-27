--!strict
-- Slice 1 capture system. The server alone decides who is standing in a zone and how full the bar is.
-- There are NO remotes here: clients cannot ask for, or change, anything about a zone.
-- Zones are any parts tagged "Zone". Presence is counted per faction (set by FactionSystem).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CaptureBar = require(Shared:WaitForChild("CaptureBar"))
local Config = require(Shared:WaitForChild("EconomyConfig"))
local FactionRules = require(Shared:WaitForChild("FactionRules"))
local ContributionScoring = require(Shared:WaitForChild("ContributionScoring"))
local TrainingRules = require(Shared:WaitForChild("TrainingRules"))
local SpawnRules = require(Shared:WaitForChild("SpawnRules"))
local Features = require(Shared:WaitForChild("Features"))
local Pace = require(Shared:WaitForChild("Pace"))
local SquadRules = require(Shared:WaitForChild("SquadRules"))
local ShoveRules = require(Shared:WaitForChild("ShoveRules"))
local UnitRules = require(Shared:WaitForChild("UnitRules"))
local WarRules = require(Shared:WaitForChild("WarRules"))
local ZoneGeometry = require(Shared:WaitForChild("ZoneGeometry"))
local BotRules = require(Shared:WaitForChild("BotRules"))
local Territories = require(Shared:WaitForChild("Territories"))
local TerritoryRules = require(Shared:WaitForChild("TerritoryRules"))
local BotService = require(script.Parent:WaitForChild("BotService"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local FriendService = require(script.Parent:WaitForChild("FriendService"))
local PopupSystem = require(script.Parent:WaitForChild("PopupSystem"))
local SeasonService = require(script.Parent:WaitForChild("SeasonService"))
local Stats = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("Stats"))

local HEADROOM = 8 -- studs above the zone that still count as standing in it
local UNOWNED_COLOR = Color3.fromRGB(0, 235, 255) -- bright glowing cyan: nobody owns it yet
local PUSH_COLOR = Color3.fromRGB(255, 235, 40) -- turns bright yellow as it fills

-- A territory groups one or more flags. A faction owns it only when it holds ALL of its flags. Contributions are
-- gathered per territory (across all its flags) and paid when a faction completes it.
type TerritoryState = {
	id: string,
	name: string,
	tier: string,
	owner: number, -- 0 until one faction holds every flag
	contribs: { [number]: { faction: number, units: number } }, -- by user id
	flags: { ZoneRecord },
}

type ZoneRecord = {
	part: BasePart,
	state: CaptureBar.State,
	shownProgress: number,
	territory: TerritoryState,
	height: number, -- how high the flag's ground is (raised flags are skipped for spawning)
	noSpawn: boolean, -- never spawn players beside this flag
	boosts: { [number]: number }, -- tank boost per faction in this zone (set by UnitSystem)
	beacon: BasePart?, -- the tall glowing pillar over the zone, recoloured with it
	light: PointLight?,
	ring: BasePart?, -- the round capture circle: outline, and the fill that grows like a pie
	fill: BasePart?,
	cloth: BasePart?, -- the flag cloth, in the owner's colour
	diameter: number,
}

local zones: { [BasePart]: ZoneRecord } = {}
local territories: { [string]: TerritoryState } = {}
local accumulator = 0
local active = true -- zones only move during a war
local warUnits: { [number]: number } = {} -- contribution per user id this war
local warCaptures: { [number]: number } = {} -- captures per faction this war

local tickClock = 0 -- counts up to one second for the "+1" aura ticks
local tierParams: { [string]: CaptureBar.Params } = {}

local params: CaptureBar.Params = {
	secondsForOneAura = Config.capture.secondsForOneAura,
	decayPerSecond = Config.capture.decayPerSecond,
}

local CaptureSystem = {}

local function register(instance: Instance)
	if not instance:IsA("BasePart") or zones[instance] then
		return
	end
	-- Find (or create) the territory this flag belongs to. A part without territory attributes is its own
	-- one-flag Gold territory, so a hand-made map still works.
	local territoryId = instance:GetAttribute("Territory")
	if type(territoryId) ~= "string" then
		territoryId = instance.Name
	end
	local territory = territories[territoryId]
	if not territory then
		local info = Territories.byId[territoryId]
		territory = {
			id = territoryId,
			name = if info then info.name else territoryId,
			tier = if info then info.tier else "gold",
			owner = 0,
			contribs = {},
			flags = {},
		}
		territories[territoryId] = territory
	end
	local flagIndex = instance:GetAttribute("FlagIndex")
	local info = Territories.byId[territoryId]
	local flagInfo = if info and type(flagIndex) == "number" then info.flags[flagIndex] else nil
	zones[instance] = {
		part = instance,
		state = CaptureBar.newState(),
		shownProgress = -1,
		territory = territory,
		height = if flagInfo then flagInfo.y else 0,
		noSpawn = if flagInfo then flagInfo.noSpawn == true else false,
		boosts = {},
		beacon = instance:FindFirstChild("Beacon") :: BasePart?,
		light = instance:FindFirstChildOfClass("PointLight"),
		ring = instance:FindFirstChild("Ring") :: BasePart?,
		fill = instance:FindFirstChild("Fill") :: BasePart?,
		cloth = instance:FindFirstChild("Cloth") :: BasePart?,
		diameter = if flagInfo then flagInfo.size * 0.9 else 16,
	}
	table.insert(territory.flags, zones[instance])
	instance:SetAttribute("TerritoryOwner", 0)
	instance:SetAttribute("OwnerFaction", 0)
	instance:SetAttribute("Progress", 0)
	instance:SetAttribute("CapturerFaction", 0)
	if instance:GetAttribute("Value") == nil then
		instance:SetAttribute("Value", 1)
	end
end

local function unregister(instance: Instance)
	if instance:IsA("BasePart") then
		local record = zones[instance]
		zones[instance] = nil
		if record then
			local list = record.territory.flags
			local at = table.find(list, record)
			if at then
				table.remove(list, at)
			end
		end
	end
end

-- Aura power per faction of everyone alive and standing in the zone. Aura grows with training; a recent shove
-- or mog-off loss weakens it for a few seconds.
local function powersInZone(zone: BasePart): ({ [number]: number }, { [number]: { Player } }, { BotService.Bot })
	local powers: { [number]: number } = {}
	local members: { [number]: { Player } } = {}
	local botsHere: { BotService.Bot } = {}
	local now = Workspace:GetServerTimeNow()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local faction = player:GetAttribute("Faction")
		if type(faction) == "number" and FactionRules.byId(faction) and humanoid and root and root:IsA("BasePart") and humanoid.Health > 0 then
			local offset = zone.CFrame:PointToObjectSpace(root.Position)
			if ZoneGeometry.contains(offset.X, offset.Y, offset.Z, zone.Size.X, zone.Size.Y, zone.Size.Z, HEADROOM) then
				local penaltyUntil = player:GetAttribute("PushPenaltyUntil")
				local weight = ShoveRules.powerMultiplier(now, if type(penaltyUntil) == "number" then penaltyUntil else 0, Config.shove)
				local level = player:GetAttribute("TrainingLevel")
				local aura = TrainingRules.auraMultiplier(if type(level) == "number" then level else 0, Config.training)
				powers[faction] = (powers[faction] or 0) + weight * aura
				members[faction] = members[faction] or {}
				table.insert(members[faction], player)
			end
		end
	end
	-- Bots push like anyone else, but they are never paid and never counted as contributors.
	for _, bot in BotService.list() do
		local offset = zone.CFrame:PointToObjectSpace(bot.root.Position)
		if ZoneGeometry.contains(offset.X, offset.Y, offset.Z, zone.Size.X, zone.Size.Y, zone.Size.Z, HEADROOM) then
			local weight = ShoveRules.powerMultiplier(now, bot.penaltyUntil, Config.shove)
			powers[bot.faction] = (powers[bot.faction] or 0) + weight * bot.aura
			table.insert(botsHere, bot)
		end
	end
	return powers, members, botsHere
end

local function ownerColor(owner: number): Color3
	local faction = FactionRules.byId(owner)
	return if faction then FactionRules.color(faction) else UNOWNED_COLOR
end

local function setZoneColor(record: ZoneRecord, color: Color3)
	record.part.Color = color
	if record.beacon then
		record.beacon.Color = color
	end
	if record.light then
		record.light.Color = color
	end
end

local WHITE = Color3.new(1, 1, 1)

-- The look of one flag: white ring when neutral, faction ring when owned, a fill that grows from the middle in the
-- capturing faction's colour, a cloth flag in the owner's colour, and a thin beam only while neutral or contested.
local function restyle(record: ZoneRecord)
	local state = record.state
	local ownerTint = if state.owner ~= 0 then ownerColor(state.owner) else WHITE
	if record.ring then
		record.ring.Color = ownerTint
	end
	if record.cloth then
		record.cloth.Color = ownerTint
	end
	local fill = record.fill
	if fill then
		local progress = math.clamp(state.progress, 0, 1)
		if progress > 0.01 and state.capturer ~= 0 then
			local d = math.max(0.1, record.diameter * progress)
			fill.Size = Vector3.new(0.3, d, d)
			fill.Color = ownerColor(state.capturer)
			fill.Transparency = 0.15
		elseif state.owner ~= 0 then
			fill.Size = Vector3.new(0.3, record.diameter, record.diameter)
			fill.Color = ownerTint
			fill.Transparency = 0.55
		else
			fill.Transparency = 1
		end
	end
	if record.beacon then
		local contested = record.part:GetAttribute("Contested") == true
		local show = contested or state.owner == 0
		record.beacon.Transparency = if show then 0.45 else 1
		record.beacon.Color = if state.capturer ~= 0 then ownerColor(state.capturer) elseif state.owner ~= 0 then ownerTint else WHITE
	end
end

local function show(record: ZoneRecord)
	local state = record.state
	restyle(record)
	-- Round so attributes only replicate when the bar visibly moves.
	local rounded = math.floor(state.progress * 100 + 0.5) / 100
	if rounded ~= record.shownProgress then
		record.shownProgress = rounded
		record.part:SetAttribute("Progress", rounded)
		record.part:SetAttribute("CapturerFaction", state.capturer)
		if state.owner ~= 0 then
			setZoneColor(record, ownerColor(state.owner))
		else
			setZoneColor(record, UNOWNED_COLOR:Lerp(PUSH_COLOR, rounded))
		end
	end
	if record.part:GetAttribute("CapturerFaction") ~= state.capturer then
		record.part:SetAttribute("CapturerFaction", state.capturer)
	end
	if record.part:GetAttribute("OwnerFaction") ~= state.owner then
		record.part:SetAttribute("OwnerFaction", state.owner)
		setZoneColor(record, if state.owner ~= 0 then ownerColor(state.owner) else UNOWNED_COLOR)
	end
end

-- How many real players are fighting on a faction (bots never count).
local function humansOn(faction: number): number
	local count = 0
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("Faction") == faction and player:GetAttribute("Island") ~= "training" then
			count += 1
		end
	end
	return count
end

-- Pay out a captured TERRITORY (the capturing faction now holds all its flags). Everyone who helped, by
-- contribution, gets a share of the Mog Points pool, the territory's aura reward and a box of its tier.
-- Taking it from a faction that has no real players (only bots) pays fewer Mog Points.
local function payOut(territory: TerritoryState, winner: number, factorOwner: number)
	local tier = Territories.tiers[territory.tier]
	local factor = BotRules.capturePoolFactor(factorOwner, humansOn(factorOwner), Config.bots)
	local pool = math.floor(Config.capture.basePool * tier.value * factor)
	local units: { [number]: number } = {}
	for userId, entry in territory.contribs do
		if entry.faction == winner then
			units[userId] = entry.units
		end
	end
	local payouts = ContributionScoring.split(pool, units, {
		minContribution = Config.capture.minContribution,
		minAward = Config.capture.minAward,
	})
	-- Work out each paid player's points first (the daily reward multiplier applies), then the squad bonus:
	-- friends on the same faction who were paid for this capture each add a little to a player's own points.
	local finalAmounts: { [number]: number } = {}
	local present: { [number]: Player } = {}
	local members: { SquadRules.Member } = {}
	for userId, amount in payouts do
		local player = Players:GetPlayerByUserId(userId) -- a player who left before payout loses that share
		if player then
			present[userId] = player
			finalAmounts[userId] = WarRules.applyMultiplier(amount, DataService.rewardMultiplier(player))
			table.insert(members, { id = userId, faction = winner })
		end
	end
	local friendCounts = SquadRules.friendCounts(members, function(a: number, b: number)
		local playerA, playerB = present[a], present[b]
		return Features.squadBonus and playerA ~= nil and playerB ~= nil and FriendService.areFriends(playerA, playerB)
	end)
	for userId, player in present do
		local bonus = SquadRules.bonusPoints(finalAmounts[userId], friendCounts[userId] or 0, Config.squad)
		local points = finalAmounts[userId] + bonus
		DataService.addPoints(player, points)
		PopupSystem.send(player, "points", points, "")
		local aura = DataService.addAura(player, tier.aura)
		if aura > 0 then
			Stats.add(player, "aura", aura)
			PopupSystem.send(player, "aura", aura, "")
		end
		if DataService.earnBox(player, tier.box) then -- every paid contributor also earns a box, up to the daily cap
			PopupSystem.send(player, "box", 1, tier.box)
		end
		SeasonService.earn(player, "capture", tier.value)
		DataService.recordCapture(player)
	end
	for userId, entry in territory.contribs do
		if entry.faction == winner then
			territory.contribs[userId] = nil -- paid; other factions' contributions stay
		end
	end
end

-- Recompute who owns a territory from its flags and publish it on each flag (for the HUD).
local function refreshTerritory(territory: TerritoryState): number
	local owners: { number } = {}
	for _, flag in territory.flags do
		table.insert(owners, flag.state.owner)
	end
	local before = territory.owner
	territory.owner = TerritoryRules.owner(owners)
	for _, flag in territory.flags do
		flag.part:SetAttribute("TerritoryOwner", territory.owner)
	end
	return before
end

-- Aura for a player, shown as a pop-up and counted for the results screen.
local function giveAura(player: Player, amount: number)
	local shown = DataService.addAura(player, amount)
	if shown > 0 then
		Stats.add(player, "aura", shown)
		PopupSystem.send(player, "aura", shown, "")
	end
end

-- Capture speed for a tier: Gold 4 seconds, Diamond 6, Ultra 8 for one player (see Pace.capture).
local function paramsFor(tier: string): CaptureBar.Params
	local cached = tierParams[tier]
	if not cached then
		cached = { secondsForOneAura = Pace.capture.secondsPerFlag[tier] or params.secondsForOneAura, decayPerSecond = params.decayPerSecond }
		tierParams[tier] = cached
	end
	return cached
end

local function tick(dt: number)
	if not active then
		return
	end
	tickClock += dt
	local secondTick = tickClock >= 1
	if secondTick then
		tickClock -= 1
	end
	for _, record in zones do
		local powers, members, botsHere = powersInZone(record.part)
		-- More teammates on a flag capture it faster: each extra one adds +25 percent, up to double speed. A faction's
		-- push is its average aura power times that team bonus.
		local counts: { [number]: number } = {}
		for faction, list in members do
			counts[faction] = (counts[faction] or 0) + #list
		end
		for _, bot in botsHere do
			counts[bot.faction] = (counts[bot.faction] or 0) + 1
		end
		for faction, power in powers do
			local count = math.max(1, counts[faction] or 1)
			powers[faction] = power / count * math.min(Pace.capture.maxMultiplier, 1 + Pace.capture.extraPlayerBonus * (count - 1))
		end
		local previousOwner = record.state.owner
		for faction, multiplier in record.boosts do
			if powers[faction] then
				powers[faction] = UnitRules.boostedPower(powers[faction], multiplier)
			end
		end

		-- Players on the pushing faction earn contribution while the zone is being attacked.
		local leaderId = CaptureBar.leader(powers)
		if leaderId ~= 0 and leaderId ~= record.state.owner and members[leaderId] then
			for _, player in members[leaderId] do
				local entry = record.territory.contribs[player.UserId]
				if not entry or entry.faction ~= leaderId then
					entry = { faction = leaderId, units = 0 }
					record.territory.contribs[player.UserId] = entry
				end
				local gained = ContributionScoring.fromPush(1, dt)
				entry.units += gained
				warUnits[player.UserId] = (warUnits[player.UserId] or 0) + gained
			end
		end

		-- A flag cannot be captured while an enemy is alive inside it: with two or more factions present it is
		-- CONTESTED and the bar holds still until the others are mogged or leave.
		local present = 0
		for _, power in powers do
			if power > 0 then
				present += 1
			end
		end
		local contested = present >= 2
		if record.part:GetAttribute("Contested") ~= contested then
			record.part:SetAttribute("Contested", contested)
		end
		local result = if contested then { state = record.state, captured = false, newOwner = 0 } else CaptureBar.step(record.state, powers, dt, paramsFor(record.territory.tier))
		record.state = result.state
		-- +1 aura every second you stand on a flag you are capturing
		if secondTick and not contested and not result.captured and result.state.capturer ~= 0 and result.state.owner ~= result.state.capturer then
			for _, player in members[result.state.capturer] or {} do
				giveAura(player, Pace.rewards.flagTickAura)
			end
		end
		if result.captured then
			for _, player in members[result.newOwner] or {} do
				giveAura(player, Pace.rewards.flagCapturedAura) -- +25 for everyone helping when a flag flips
				Stats.add(player, "flags", 1)
				PopupSystem.send(player, "capture", 1, "")
			end
			-- One flag changed hands. The territory changes hands only if one faction now holds ALL its flags.
			local territory = record.territory
			local ownerBefore = refreshTerritory(territory)
			print(("[mog-wars] flag %s (%s) captured by faction %d: territory owner is now %d"):format(
				tostring(record.part:GetAttribute("FlagName")), territory.name, result.newOwner, territory.owner
			))
			if TerritoryRules.justCaptured(ownerBefore, territory.owner) then
				print(("[mog-wars] TERRITORY %s captured by faction %d"):format(territory.name, territory.owner))
				warCaptures[territory.owner] = (warCaptures[territory.owner] or 0) + 1
				payOut(territory, territory.owner, if ownerBefore ~= 0 then ownerBefore else previousOwner)
			end
		end
		show(record)
	end
end

-- Zones only move while active. WarSystem turns this off between wars.
function CaptureSystem.setActive(value: boolean)
	active = value
end

-- Start a clean war: every zone unowned and empty, and the war tallies cleared.
function CaptureSystem.resetWar()
	warUnits = {}
	warCaptures = {}
	for _, record in zones do
		record.state = CaptureBar.newState()
		record.shownProgress = -1
		show(record)
	end
	for _, territory in territories do
		territory.owner = 0
		territory.contribs = {}
		for _, flag in territory.flags do
			flag.part:SetAttribute("TerritoryOwner", 0)
		end
	end
end

-- Territory owners and values, for scoring a war (a territory counts only when held with all its flags).
function CaptureSystem.zoneSummary(): { WarRules.ZoneSummary }
	local list: { WarRules.ZoneSummary } = {}
	for _, territory in territories do
		table.insert(list, { owner = territory.owner, value = Territories.tiers[territory.tier].value })
	end
	return list
end

-- Every territory with its tier and current owner (0 = nobody), for the aura trickle.
function CaptureSystem.territoryList(): { { id: string, tier: string, owner: number } }
	local list = {}
	for _, territory in territories do
		table.insert(list, { id = territory.id, tier = territory.tier, owner = territory.owner })
	end
	return list
end

-- Copies of this war's contribution per user id and captures per faction.
function CaptureSystem.warTallies(): ({ [number]: number }, { [number]: number })
	return table.clone(warUnits), table.clone(warCaptures)
end

local function playerInZone(player: Player, zone: BasePart): boolean
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	local offset = zone.CFrame:PointToObjectSpace(root.Position)
	return ZoneGeometry.contains(offset.X, offset.Y, offset.Z, zone.Size.X, zone.Size.Y, zone.Size.Z, HEADROOM)
end

-- Give a player contribution in the zone they share with `other`, but only while attacking it (the zone is
-- not already their faction's). Used for shoves and mog-off wins.
local function credit(player: Player, other: Player?, amount: number)
	local faction = player:GetAttribute("Faction")
	if not active or type(faction) ~= "number" then
		return
	end
	for _, record in zones do
		if record.state.owner ~= faction and playerInZone(player, record.part) and (other == nil or playerInZone(other, record.part)) then
			local entry = record.territory.contribs[player.UserId]
			if not entry or entry.faction ~= faction then
				entry = { faction = faction, units = 0 }
				record.territory.contribs[player.UserId] = entry
			end
			entry.units += amount
			warUnits[player.UserId] = (warUnits[player.UserId] or 0) + amount
			return
		end
	end
end

function CaptureSystem.creditShove(shover: Player, target: Player)
	credit(shover, target, Config.capture.shoveAssist)
end

-- `loser` is nil when the winner beat a bot; `factor` scales the reward (bots pay less).
function CaptureSystem.creditMogOffWin(winner: Player, loser: Player?, factor: number?)
	credit(winner, loser, Config.capture.mogOffWin * (factor or 1))
end

-- The faction that owns the flag zone containing this point (0 if none or unowned). Used for the defend bonus.
function CaptureSystem.ownerAt(position: Vector3): number
	for _, record in zones do
		local offset = record.part.CFrame:PointToObjectSpace(position)
		if ZoneGeometry.contains(offset.X, offset.Y, offset.Z, record.part.Size.X, record.part.Size.Y, record.part.Size.Z, HEADROOM) then
			return record.state.owner
		end
	end
	return 0
end

-- Every ground-level flag with its position, size and current owner, for the spawn system.
function CaptureSystem.zoneList(): { SpawnRules.ZoneInfo }
	local list: { SpawnRules.ZoneInfo } = {}
	for _, record in zones do
		if record.height <= 3 and not record.noSpawn then -- raised flags (cliffs, the lighthouse top) and hidden ones are not used for spawning
			local position = record.part.Position
			table.insert(list, { x = position.X, z = position.Z, size = record.part.Size.X, owner = record.state.owner })
		end
	end
	return list
end

-- The zone part this player is standing in, or nil.
function CaptureSystem.zoneAt(player: Player): BasePart?
	for _, record in zones do
		if playerInZone(player, record.part) then
			return record.part
		end
	end
	return nil
end

-- Set (or clear, with nil) a faction's tank boost in one zone.
function CaptureSystem.setBoost(zone: BasePart, faction: number, multiplier: number?)
	local record = zones[zone]
	if record then
		record.boosts[faction] = multiplier
	end
end

function CaptureSystem.clearBoosts()
	for _, record in zones do
		record.boosts = {}
	end
end

export type Occupancy = { owner: number, players: { Player }, bots: { BotService.Bot } }

-- Who is standing in each zone right now, with the zone's owner, for the mog-off system.
function CaptureSystem.occupants(): { Occupancy }
	local list: { Occupancy } = {}
	for _, record in zones do
		local _, members, botsHere = powersInZone(record.part)
		local everyone: { Player } = {}
		for _, group in members do
			for _, player in group do
				table.insert(everyone, player)
			end
		end
		table.insert(list, { owner = record.state.owner, players = everyone, bots = botsHere })
	end
	return list
end

-- Zones with their positions and owners, for the bots to choose from.
function CaptureSystem.zoneViews(): { BotService.ZoneView }
	local list: { BotService.ZoneView } = {}
	for _, record in zones do
		table.insert(list, {
			part = record.part,
			x = record.part.Position.X,
			z = record.part.Position.Z,
			y = record.height,
			size = record.part.Size.X,
			owner = record.state.owner,
			value = Territories.tiers[record.territory.tier].value,
		})
	end
	return list
end

function CaptureSystem.init()
	BotService.setZoneSource(CaptureSystem.zoneViews)
	for _, instance in CollectionService:GetTagged("Zone") do
		register(instance)
	end
	CollectionService:GetInstanceAddedSignal("Zone"):Connect(register)
	CollectionService:GetInstanceRemovedSignal("Zone"):Connect(unregister)
end

function CaptureSystem.start()
	RunService.Heartbeat:Connect(function(dt: number)
		accumulator += dt
		if accumulator >= Config.capture.tickSeconds then
			local step = accumulator
			accumulator = 0
			tick(step)
		end
	end)
end

return CaptureSystem
