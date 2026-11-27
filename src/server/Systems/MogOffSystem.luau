--!strict
-- Slice 7: mog-offs. When two enemies stay close together inside a zone for a moment, a 5-second tapping
-- duel starts. The server counts the taps (capped per second) and decides the winner by taps only. Rank,
-- aura and faction give no advantage. A tie goes to the defender (the fighter whose faction holds the zone);
-- with no defender it is a draw. The loser is knocked back and stunned briefly and pushes at reduced
-- power for a few seconds. The winner earns a little contribution toward the zone.
-- A duel can be player against player, or player against a bot (never bot against bot). A bot's taps are made
-- by the server at a human-like speed that depends on the player's rank (BotRules.duelRate); they go through
-- the same tap counter and speed cap as a player's. Beating a bot earns less (Config.bots.rewardFactor).
-- Players see state through attributes: MogOffStartsAt, MogOffEndsAt, MogOffOpponent, MogOffTaps, MogOffResult.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BotRules = require(Shared:WaitForChild("BotRules"))
local Config = require(Shared:WaitForChild("EconomyConfig"))
local MogOffRules = require(Shared:WaitForChild("MogOffRules"))
local ShoveRules = require(Shared:WaitForChild("ShoveRules"))
local BotService = require(script.Parent:WaitForChild("BotService"))
local CaptureSystem = require(script.Parent:WaitForChild("CaptureSystem"))
local SeasonService = require(script.Parent:WaitForChild("SeasonService"))

local LEAD_IN_SECONDS = 1 -- "get ready" time before taps count
local STEP_SECONDS = 0.1
local SCAN_SECONDS = 0.25

-- One side of a duel: a real player or a bot. Bot ids are negative, so ids never clash.
type Fighter = {
	id: number,
	faction: number,
	player: Player?,
	bot: BotService.Bot?,
}

type Active = {
	duel: MogOffRules.Duel,
	a: Fighter,
	b: Fighter,
	botRate: number, -- taps a second for the bot side, 0 if there is no bot
	botOwed: number,
}

local MogOffSystem = {}

local activeById: { [number]: Active } = {}
local pairTimers: { [string]: number } = {}
local lastDuelEnd: { [number]: number } = {}
local knockbackRemote: RemoteEvent? = nil
local rng = Random.new()

local function random(): number
	return rng:NextNumber()
end

local function playerRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function rootOf(fighter: Fighter): BasePart?
	if fighter.player then
		return playerRoot(fighter.player)
	end
	local bot = fighter.bot
	if bot and BotService.isAlive(bot) then
		return bot.root
	end
	return nil
end

local function nameOf(fighter: Fighter): string
	if fighter.player then
		return fighter.player.DisplayName
	end
	return (if fighter.bot then fighter.bot.name else "Bot") .. " (BOT)"
end

local function fighterOfPlayer(player: Player): Fighter?
	local faction = player:GetAttribute("Faction")
	if type(faction) ~= "number" then
		return nil
	end
	return { id = player.UserId, faction = faction, player = player, bot = nil }
end

local function fighterOfBot(bot: BotService.Bot): Fighter
	return { id = bot.id, faction = bot.faction, player = nil, bot = bot }
end

local function clearAttributes(fighter: Fighter)
	local player = fighter.player
	if player then
		player:SetAttribute("MogOffStartsAt", 0)
		player:SetAttribute("MogOffEndsAt", 0)
		player:SetAttribute("MogOffOpponent", "")
		player:SetAttribute("MogOffTaps", 0)
	end
end

local function stun(fighter: Fighter)
	if fighter.bot then
		BotService.stun(fighter.bot, Config.mogOff.stunSeconds)
		return
	end
	local player = fighter.player
	local humanoid = player and player.Character and player.Character:FindFirstChildOfClass("Humanoid")
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

local function finishFighter(fighter: Fighter, now: number)
	activeById[fighter.id] = nil
	lastDuelEnd[fighter.id] = now
	clearAttributes(fighter)
