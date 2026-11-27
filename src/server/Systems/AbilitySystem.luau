--!strict
-- The rank-unlocked abilities. NPC: Shove (ShoveSystem). Rookie: Glow-Up Dash (MovementSystem). From Sigma up, here:
--   Sigma    Mog Stare      a short beam that freezes ONE enemy for 1 s                       (8 s cooldown)
--   Chadlite Jawline Slam   jump + ground pound that knocks back everyone within ~10 studs   (10 s)
--   Chad     Hair Flip      a cone gust that pushes enemies back and off flags               (12 s)
--   Gigachad Mewing Shield  3 s immune to shove, stare and knockback, in a golden bubble     (18 s)
--   Mog God  Total Mog      enemies within ~20 studs are REDUCED TO NPC for 2 s: grey, half speed, cannot capture (30 s)
-- The client sends a bare request; the server checks the rank, the cooldown, that you are alive and the range, and works out
-- every effect itself. Moglings use the same abilities at the players' average rank (and wait a little longer). Also records
-- that an unlock card was shown. Server only; every number is in Pace.abilities.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Pace = require(Shared:WaitForChild("Pace"))
local BotService = require(script.Parent:WaitForChild("BotService"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local MovementSystem = require(script.Parent:WaitForChild("MovementSystem"))
local PopupSystem = require(script.Parent:WaitForChild("PopupSystem"))
local StealSystem = require(script.Parent:WaitForChild("StealSystem"))
local Events = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("Events"))
local NpcLook = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("NpcLook"))
local Shield = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("Shield"))

local AbilitySystem = {}

type Caster = { key: Instance, faction: number, root: BasePart, player: Player?, bot: BotService.Bot? }
type Target = { key: Instance, root: BasePart, player: Player?, bot: BotService.Bot? }

local remotes: { [string]: RemoteEvent } = {}
local lastUse: { [Instance]: { [string]: number } } = {}
local rng = Random.new()

local UNLOCK_RANK = {
	shove = Pace.abilities.shove.rank, dash = Pace.abilities.dash.rank, stare = Pace.abilities.stare.rank,
	slam = Pace.abilities.slam.rank, flip = Pace.abilities.flip.rank, shield = Pace.abilities.shield.rank, total = Pace.abilities.total.rank,
}
local READY_ATTRIBUTE = { stare = "StareReadyAt", slam = "SlamReadyAt", flip = "FlipReadyAt", shield = "ShieldReadyAt", total = "TotalReadyAt" }

local function now(): number
	return Workspace:GetServerTimeNow()
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

local function casterOfPlayer(player: Player): Caster?
	local root = playerRoot(player)
	local faction = player:GetAttribute("Faction")
	if not root or type(faction) ~= "number" then
		return nil
	end
	return { key = player, faction = faction, root = root, player = player, bot = nil }
end

local function enemiesOf(faction: number): { Target }
	local list: { Target } = {}
	for _, other in Players:GetPlayers() do
		local root = playerRoot(other)
		local otherFaction = other:GetAttribute("Faction")
		if root and type(otherFaction) == "number" and otherFaction ~= faction then
			table.insert(list, { key = other, root = root, player = other, bot = nil })
		end
	end
	for _, bot in BotService.list() do
		if bot.faction ~= faction then
			table.insert(list, { key = bot.model, root = bot.root, player = nil, bot = bot })
		end
	end
	return list
end

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- Push a target. A shielded target is not moved. Returns whether it worked.
local function knock(target: Target, dx: number, dz: number, studs: number, attacker: Caster?): boolean
	if Shield.active(target.key) then
		return false
	end
	local length = math.sqrt(dx * dx + dz * dz)
	if length < 0.01 then
		return false
	end
	dx, dz = dx / length, dz / length
	if target.player then
		local remote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("ShoveKnockback")
		if remote and remote:IsA("RemoteEvent") then
			remote:FireClient(target.player, dx, dz, studs)
		end
		StealSystem.noteHit(target.player, if attacker then attacker.player else nil)
	elseif target.bot then
		BotService.knockback(target.bot, dx, dz, studs)
	end
	return true
end

-- ---------- the abilities ----------

