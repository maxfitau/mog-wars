--!strict
-- Slice 6: the shove ability. The client sends a bare "ShoveRequest" with NO data; the server decides who
-- (if anyone) is shoved, using ShoveRules. Checks run in this order: war running, throttle, cooldown,
-- shover alive and in a faction, then target choice (nearest living enemy in range).
-- Effects: the target is pushed back (the target's own client applies it), pushes at reduced power for a
-- few seconds (server-side attribute read by CaptureSystem), and a shove inside a zone earns the shover
-- a little contribution.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("EconomyConfig"))
local Features = require(Shared:WaitForChild("Features"))
local WeaponRules = require(Shared:WaitForChild("WeaponRules"))
local ShoveRules = require(Shared:WaitForChild("ShoveRules"))
local BotService = require(script.Parent:WaitForChild("BotService"))
local CaptureSystem = require(script.Parent:WaitForChild("CaptureSystem"))
local PopupSystem = require(script.Parent:WaitForChild("PopupSystem"))
local MovementSystem = require(script.Parent:WaitForChild("MovementSystem"))
local StealSystem = require(script.Parent:WaitForChild("StealSystem"))
local Events = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("Events"))
local Shield = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("Shield"))
local AmbientNpc = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("AmbientNpc"))

local ShoveSystem = {}

local lastRequest: { [Player]: number } = {}
local lastShove: { [Player]: number } = {}
local knockRemote: RemoteEvent? = nil -- ShoveKnockback (set in init); the weapons use it too

-- An equipped weapon REPLACES plain Shove (the weapon button sends UseWeapon instead).
local function hasWeapon(player: Player): boolean
	if not Features.weapons then
		return false
	end
	local weapon = player:GetAttribute("Weapon")
	return type(weapon) == "string" and weapon ~= ""
end

-- Push a player (their own client applies it). Used by WeaponSystem too.
function ShoveSystem.knockPlayer(target: Player, dx: number, dz: number, studs: number)
	if knockRemote then
		knockRemote:FireClient(target, dx, dz, WeaponRules.clampStuds(studs))
	end
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function handle(player: Player, knockbackRemote: RemoteEvent)
	local now = Workspace:GetServerTimeNow()

	if Workspace:GetAttribute("WarPhase") ~= "War" then
		return
	end
	if hasWeapon(player) then
		return -- the weapon button (UseWeapon) is used instead
	end
	if ShoveRules.tooFast(now, lastRequest[player] or -1000, Config.shove) then
		return
	end
	lastRequest[player] = now
	if not ShoveRules.offCooldown(now, lastShove[player] or -1000, Config.shove) then
		return
	end

	local root = rootOf(player)
	local faction = player:GetAttribute("Faction")
	if not root or type(faction) ~= "number" then
		return
	end

	local candidates: { ShoveRules.Candidate } = {}
	local byId: { [number]: Player } = {}
	local botById: { [number]: BotService.Bot } = {}
	for _, other in Players:GetPlayers() do
		local otherRoot = rootOf(other)
		local otherFaction = other:GetAttribute("Faction")
		if other ~= player and otherRoot and type(otherFaction) == "number" then
			local position = otherRoot.Position
			table.insert(candidates, {
				id = other.UserId,
				x = position.X,
				y = position.Y,
				z = position.Z,
				faction = otherFaction,
				alive = true,
			})
			byId[other.UserId] = other
		end
	end

	-- Bots can be shoved too (their ids are negative, so they never clash with player ids).
	for _, bot in BotService.list() do
		local position = bot.root.Position
		table.insert(candidates, { id = bot.id, x = position.X, y = position.Y, z = position.Z, faction = bot.faction, alive = true })
		botById[bot.id] = bot
	end

	local origin = root.Position
	local targetId = ShoveRules.pickTarget(origin.X, origin.Y, origin.Z, faction, candidates, Config.shove)
	local targetBot = if targetId then botById[targetId] else nil
	if targetBot and Shield.active(targetBot.model) then
		lastShove[player] = now
		player:SetAttribute("ShoveReadyAt", now + Config.shove.cooldownSeconds)
		PopupSystem.send(player, "announce", 1, "BLOCKED!")
		return
	end
	if targetBot then
		lastShove[player] = now
		player:SetAttribute("ShoveReadyAt", now + Config.shove.cooldownSeconds)
		local bx, bz = ShoveRules.direction(origin.X, origin.Z, targetBot.root.Position.X, targetBot.root.Position.Z)
		BotService.weaken(targetBot, now + Config.shove.penaltySeconds)
		BotService.knockback(targetBot, bx, bz, Config.shove.knockbackStuds)
		PopupSystem.send(player, "bonk", 1, "")
		Events.fire(player, "shove_mogling", 1)
		return -- no contribution for shoving a bot
	end
	local target = if targetId then byId[targetId] else nil
	local targetRoot = if target then rootOf(target) else nil
	if not target or not targetRoot then
		-- no player or bot in range: a villager (ambient NPC) will do. It tips over comically and gets back up.
		local villager = AmbientNpc.nearest(origin, Config.shove.range)
		if villager then
			lastShove[player] = now
			player:SetAttribute("ShoveReadyAt", now + Config.shove.cooldownSeconds)
			villager:SetAttribute("BonkedAt", now)
			PopupSystem.send(player, "bonk", 1, "")
		end
		return -- nothing else in range: no cooldown is used
	end

	if Shield.active(target) then -- Mewing Shield: immune to shove
		lastShove[player] = now
		player:SetAttribute("ShoveReadyAt", now + Config.shove.cooldownSeconds)
		PopupSystem.send(player, "announce", 1, "BLOCKED!")
		return
	end
	lastShove[player] = now
	player:SetAttribute("ShoveReadyAt", now + Config.shove.cooldownSeconds)
	local dx, dz = ShoveRules.direction(origin.X, origin.Z, targetRoot.Position.X, targetRoot.Position.Z)
	if WeaponRules.reflecting(now, target:GetAttribute("ReflectUntil")) then
		-- Mirror Shield: the shove bounces back at the shover
		player:SetAttribute("PushPenaltyUntil", now + Config.shove.penaltySeconds)
		knockbackRemote:FireClient(player, -dx, -dz, Config.shove.knockbackStuds)
		StealSystem.noteHit(player, target)
		PopupSystem.send(player, "announce", 1, "REFLECTED!")
		PopupSystem.send(target, "announce", 1, "REFLECTED!")
		return
	end
	target:SetAttribute("PushPenaltyUntil", now + Config.shove.penaltySeconds)
	knockbackRemote:FireClient(target, dx, dz, Config.shove.knockbackStuds)
	PopupSystem.send(player, "bonk", 1, "") -- BONK! for the shover ...
	PopupSystem.send(target, "bonk", 2, "") -- ... and for whoever got bonked
	CaptureSystem.creditShove(player, target)
	Events.fire(player, "shove_player", 1)
	StealSystem.noteHit(target, player)
	if MovementSystem.isFrozen(target) then
		StealSystem.shoveFrozen(target, player) -- freeze them, then shove: they drop aura
	end
