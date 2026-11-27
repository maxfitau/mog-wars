--!strict
-- Slice 10: tank and horse units. Server only.
--  * "DeployUnitRequest" carries only a unit id. UnitRules.canDeploy checks the war, the player and the
--    zone; then one unit is used up and the effect starts. Units last ONE war: every effect is removed when
--    the war phase changes.
--  * Tank: boosts the player's FACTION push in the zone they stand in (one tank per faction per zone).
--  * Horse: raises that player's walk speed (kept after respawn until the war ends).
--  * "SellUnitRequest" carries only a unit id and pays the unit's sell value (DataService.sellUnit).
-- Results go back to the client as "UnitResult".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("EconomyConfig"))
local FactionRules = require(Shared:WaitForChild("FactionRules"))
local UnitRules = require(Shared:WaitForChild("UnitRules"))
local CaptureSystem = require(script.Parent:WaitForChild("CaptureSystem"))
local DataService = require(script.Parent:WaitForChild("DataService"))

local MIN_INTERVAL = 0.5 -- seconds between requests from one player

local UnitSystem = {}

local lastRequest: { [Player]: number } = {}
local tanks: { [BasePart]: { [number]: Part } } = {} -- zone, then faction id, to the visible tank
local riders: { [Player]: boolean } = {}
local resultRemote: RemoteEvent? = nil

local function send(player: Player, ok: boolean, reason: string, action: string, unit: string, amount: number)
	if resultRemote then
		resultRemote:FireClient(player, ok, reason, action, unit, amount)
	end
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return humanoid
	end
	return nil
end

local function applyHorse(player: Player)
	local humanoid = humanoidOf(player)
	if humanoid then
		player:SetAttribute("HorseMultiplier", UnitRules.walkSpeed(1, true, Config.units.horse.speedMultiplier)) -- MovementSystem applies it on top of the base speed
	end
end

-- Remove every unit effect. Called when the war phase changes, so units last one war.
local function clearAll()
	for _, byFaction in tanks do
		for _, part in byFaction do
			part:Destroy()
		end
	end
	tanks = {}
	CaptureSystem.clearBoosts()
	for player in riders do
		player:SetAttribute("HorseMultiplier", nil)
	end
	riders = {}
end

local function makeTankPart(zone: BasePart, player: Player, factionId: number): Part
	local faction = FactionRules.byId(factionId)
	local part = Instance.new("Part")
	part.Name = "Tank"
	part.Size = Vector3.new(6, 4, 10)
	part.Anchored = true
	part.CanCollide = false
	part.Material = Enum.Material.Metal
	part.Color = if faction then FactionRules.color(faction) else Color3.fromRGB(120, 120, 120)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local at = if root and root:IsA("BasePart") then root.Position else zone.Position
	part.Position = Vector3.new(at.X + 6, zone.Position.Y + 2.5, at.Z)
	part:SetAttribute("Faction", factionId)
	part.Parent = Workspace
	return part
end

local function deploy(player: Player, unitId: any)
	if type(unitId) ~= "string" then
		send(player, false, "bad_input", "deploy", "", 0)
		return
	end
	local factionId = player:GetAttribute("Faction")
	if type(factionId) ~= "number" then
		send(player, false, "bad_input", "deploy", unitId, 0)
		return
	end
	local zone = CaptureSystem.zoneAt(player)
	local ok, reason = UnitRules.canDeploy(unitId, {
		warOn = Workspace:GetAttribute("WarPhase") == "War",
		owned = DataService.unitCount(player, unitId),
		alive = humanoidOf(player) ~= nil,
		inZone = zone ~= nil,
		tankInZone = zone ~= nil and tanks[zone] ~= nil and tanks[zone][factionId] ~= nil,
		riding = riders[player] == true,
	})
	if not ok then
		send(player, false, reason or "bad_input", "deploy", unitId, 0)
		return
	end
	if not DataService.takeUnit(player, unitId) then
		send(player, false, "no_unit", "deploy", unitId, 0)
		return
	end
	if unitId == "tank" and zone then
		local byFaction = tanks[zone] or {}
		tanks[zone] = byFaction
		byFaction[factionId] = makeTankPart(zone, player, factionId)
		CaptureSystem.setBoost(zone, factionId, Config.units.tank.captureMultiplier)
	elseif unitId == "horse" then
		riders[player] = true
		applyHorse(player)
	end
	send(player, true, "", "deploy", unitId, 0)
end

function UnitSystem.init()
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	local deployRemote = Instance.new("RemoteEvent")
	deployRemote.Name = "DeployUnitRequest"
	deployRemote.Parent = folder
	local sellRemote = Instance.new("RemoteEvent")
	sellRemote.Name = "SellUnitRequest"
	sellRemote.Parent = folder
	local result = Instance.new("RemoteEvent")
	result.Name = "UnitResult"
	result.Parent = folder
	resultRemote = result

	local function throttled(player: Player): boolean
		local now = Workspace:GetServerTimeNow()
		if now - (lastRequest[player] or -1000) < MIN_INTERVAL then
			return true
		end
		lastRequest[player] = now
		return false
	end

	deployRemote.OnServerEvent:Connect(function(player: Player, unitId: any)
		if not throttled(player) then
			deploy(player, unitId)
		end
	end)
	sellRemote.OnServerEvent:Connect(function(player: Player, unitId: any)
		if throttled(player) then
			return
		end
		local ok, reason, amount = DataService.sellUnit(player, unitId)
		send(player, ok, reason, "sell", if type(unitId) == "string" then unitId else "", amount)
	end)

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			if riders[player] then
				task.defer(applyHorse, player)
			end
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
		riders[player] = nil
	end)
	-- Units last one war: any phase change (war start or war end) clears them.
	Workspace:GetAttributeChangedSignal("WarPhase"):Connect(clearAll)
end

function UnitSystem.start()
	for _, player in Players:GetPlayers() do
		player.CharacterAdded:Connect(function()
			if riders[player] then
				task.defer(applyHorse, player)
			end
		end)
	end
end

return UnitSystem