end

local function endDuel(active: Active, cancelled: boolean)
	local now = Workspace:GetServerTimeNow()
	finishFighter(active.a, now)
	finishFighter(active.b, now)
	if cancelled then
		return
	end

	local outcome = MogOffRules.resolve(active.duel)
	local winner = if outcome.winner == active.a.id then active.a elseif outcome.winner == active.b.id then active.b else nil
	local loser = if outcome.loser == active.a.id then active.a elseif outcome.loser == active.b.id then active.b else nil

	if not winner or not loser then
		for _, fighter in { active.a, active.b } do
			if fighter.player then
				fighter.player:SetAttribute("MogOffResult", "draw")
			end
		end
		return
	end
	if winner.player then
		winner.player:SetAttribute("MogOffResult", "won")
	end
	if loser.player then
		loser.player:SetAttribute("MogOffResult", "lost")
	end

	-- The loser pushes weaker for a few seconds, is stunned, and is knocked back.
	local winnerRoot, loserRoot = rootOf(winner), rootOf(loser)
	local dx, dz = 0, 1
	if winnerRoot and loserRoot then
		dx, dz = ShoveRules.direction(winnerRoot.Position.X, winnerRoot.Position.Z, loserRoot.Position.X, loserRoot.Position.Z)
	end
	if loser.player then
		loser.player:SetAttribute("PushPenaltyUntil", now + Config.shove.penaltySeconds)
		if winnerRoot and loserRoot and knockbackRemote then
			knockbackRemote:FireClient(loser.player, dx, dz, Config.mogOff.knockbackStuds)
		end
	elseif loser.bot then
		BotService.weaken(loser.bot, now + Config.shove.penaltySeconds)
		BotService.knockback(loser.bot, dx, dz, Config.mogOff.knockbackStuds)
	end
	stun(loser)

	-- Rewards go to real players only, and are smaller for beating a bot.
	if winner.player then
		CaptureSystem.creditMogOffWin(winner.player, loser.player, if loser.bot then Config.bots.rewardFactor else 1)
		if loser.player then
			SeasonService.earn(winner.player, "mogOffWin", 1)
		end
	end
end

local function startDuel(a: Fighter, b: Fighter, zoneOwner: number)
	local now = Workspace:GetServerTimeNow()
	local defender = 0
	if zoneOwner ~= 0 then
		if a.faction == zoneOwner then
			defender = a.id
		elseif b.faction == zoneOwner then
			defender = b.id
		end
	end
	local duel = MogOffRules.newDuel(a.id, b.id, now + LEAD_IN_SECONDS, defender, Config.mogOff)

	-- If a bot is on one side, work out how fast it will tap against this particular player.
	local botRate = 0
	local human = if a.player then a.player elseif b.player then b.player else nil
	if (a.bot or b.bot) and human then
		local rank = human:GetAttribute("Rank")
		local stage = human:GetAttribute("RevealStage")
		botRate = BotRules.duelRate(if type(rank) == "number" then rank else 1, if type(stage) == "number" then stage else 0, random, Config.bots)
	end

	local active: Active = { duel = duel, a = a, b = b, botRate = botRate, botOwed = 0 }
	activeById[a.id] = active
	activeById[b.id] = active
	for _, pair in { { a, b }, { b, a } } do
		local me, opponent = pair[1], pair[2]
		local player = me.player
		if player then
			player:SetAttribute("MogOffResult", "")
			player:SetAttribute("MogOffTaps", 0)
			player:SetAttribute("MogOffOpponent", nameOf(opponent))
			player:SetAttribute("MogOffStartsAt", duel.startsAt)
			player:SetAttribute("MogOffEndsAt", duel.endsAt)
		end
	end
end

