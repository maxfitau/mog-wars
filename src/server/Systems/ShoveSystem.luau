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
local ShoveRules = require(Shared:WaitForChild("ShoveRules"))
local BotService = require(script.Parent:WaitForChild("BotService"))
local CaptureSystem = require(script.Parent:WaitForChild("CaptureSystem"))
local PopupSystem = require(script.Parent:WaitForChild("PopupSystem"))

local ShoveSystem = {}

local lastRequest: { [Player]: number } = {}
local lastShove: { [Player]: number } = {}

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
	if targetBot then
		lastShove[player] = now
		player:SetAttribute("ShoveReadyAt", now + Config.shove.cooldownSeconds)
		local bx, bz = ShoveRules.direction(origin.X, origin.Z, targetBot.root.Position.X, targetBot.root.Position.Z)
		BotService.weaken(targetBot, now + Config.shove.penaltySeconds)
		BotService.knockback(targetBot, bx, bz, Config.shove.knockbackStuds)
		PopupSystem.send(player, "bonk", 1, "")
		return -- no contribution for shoving a bot
	end
	local target = if targetId then byId[targetId] else nil
	local targetRoot = if target then rootOf(target) else nil
	if not target or not targetRoot then
		return -- nothing in range: no cooldown is used
	end

	lastShove[player] = now
	player:SetAttribute("ShoveReadyAt", now + Config.shove.cooldownSeconds)
	target:SetAttribute("PushPenaltyUntil", now + Config.shove.penaltySeconds)

	local dx, dz = ShoveRules.direction(origin.X, origin.Z, targetRoot.Position.X, targetRoot.Position.Z)
	knockbackRemote:FireClient(target, dx, dz, Config.shove.knockbackStuds)
	PopupSystem.send(player, "bonk", 1, "") -- BONK! for the shover ...
	PopupSystem.send(target, "bonk", 2, "") -- ... and for whoever got bonked
	CaptureSystem.creditShove(player, target)
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
				if best then
					local root = rootOf(best)
					if root then
						local dx, dz = ShoveRules.direction(bot.root.Position.X, bot.root.Position.Z, root.Position.X, root.Position.Z)
						best:SetAttribute("PushPenaltyUntil", now + Config.shove.penaltySeconds)
						knockbackRemote:FireClient(best, dx, dz, Config.shove.knockbackStuds)
						PopupSystem.send(best, "bonk", 2, "")
					end
				elseif bestBot then
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