local function stare(caster: Caster): boolean
	local forward = Vector3.new(caster.root.CFrame.LookVector.X, 0, caster.root.CFrame.LookVector.Z)
	if forward.Magnitude < 0.1 then
		return false
	end
	forward = forward.Unit
	local best: Target? = nil
	local bestDistance = Pace.abilities.stare.range
	for _, target in enemiesOf(caster.faction) do
		local flat = Vector3.new(target.root.Position.X - caster.root.Position.X, 0, target.root.Position.Z - caster.root.Position.Z)
		if flat.Magnitude > 1 and flat.Magnitude < bestDistance and flat.Unit:Dot(forward) > 0.3 then
			best, bestDistance = target, flat.Magnitude
		end
	end
	if not best then
		return false -- nobody to stare at: no cooldown is used
	end
	if not Shield.active(best.key) then
		if best.player then
			MovementSystem.freeze(best.player, Pace.abilities.stare.freezeSeconds)
			StealSystem.noteHit(best.player, caster.player)
			PopupSystem.send(best.player, "announce", 1, "FROZEN BY A MOG STARE!")
		elseif best.bot then
			BotService.stun(best.bot, Pace.abilities.stare.freezeSeconds)
		end
		if caster.player then
			Events.fire(caster.player, "stare", 1)
		end
	end
	PopupSystem.fx("stare", caster.root.Position + Vector3.new(0, 1.5, 0), best.root.Position + Vector3.new(0, 1.5, 0))
	return true
end

local function slam(caster: Caster): boolean
	if caster.player then
		MovementSystem.launch(caster.player, Vector3.new(0, 62, 0)) -- the jump ...
	else
		caster.root.AssemblyLinearVelocity = Vector3.new(0, 62, 0)
	end
	task.delay(0.65, function() -- ... and the ground pound when you come down
		if not caster.root.Parent then
			return
		end
		local origin = caster.root.Position
		PopupSystem.fx("slam", origin, Pace.abilities.slam.radius)
		for _, target in enemiesOf(caster.faction) do
			if flatDistance(target.root.Position, origin) <= Pace.abilities.slam.radius and math.abs(target.root.Position.Y - origin.Y) < 12 then
				knock(target, target.root.Position.X - origin.X, target.root.Position.Z - origin.Z, Pace.abilities.slam.knockbackStuds, caster)
			end
		end
	end)
	return true
end

local function flip(caster: Caster): boolean
	local forward = Vector3.new(caster.root.CFrame.LookVector.X, 0, caster.root.CFrame.LookVector.Z)
	if forward.Magnitude < 0.1 then
		return false
	end
	forward = forward.Unit
	PopupSystem.fx("gust", caster.root.Position, forward)
	for _, target in enemiesOf(caster.faction) do
		local flat = Vector3.new(target.root.Position.X - caster.root.Position.X, 0, target.root.Position.Z - caster.root.Position.Z)
		if flat.Magnitude > 0.5 and flat.Magnitude <= Pace.abilities.flip.range and flat.Unit:Dot(forward) >= Pace.abilities.flip.coneDot then
			knock(target, forward.X, forward.Z, Pace.abilities.flip.knockbackStuds, caster)
		end
	end
	return true
end

local function shield(caster: Caster): boolean
	Shield.give(caster.key, Pace.abilities.shield.seconds)
	local bubble = Instance.new("Part")
	bubble.Name = "MewingShield"
	bubble.Shape = Enum.PartType.Ball
	bubble.Size = Vector3.new(9, 9, 9)
	bubble.Material = Enum.Material.Neon
	bubble.Color = Color3.fromRGB(255, 210, 80)
	bubble.Transparency = 0.7
	bubble.CanCollide = false
	bubble.CanQuery = false
	bubble.CanTouch = false
	bubble.Massless = true
	bubble.CFrame = caster.root.CFrame
	bubble.Parent = caster.root.Parent
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = caster.root
	weld.Part1 = bubble
	weld.Parent = bubble
	game:GetService("Debris"):AddItem(bubble, Pace.abilities.shield.seconds)
	PopupSystem.fx("shield", caster.root.Position, Pace.abilities.shield.seconds)
	return true
end

local function total(caster: Caster): boolean
	local origin = caster.root.Position
	PopupSystem.fx("total", origin, Pace.abilities.total.radius)
	for _, target in enemiesOf(caster.faction) do
		if flatDistance(target.root.Position, origin) <= Pace.abilities.total.radius and not Shield.active(target.key) then
			local character = target.root.Parent
			if character and character:IsA("Model") then
				NpcLook.apply(character, Pace.abilities.total.seconds)
			end
			target.key:SetAttribute("NpcUntil", now() + Pace.abilities.total.seconds) -- cannot capture while reduced to NPC
			if target.player then
				MovementSystem.slow(target.player, Pace.abilities.total.slow, Pace.abilities.total.seconds)
				StealSystem.noteHit(target.player, caster.player)
			elseif target.bot then
				local humanoid = target.bot.humanoid
				local original = humanoid.WalkSpeed
				if original > 0 then
					humanoid.WalkSpeed = original * Pace.abilities.total.slow
					task.delay(Pace.abilities.total.seconds, function()
						if humanoid.Parent and humanoid.WalkSpeed == original * Pace.abilities.total.slow then
							humanoid.WalkSpeed = original
						end
					end)
				end
			end
		end
	end
	return true
