--!strict
-- Slice 7: mog-offs. When two enemies stay close together inside a zone for a moment, a 5-second tapping
-- duel starts. The server counts the taps (capped per second) and decides the winner by taps only. Rank,
-- aura and faction give no advantage. A tie goes to the defender (the player whose faction holds the zone);
-- with no defender it is a draw. The loser is knocked back and stunned briefly and pushes at reduced
-- power for a few seconds. The winner earns a little contribution toward the zone.
-- Players see state through attributes: MogOffStartsAt, MogOffEndsAt, MogOffOpponent, MogOffTaps, MogOffResult.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("EconomyConfig"))
local MogOffRules = require(Shared:WaitForChild("MogOffRules"))
local ShoveRules = require(Shared:WaitForChild("ShoveRules"))
local CaptureSystem = require(script.Parent:WaitForChild("CaptureSystem"))
local SeasonService = require(script.Parent:WaitForChild("SeasonService"))

local LEAD_IN_SECONDS = 1 -- "get ready" time before taps count

type Active = { duel: MogOffRules.Duel, a: Player, b: Player }

local MogOffSystem = {}

local activeByUser: { [number]: Active } = {}
local pairTimers: { [string]: number } = {}
local lastDuelEnd: { [number]: number } = {}
local knockbackRemote: RemoteEvent? = nil

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function clearAttributes(player: Player)
	player:SetAttribute("MogOffStartsAt", 0)
	player:SetAttribute("MogOffEndsAt", 0)
	player:SetAttribute("MogOffOpponent", "")
	player:SetAttribute("MogOffTaps", 0)
end