end

local botNextShove: { [number]: number } = {}

-- Bots shove too: now and then, a bot with an enemy close by gives a BONK (never more often than the cooldown).
local function botShoves(knockbackRemote: RemoteEvent)
	local now = Workspace:GetServerTimeNow()
	if Workspace:GetAttribute("WarPhase") ~= "War" then
		return
	end
	for _, bot in BotService.list() do
		if now >= (botNextShove[bot.id] or 0) and bot.humanoid.WalkSpeed > 0 then
			local best: Player? = nil
			local bestBot: BotService.Bot? = nil
			local bestDistance = Config.shove.range * 0.9
			for _, other in Players:GetPlayers() do
				local root = rootOf(other)
				if root and other:GetAttribute("Faction") ~= bot.faction and type(other:GetAttribute("Faction")) == "number" then
					local distance = (root.Position - bot.root.Position).Magnitude
					if distance < bestDistance then
						best, bestBot, bestDistance = other, nil, distance
					end
				end
			end
			for _, other in BotService.list() do
				if other.faction ~= bot.faction then
					local distance = (other.root.Position - bot.root.Position).Magnitude
					if distance < bestDistance then
						best, bestBot, bestDistance = nil, other, distance
					end
				end
			end
			if best or bestBot then
				botNextShove[bot.id] = now + Config.shove.cooldownSeconds * (1.5 + math.random() * 2)
				if best and WeaponRules.reflecting(now, best:GetAttribute("ReflectUntil")) then
					-- Mirror Shield: the Mogling's shove bounces back
					local bestRoot = rootOf(best) or bot.root
					local dx, dz = ShoveRules.direction(bestRoot.Position.X, bestRoot.Position.Z, bot.root.Position.X, bot.root.Position.Z)
					BotService.weaken(bot, now + Config.shove.penaltySeconds)
					BotService.knockback(bot, dx, dz, Config.shove.knockbackStuds)
					PopupSystem.send(best, "announce", 1, "REFLECTED!")
				elseif best and not Shield.active(best) then
					local root = rootOf(best)
					if root then
						StealSystem.noteHit(best, nil)
						local dx, dz = ShoveRules.direction(bot.root.Position.X, bot.root.Position.Z, root.Position.X, root.Position.Z)
						best:SetAttribute("PushPenaltyUntil", now + Config.shove.penaltySeconds)
						knockbackRemote:FireClient(best, dx, dz, Config.shove.knockbackStuds)
						PopupSystem.send(best, "bonk", 2, "")
					end
				elseif bestBot and not Shield.active(bestBot.model) then
					local dx, dz = ShoveRules.direction(bot.root.Position.X, bot.root.Position.Z, bestBot.root.Position.X, bestBot.root.Position.Z)
					BotService.weaken(bestBot, now + Config.shove.penaltySeconds)
					BotService.knockback(bestBot, dx, dz, Config.shove.knockbackStuds)
				end
			end
		end
	end
end

function ShoveSystem.init()
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end

	local request = Instance.new("RemoteEvent")
	request.Name = "ShoveRequest"
	request.Parent = folder
	local knockback = Instance.new("RemoteEvent")
	knockback.Name = "ShoveKnockback"
	knockback.Parent = folder
	knockRemote = knockback

	request.OnServerEvent:Connect(function(player: Player)
		-- Any arguments the client sent are ignored on purpose.
		handle(player, knockback)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
		lastShove[player] = nil
	end)
end

function ShoveSystem.start()
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ShoveKnockback") :: RemoteEvent
	task.spawn(function()
		while true do
			task.wait(0.4)
			local ok, err = pcall(botShoves, remote)
			if not ok then
				warn("[mog-wars] bot shove error: " .. tostring(err))
			end
		end
	end)
end

return ShoveSystem
