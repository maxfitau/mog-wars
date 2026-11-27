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
local BoxRoll = require(Shared:WaitForChild("BoxRoll"))
local ContributionScoring = require(Shared:WaitForChild("ContributionScoring"))
local TrainingRules = require(Shared:WaitForChild("TrainingRules"))
local SpawnRules = require(Shared:WaitForChild("SpawnRules"))
local Features = require(Shared:WaitForChild("Features"))
local SquadRules = require(Shared:WaitForChild("SquadRules"))
local ShoveRules = require(Shared:WaitForChild("ShoveRules"))
local UnitRules = require(Shared:WaitForChild("UnitRules"))
local WarRules = require(Shared:WaitForChild("WarRules"))
local ZoneGeometry = require(Shared:WaitForChild("ZoneGeometry"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local FriendService = require(script.Parent:WaitForChild("FriendService"))
local SeasonService = require(script.Parent:WaitForChild("SeasonService"))

local HEADROOM = 8 -- studs above the zone that still count as standing in it
local UNOWNED_COLOR = Color3.fromRGB(200, 200, 200)
local PUSH_COLOR = Color3.fromRGB(255, 200, 60)

type ZoneRecord = {
	part: BasePart,
	state: CaptureBar.State,
	shownProgress: number,
	contribs: { [number]: { faction: number, units: number } }, -- by user id, for the next payout
	boosts: { [number]: number }, -- tank boost per faction in this zone (set by UnitSystem)
}

local zones: { [BasePart]: ZoneRecord } = {}
local accumulator = 0
local active = true -- zones only move during a war
local warUnits: { [number]: number } = {} -- contribution per user id this war
local warCaptures: { [number]: number } = {} -- captures per faction this war

local params: CaptureBar.Params = {
	secondsForOneAura = Config.capture.secondsForOneAura,
	decayPerSecond = Config.capture.decayPerSecond,
}

local CaptureSystem = {}

local function register(instance: Instance)
	if not instance:IsA("BasePart") or zones[instance] then
		return
	end
	zones[instance] = {
		part = instance,
		state = CaptureBar.newState(),
		shownProgress = -1,
		contribs = {},
		boosts = {},
	}
	instance:SetAttribute("OwnerFaction", 0)
	instance:SetAttribute("Progress", 0)
	instance:SetAttribute("CapturerFaction", 0)
	if instance:GetAttribute("Value") == nil then
		instance:SetAttribute("Value", 1)
	end
end

local function unregister(instance: Instance)
	if instance:IsA("BasePart") then
		zones[instance] = nil
	end
end

-- Aura power per faction of everyone alive and standing in the zone. Aura grows with training; a recent shove
-- or mog-off loss weakens it for a few seconds.
local function powersInZone(zone: BasePart): ({ [number]: number }, { [number]: { Player } })
	local powers: { [number]: number } = {}
	local members: { [number]: { Player } } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local faction = player:GetAttribute("Faction")
		if type(faction) == "number" and FactionRules.byId(faction) and humanoid and root and root:IsA("BasePart") and humanoid.Health > 0 then
			local offset = zone.CFrame:PointToObjectSpace(root.Position)
			if
				ZoneGeometry.contains(
					offset.X,
					offset.Y,
					offset.Z,
					zone.Size.X,
					zone.Size.Y,
					zone.Size.Z,
					HEADROOM
				)
			then
				local penaltyUntil = player:GetAttribute("PushPenaltyUntil")
				local weight = ShoveRules.powerMultiplier(
					Workspace:GetServerTimeNow(),
					if type(penaltyUntil) == "number" then penaltyUntil else 0,
					Config.shove
				)
				local level = player:GetAttribute("TrainingLevel")
				local aura = TrainingRules.auraMultiplier(if type(level) == "number" then level else 0, Config.training)
				powers[faction] = (powers[faction] or 0) + weight * aura
				members[faction] = members[faction] or {}
				table.insert(members[faction], player)
			end
		end
	end
	return powers, members
end

local function ownerColor(owner: number): Color3
	local faction = FactionRules.byId(owner)
	return if faction then FactionRules.color(faction) else UNOWNED_COLOR
end

local function show(record: ZoneRecord)
	local state = record.state
	-- Round so attributes only replicate when the bar visibly moves.
	local rounded = math.floor(state.progress * 100 + 0.5) / 100
	if rounded ~= record.shownProgress then
		record.shownProgress = rounded
		record.part:SetAttribute("Progress", rounded)
		record.part:SetAttribute("CapturerFaction", state.capturer)
		if state.owner ~= 0 then
			record.part.Color = ownerColor(state.owner)
		else
			record.part.Color = UNOWNED_COLOR:Lerp(PUSH_COLOR, rounded)
		end
	end
	if record.part:GetAttribute("CapturerFaction") ~= state.capturer then
		record.part:SetAttribute("CapturerFaction", state.capturer)
	end
	if record.part:GetAttribute("OwnerFaction") ~= state.owner then
		record.part:SetAttribute("OwnerFaction", state.owner)
		record.part.Color = if state.owner ~= 0 then ownerColor(state.owner) else UNOWNED_COLOR
	end
end

-- Pay out a captured zone: the pool is split by contribution among players of the capturing faction.
local function payOut(record: ZoneRecord, winner: number)
	local value = record.part:GetAttribute("Value")
	local zoneValue = if type(value) == "number" then value else 1
	local pool = Config.capture.basePool * zoneValue
	local boxTier = BoxRoll.tierForValue(zoneValue, Config.boxes.tierForValue)
	local units: { [number]: number } = {}
	for userId, entry in record.contribs do
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
		DataService.addPoints(player, finalAmounts[userId] + bonus)
		if boxTier then
			DataService.earnBox(player, boxTier) -- every paid contributor also earns a box, up to the daily cap
		end
		SeasonService.earn(player, "capture", zoneValue)
		DataService.recordCapture(player)
	end
	record.contribs = {}
end

local function tick(dt: number)
	if not active then
		return
	end
	for _, record in zones do
		local powers, members = powersInZone(record.part)
		for faction, multiplier in record.boosts do
			if powers[faction] then
				powers[faction] = UnitRules.boostedPower(powers[faction], multiplier)
			end
		end

		-- Players on the pushing faction earn contribution while the zone is being attacked.
		local leaderId = CaptureBar.leader(powers)
		if leaderId ~= 0 and leaderId ~= record.state.owner and members[leaderId] then
			for _, player in members[leaderId] do
				local entry = record.contribs[player.UserId]
				if not entry or entry.faction ~= leaderId then
					entry = { faction = leaderId, units = 0 }
					record.contribs[player.UserId] = entry
				end
				local gained = ContributionScoring.fromPush(1, dt)
				entry.units += gained
				warUnits[player.UserId] = (warUnits[player.UserId] or 0) + gained
			end
		end

		local result = CaptureBar.step(record.state, powers, dt, params)
		record.state = result.state
		if result.captured then
			print(("[mog-wars] zone %s captured by faction %d"):format(record.part.Name, result.newOwner))
			warCaptures[result.newOwner] = (warCaptures[result.newOwner] or 0) + 1
			payOut(record, result.newOwner)
		elseif record.state.capturer == 0 and record.state.progress == 0 and leaderId == 0 then
			record.contribs = {} -- the zone went idle, so old pushing no longer counts
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
		record.contribs = {}
		record.shownProgress = -1
		show(record)
	end
end

-- Zone owners and values, for scoring.
function CaptureSystem.zoneSummary(): { WarRules.ZoneSummary }
	local list: { WarRules.ZoneSummary } = {}
	for _, record in zones do
		local value = record.part:GetAttribute("Value")
		table.insert(list, { owner = record.state.owner, value = if type(value) == "number" then value else 1 })
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
local function credit(player: Player, other: Player, amount: number)
	local faction = player:GetAttribute("Faction")
	if not active or type(faction) ~= "number" then
		return
	end
	for _, record in zones do
		if record.state.owner ~= faction and playerInZone(player, record.part) and playerInZone(other, record.part) then
			local entry = record.contribs[player.UserId]
			if not entry or entry.faction ~= faction then
				entry = { faction = faction, units = 0 }
				record.contribs[player.UserId] = entry
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

function CaptureSystem.creditMogOffWin(winner: Player, loser: Player)
	credit(winner, loser, Config.capture.mogOffWin)
end

-- Every zone with its position, size and current owner, for the spawn system.
function CaptureSystem.zoneList(): { SpawnRules.ZoneInfo }
	local list: { SpawnRules.ZoneInfo } = {}
	for _, record in zones do
		local position = record.part.Position
		table.insert(list, { x = position.X, z = position.Z, size = record.part.Size.X, owner = record.state.owner })
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

export type Occupancy = { owner: number, players: { Player } }

-- Who is standing in each zone right now, with the zone's owner, for the mog-off system.
function CaptureSystem.occupants(): { Occupancy }
	local list: { Occupancy } = {}
	for _, record in zones do
		local _, members = powersInZone(record.part)
		local everyone: { Player } = {}
		for _, group in members do
			for _, player in group do
				table.insert(everyone, player)
			end
		end
		table.insert(list, { owner = record.state.owner, players = everyone })
	end
	return list
end

function CaptureSystem.init()
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