local function scan(dt: number)
	local now = Workspace:GetServerTimeNow()
	local seen: { [string]: boolean } = {}

	for _, occupancy in CaptureSystem.occupants() do
		local fighters: { Fighter } = {}
		for _, player in occupancy.players do
			local fighter = fighterOfPlayer(player)
			if fighter then
				table.insert(fighters, fighter)
			end
		end
		for _, bot in occupancy.bots do
			table.insert(fighters, fighterOfBot(bot))
		end
		for i = 1, #fighters do
			for j = i + 1, #fighters do
				local a, b = fighters[i], fighters[j]
				if a.faction ~= b.faction and (a.player or b.player) then -- never bot against bot
					local free = not activeById[a.id]
						and not activeById[b.id]
						and MogOffRules.offCooldown(now, lastDuelEnd[a.id] or -1000, Config.mogOff)
						and MogOffRules.offCooldown(now, lastDuelEnd[b.id] or -1000, Config.mogOff)
					local ra, rb = rootOf(a), rootOf(b)
					if free and ra and rb and MogOffRules.isClose(ra.Position.X, ra.Position.Y, ra.Position.Z, rb.Position.X, rb.Position.Y, rb.Position.Z, Config.mogOff) then
						local key = math.min(a.id, b.id) .. ":" .. math.max(a.id, b.id)
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
	end
	for key in pairTimers do
		if not seen[key] then
			pairTimers[key] = nil -- they separated, so the timer starts over
		end
	end
end

-- True while the player is in a mog-off (used to stop them travelling away from it).
function MogOffSystem.inDuel(player: Player): boolean
	return activeById[player.UserId] ~= nil
end

function MogOffSystem.init()
	local folder = ReplicatedStorage:WaitForChild("Remotes")
	knockbackRemote = folder:WaitForChild("ShoveKnockback") :: RemoteEvent

	local tap = Instance.new("RemoteEvent")
	tap.Name = "MogOffTap"
	tap.Parent = folder
	tap.OnServerEvent:Connect(function(player: Player)
		-- No arguments are read. The server decides whether this counts.
		local active = activeById[player.UserId]
		if not active then
			return
		end
		if MogOffRules.registerTap(active.duel, player.UserId, Workspace:GetServerTimeNow(), Config.mogOff) then
			player:SetAttribute("MogOffTaps", active.duel.taps[player.UserId])
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local active = activeById[player.UserId]
		if active then
			endDuel(active, true)
		end
		lastDuelEnd[player.UserId] = nil
	end)
end

-- A bot's taps for this step: the server makes them at the bot's speed, through the same counter and cap.
local function botTaps(active: Active, now: number)
	local bot = if active.a.bot then active.a elseif active.b.bot then active.b else nil
	if not bot or active.botRate <= 0 then
		return
	end
	local whole
	whole, active.botOwed = BotRules.tapsThisStep(active.botRate, STEP_SECONDS, active.botOwed, 0.7 + random() * 0.6)
	for _ = 1, whole do
		MogOffRules.registerTap(active.duel, bot.id, now, Config.mogOff)
	end
end

function MogOffSystem.start()
	task.spawn(function()
		local scanAccumulator = 0
		while true do
			task.wait(STEP_SECONDS)
			local now = Workspace:GetServerTimeNow()
			local warOn = Workspace:GetAttribute("WarPhase") == "War"
			local handled: { [Active]: boolean } = {}
			for _, active in activeById do
				if not handled[active] then
					handled[active] = true
					local gone = not rootOf(active.a) or not rootOf(active.b)
					if not warOn or gone then
						endDuel(active, true)
					elseif now >= active.duel.endsAt then
						endDuel(active, false)
					else
						botTaps(active, now)
					end
				end
			end
			scanAccumulator += STEP_SECONDS
			if scanAccumulator >= SCAN_SECONDS then
				local dt = scanAccumulator
				scanAccumulator = 0
				if warOn then
					scan(dt)
				else
					pairTimers = {}
				end
			end
		end
	end)
end

return MogOffSystem
