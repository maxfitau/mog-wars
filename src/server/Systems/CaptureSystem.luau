--!strict
-- Slice 1 capture system. The server alone decides who is standing in a zone and how full the bar is.
-- There are NO remotes here: clients cannot ask for, or change, anything about a zone.
-- Zones are any parts tagged "Zone". Everyone is on one placeholder team until slice 2 adds factions.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CaptureBar = require(Shared:WaitForChild("CaptureBar"))
local Config = require(Shared:WaitForChild("EconomyConfig"))
local ZoneGeometry = require(Shared:WaitForChild("ZoneGeometry"))

local PLAYER_TEAM = 1
local HEADROOM = 8 -- studs above the zone that still count as standing in it
local UNOWNED_COLOR = Color3.fromRGB(200, 200, 200)
local PUSH_COLOR = Color3.fromRGB(255, 200, 60)
local OWNED_COLOR = Color3.fromRGB(70, 200, 110)

type ZoneRecord = {
	part: BasePart,
	state: CaptureBar.State,
	shownProgress: number,
}

local zones: { [BasePart]: ZoneRecord } = {}
local accumulator = 0

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
	}
	instance:SetAttribute("OwnerFaction", 0)
	instance:SetAttribute("Progress", 0)
end

local function unregister(instance: Instance)
	if instance:IsA("BasePart") then
		zones[instance] = nil
	end
end

-- Aura power of everyone alive and standing in the zone. Rank scaling arrives in slice 8.
local function powerInZone(zone: BasePart): number
	local power = 0
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and root and root:IsA("BasePart") and humanoid.Health > 0 then
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
				power += 1
			end
		end
	end
	return power
end

local function show(record: ZoneRecord)
	local state = record.state
	-- Round so attributes only replicate when the bar visibly moves.
	local rounded = math.floor(state.progress * 100 + 0.5) / 100
	if rounded ~= record.shownProgress then
		record.shownProgress = rounded
		record.part:SetAttribute("Progress", rounded)
		if state.owner ~= 0 then
			record.part.Color = OWNED_COLOR
		else
			record.part.Color = UNOWNED_COLOR:Lerp(PUSH_COLOR, rounded)
		end
	end
	if record.part:GetAttribute("OwnerFaction") ~= state.owner then
		record.part:SetAttribute("OwnerFaction", state.owner)
		record.part.Color = if state.owner ~= 0 then OWNED_COLOR else UNOWNED_COLOR
	end
end

local function tick(dt: number)
	for _, record in zones do
		local power = powerInZone(record.part)
		local powers: { [number]: number } = {}
		if power > 0 then
			powers[PLAYER_TEAM] = power
		end
		local result = CaptureBar.step(record.state, powers, dt, params)
		record.state = result.state
		if result.captured then
			print(("[mog-wars] zone %s captured by team %d"):format(record.part.Name, result.newOwner))
		end
		show(record)
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