end

local ABILITIES: { [string]: (Caster) -> boolean } = { stare = stare, slam = slam, flip = flip, shield = shield, total = total }

local function use(caster: Caster, id: string, cooldownFactor: number): boolean
	local config = (Pace.abilities :: any)[id]
	local run = ABILITIES[id]
	if not config or not run then
		return false
	end
	local used = lastUse[caster.key] or {}
	lastUse[caster.key] = used
	local t = now()
	if t - (used[id] or -1000) < config.cooldownSeconds * cooldownFactor then
		return false
	end
	if not run(caster) then
		return false
	end
	used[id] = t
	if caster.player and READY_ATTRIBUTE[id] then
		caster.player:SetAttribute(READY_ATTRIBUTE[id], t + config.cooldownSeconds)
	end
	return true
end

local function averageRank(): number
	local sum, count = 0, 0
	for _, player in Players:GetPlayers() do
		local rank = player:GetAttribute("Rank")
		if type(rank) == "number" then
			sum += rank
			count += 1
		end
	end
	return if count > 0 then math.clamp(math.floor(sum / count + 0.5), 1, 7) else 1
end

-- Moglings use their abilities too: now and then, when it makes sense, at the players' average rank.
local function mogglingsAct()
	if Workspace:GetAttribute("WarPhase") ~= "War" then
		return
	end
	local rank = averageRank()
	for _, bot in BotService.list() do
		if rank >= 3 and bot.humanoid.WalkSpeed > 0 and rng:NextNumber() < 0.35 then
			local caster: Caster = { key = bot.model, faction = bot.faction, root = bot.root, player = nil, bot = bot }
			local enemies = enemiesOf(bot.faction)
			local nearest = math.huge
			local inRange = 0
			for _, target in enemies do
				local distance = flatDistance(target.root.Position, bot.root.Position)
				nearest = math.min(nearest, distance)
				if distance < 16 then
					inRange += 1
				end
			end
			local choices: { string } = {}
			if rank >= 3 and nearest < 30 then
				table.insert(choices, "stare")
			end
			if rank >= 4 and nearest < 8 then
				table.insert(choices, "slam")
			end
			if rank >= 5 and nearest < 18 then
				table.insert(choices, "flip")
			end
			if rank >= 6 and nearest < 10 then
				table.insert(choices, "shield")
			end
			if rank >= 7 and inRange >= 2 then
				table.insert(choices, "total")
			end
			if #choices > 0 then
				use(caster, choices[rng:NextInteger(1, #choices)], Pace.abilities.moglingCooldownFactor)
			end
		end
	end
end

function AbilitySystem.init()
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for _, name in { "StareRequest", "AbilityRequest", "UnlockSeen" } do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		remotes[name] = remote
	end
	local lastRequest: { [Player]: number } = {}
	local function request(player: Player, id: any)
		local t = now()
		if type(id) ~= "string" or t - (lastRequest[player] or -100) < 0.2 then
			return
		end
		lastRequest[player] = t
		local rank = player:GetAttribute("Rank")
		local needed = UNLOCK_RANK[id]
		if not needed or id == "dash" or id == "shove" or type(rank) ~= "number" or rank < needed or Workspace:GetAttribute("WarPhase") ~= "War" then
			return
		end
		local caster = casterOfPlayer(player)
		if caster then
			use(caster, id, 1)
		end
	end
	remotes.StareRequest.OnServerEvent:Connect(function(player: Player)
		request(player, "stare")
	end)
	remotes.AbilityRequest.OnServerEvent:Connect(request)
	remotes.UnlockSeen.OnServerEvent:Connect(function(player: Player, id: any)
		local rank = player:GetAttribute("Rank")
		if type(id) == "string" and UNLOCK_RANK[id] and type(rank) == "number" and rank >= UNLOCK_RANK[id] then
			DataService.markUnlockSeen(player, id)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastUse[player] = nil
		lastRequest[player] = nil
	end)
end

function AbilitySystem.start()
	task.spawn(function()
		while true do
			task.wait(1.2)
			local ok, err = pcall(mogglingsAct)
			if not ok then
				warn("[mog-wars] Mogling abilities: " .. tostring(err))
			end
		end
	end)
end

return AbilitySystem
