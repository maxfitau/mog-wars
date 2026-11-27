--!strict
-- Travel between War Island and Training Island, in the same place. Server only.
--  * Walking into a part tagged "Portal" (attribute Destination = "training" or "war") sends you there.
--  * The "TravelRequest" remote does the same for the HUD buttons. It carries only a destination name.
--  * Each request is checked (IslandRules.canTravel): known destination, not already there, not in a mog-off,
--    not just after being shoved or losing a duel, and a short cooldown. Nothing is trusted from the client.
--  * Landing on Training Island puts you at its arrival spot; going back drops you on your faction's front line
--    (home base between wars).
-- The "Island" attribute ("war" or "training") is worked out from where each player is standing, so it stays
-- right after respawns too. Replies go to the client as "TravelResult" (ok, reason, destination).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local IslandRules = require(Shared:WaitForChild("IslandRules"))
local MapLayout = require(Shared:WaitForChild("MapLayout"))
local ZoneGeometry = require(Shared:WaitForChild("ZoneGeometry"))
local MogOffSystem = require(script.Parent:WaitForChild("MogOffSystem"))
local SpawnSystem = require(script.Parent:WaitForChild("SpawnSystem"))

local COOLDOWN_SECONDS = 3
local MIN_REQUEST_INTERVAL = 0.5
local PORTAL_HEADROOM = 6
local TICK_SECONDS = 0.2

local TravelSystem = {}

local lastTravel: { [Player]: number } = {}
local lastRequest: { [Player]: number } = {}
local resultRemote: RemoteEvent? = nil

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function islandOf(player: Player): string
	local root = rootOf(player)
	if not root then
		return "war"
	end
	return IslandRules.islandAt(root.Position.X, root.Position.Z, MapLayout.trainingIsland)
end

local function send(player: Player, ok: boolean, reason: string, destination: string)
	if resultRemote then
		resultRemote:FireClient(player, ok, reason, destination)
	end
end

-- Try to move a player. Returns ok and a stable reason.
local function travel(player: Player, destination: any): (boolean, string)
	local now = Workspace:GetServerTimeNow()
	local root = rootOf(player)
	if not root or type(player:GetAttribute("Faction")) ~= "number" then
		return false, "not_ready"
	end
	local penalty = player:GetAttribute("PushPenaltyUntil")
	local ok, reason = IslandRules.canTravel(
		destination,
		islandOf(player),
		MogOffSystem.inDuel(player),
		now - (lastTravel[player] or -1000),
		if type(penalty) == "number" then penalty - now else 0,
		COOLDOWN_SECONDS
	)
	if not ok then
		return false, reason or "bad_input"
	end

	if destination == "training" then
		local island = MapLayout.trainingIsland
		local x, z = IslandRules.worldPoint(island, island.arrival.x, island.arrival.z)
		local target = Vector3.new(x, 4, z)
		local character = player.Character :: Model
		character:PivotTo(CFrame.lookAt(target, Vector3.new(x, 4, z - 20))) -- facing the treadmills
		root.AssemblyLinearVelocity = Vector3.zero
	elseif not SpawnSystem.sendToWar(player) then
		return false, "not_ready"
	end
	lastTravel[player] = now
	player:SetAttribute("Island", if destination == "training" then "training" else "war")
	return true, ""
end

local function scan()
	for _, player in Players:GetPlayers() do
		local island = islandOf(player)
		if player:GetAttribute("Island") ~= island then
			player:SetAttribute("Island", island)
		end
		local root = rootOf(player)
		if root then
			for _, portal in CollectionService:GetTagged("Portal") do
				if portal:IsA("BasePart") then
					local offset = portal.CFrame:PointToObjectSpace(root.Position)
					if ZoneGeometry.contains(offset.X, offset.Y, offset.Z, portal.Size.X, portal.Size.Y, portal.Size.Z, PORTAL_HEADROOM) then
						local destination = portal:GetAttribute("Destination")
						local ok, reason = travel(player, destination)
						if not ok and reason ~= "already_there" and reason ~= "too_soon" then
							send(player, false, reason, if type(destination) == "string" then destination else "")
						end
						break
					end
				end
			end
		end
	end
end

function TravelSystem.init()
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	local request = Instance.new("RemoteEvent")
	request.Name = "TravelRequest"
	request.Parent = folder
	local result = Instance.new("RemoteEvent")
	result.Name = "TravelResult"
	result.Parent = folder
	resultRemote = result

	request.OnServerEvent:Connect(function(player: Player, destination: any)
		local now = Workspace:GetServerTimeNow()
		if now - (lastRequest[player] or -1000) < MIN_REQUEST_INTERVAL then
			return
		end
		lastRequest[player] = now
		local ok, reason = travel(player, destination)
		send(player, ok, reason, if type(destination) == "string" then destination else "")
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastTravel[player] = nil
		lastRequest[player] = nil
	end)
end

function TravelSystem.start()
	task.spawn(function()
		while true do
			task.wait(TICK_SECONDS)
			scan()
		end
	end)
end

return TravelSystem