local function stun(player: Player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local original = humanoid.WalkSpeed
	humanoid.WalkSpeed = 0
	task.delay(Config.mogOff.stunSeconds, function()
		if humanoid.Parent and humanoid.WalkSpeed == 0 then
			humanoid.WalkSpeed = original
		end
	end)
end

local function endDuel(active: Active, cancelled: boolean)
	activeByUser[active.a.UserId] = nil
	activeByUser[active.b.UserId] = nil
	local now = Workspace:GetServerTimeNow()
	lastDuelEnd[active.a.UserId] = now
	lastDuelEnd[active.b.UserId] = now
	clearAttributes(active.a)
	clearAttributes(active.b)
	if cancelled then
		return
	end

	local outcome = MogOffRules.resolve(active.duel)
	local winner = if outcome.winner == active.a.UserId then active.a elseif outcome.winner == active.b.UserId then active.b else nil
	local loser = if outcome.loser == active.a.UserId then active.a elseif outcome.loser == active.b.UserId then active.b else nil

	if not winner or not loser then
		active.a:SetAttribute("MogOffResult", "draw")
		active.b:SetAttribute("MogOffResult", "draw")
		return
	end
	winner:SetAttribute("MogOffResult", "won")
	loser:SetAttribute("MogOffResult", "lost")

	loser:SetAttribute("PushPenaltyUntil", now + Config.shove.penaltySeconds)
	stun(loser)
	local winnerRoot, loserRoot = rootOf(winner), rootOf(loser)
	if winnerRoot and loserRoot and knockbackRemote then
		local dx, dz = ShoveRules.direction(winnerRoot.Position.X, winnerRoot.Position.Z, loserRoot.Position.X, loserRoot.Position.Z)
		knockbackRemote:FireClient(loser, dx, dz, Config.mogOff.knockbackStuds)
	end
	CaptureSystem.creditMogOffWin(winner, loser)
	SeasonService.earn(winner, "mogOffWin", 1)
end

local function startDuel(a: Player, b: Player, zoneOwner: number)
	local now = Workspace:GetServerTimeNow()
	local factionA, factionB = a:GetAttribute("Faction"), b:GetAttribute("Faction")
	local defender = 0
	if zoneOwner ~= 0 then
		if factionA == zoneOwner then
			defender = a.UserId
		elseif factionB == zoneOwner then
			defender = b.UserId
		end
	end
	local duel = MogOffRules.newDuel(a.UserId, b.UserId, now + LEAD_IN_SECONDS, defender, Config.mogOff)
	local active: Active = { duel = duel, a = a, b = b }
	activeByUser[a.UserId] = active
	activeByUser[b.UserId] = active
	for player, opponent in { [a] = b, [b] = a } do
		player:SetAttribute("MogOffResult", "")
		player:SetAttribute("MogOffTaps", 0)
		player:SetAttribute("MogOffOpponent", opponent.DisplayName)
		player:SetAttribute("MogOffStartsAt", duel.startsAt)
		player:SetAttribute("MogOffEndsAt", duel.endsAt)
	end
end

local function scan(dt: number)
	local now = Workspace:GetServerTimeNow()
	local seen: { [string]: boolean } = {}

	for _, occupancy in CaptureSystem.occupants() do
		local list = occupancy.players
		for i = 1, #list do
			for j = i + 1, #list do
				local a, b = list[i], list[j]
				local fa, fb = a:GetAttribute("Faction"), b:GetAttribute("Faction")
				local free = not activeByUser[a.UserId]
					and not activeByUser[b.UserId]
					and MogOffRules.offCooldown(now, lastDuelEnd[a.UserId] or -1000, Config.mogOff)
					and MogOffRules.offCooldown(now, lastDuelEnd[b.UserId] or -1000, Config.mogOff)
				local ra, rb = rootOf(a), rootOf(b)
				if free and fa ~= fb and ra and rb and MogOffRules.isClose(ra.Position.X, ra.Position.Y, ra.Position.Z, rb.Position.X, rb.Position.Y, rb.Position.Z, Config.mogOff) then
					local key = math.min(a.UserId, b.UserId) .. ":" .. math.max(a.UserId, b.UserId)
					seen[key] = true
					pairTimers[key] = (pairTimers[key] or 0) + dt
					if pairTimers[key] >= Config.mogOff.closeSeconds then
						pairTimers[key] = nil
						seen[key] = nil
						startDuel(a, b, occupancy.owner)
					end
				end
			end
		end
	end
	for key in pairTimers do
		if not seen[key] then
			pairTimers[key] = nil -- they separated, so the timer starts over
		end
	end
end

-- True while the player is in a mog-off (used to stop them travelling away from it).
function MogOffSystem.inDuel(player: Player): boolean
	return activeByUser[player.UserId] ~= nil
end

function MogOffSystem.init()
	local folder = ReplicatedStorage:WaitForChild("Remotes")
	knockbackRemote = folder:WaitForChild("ShoveKnockback") :: RemoteEvent

	local tap = Instance.new("RemoteEvent")
	tap.Name = "MogOffTap"
	tap.Parent = folder
	tap.OnServerEvent:Connect(function(player: Player)
		-- No arguments are read. The server decides whether this counts.
		local active = activeByUser[player.UserId]
		if not active then
			return
		end
		if MogOffRules.registerTap(active.duel, player.UserId, Workspace:GetServerTimeNow(), Config.mogOff) then
			player:SetAttribute("MogOffTaps", active.duel.taps[player.UserId])
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local active = activeByUser[player.UserId]
		if active then
			endDuel(active, true)
		end
		lastDuelEnd[player.UserId] = nil
	end)
end

function MogOffSystem.start()
	task.spawn(function()
		local step = 0.25
		while true do
			task.wait(step)
			local now = Workspace:GetServerTimeNow()
			local warOn = Workspace:GetAttribute("WarPhase") == "War"
			local handled: { [Active]: boolean } = {}
			for _, active in activeByUser do
				if not handled[active] then
					handled[active] = true
					local gone = not rootOf(active.a) or not rootOf(active.b)
					if not warOn or gone then
						endDuel(active, true)
					elseif now >= active.duel.endsAt then
						endDuel(active, false)
					end
				end
			end
			if warOn then
				scan(step)
			else
				pairTimers = {}
			end
		end
	end)
end

return MogOffSystem
