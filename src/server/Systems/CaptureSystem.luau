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
local ShoveRules = require(Shared:WaitForChild("ShoveRules"))
local WarRules = require(Shared:WaitForChild("WarRules"))
local ZoneGeometry = require(Shared:WaitForChild("ZoneGeometry"))
local DataService = require(script.Parent:WaitForChild("DataService"))

local HEADROOM = 8 -- studs above the zone that still count as standing in it
local UNOWNED_COLOR = Color3.fromRGB(200, 200, 200)
local PUSH_COLOR = Color3.fromRGB(255, 200, 60)

type ZoneRecord = {
	part: BasePart,
	state: CaptureBar.State,
	shownProgress: number,
	contribs: { [number]: { faction: number, units: number } }, -- by user id, for the next payout
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

-- Aura power per faction of everyone alive and standing in the zone. Rank scaling arrives in slice 8.
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
				powers[faction] = (powers[faction] or 0) + weight
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
	for userId, amount in payouts do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			DataService.addPoints(player, WarRules.applyMultiplier(amount, DataService.rewardMultiplier(player))) -- a player who left before payout loses that share
		end
	end
	record.contribs = {}
end

local function tick(dt: number)
	if not active then
		return
	end
	for _, record in zones do
		local powers, members = powersInZone(record.part)

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

-- A shove inside a zone counts as a little contribution for the shover, but only while the shover is
-- attacking (the zone is not already theirs).
function CaptureSystem.creditShove(shover: Player, target: Player)
	local faction = shover:GetAttribute("Faction")
	if not active or type(faction) ~= "number" then
		return
	end
	for _, record in zones do
		if record.state.owner ~= faction and playerInZone(shover, record.part) and playerInZone(target, record.part) then
			local entry = record.contribs[shover.UserId]
			if not entry or entry.faction ~= faction then
				entry = { faction = faction, units = 0 }
				record.contribs[shover.UserId] = entry
			end
			entry.units += Config.capture.shoveAssist
			warUnits[shover.UserId] = (warUnits[shover.UserId] or 0) + Config.capture.shoveAssist
			return
		end
	end
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
