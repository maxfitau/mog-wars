--!strict
-- THE WEAPONS (server). The equipped weapon REPLACES Shove: the client sends Remotes.UseWeapon (optionally an aim direction and a
-- charge time) and the server decides everything. Checks, in order: payload types, spam rate, war running, the weapon is the one
-- this player has equipped AND owns (DataService), its cooldown (WeaponCatalog), alive character, then the effect.
-- SAME POWER BUDGET for all nine: rarity changes ONLY looks and sounds (the client draws them from Remotes.WeaponFx); the cooldown
-- is the balance lever and stars add at most +20 percent. Effects hit players AND Moglings. Knock-offs and traps are credited with
-- StealSystem.noteHit. MoglingWeapons calls WeaponSystem.use for Moglings, with the very same effects.
-- Also builds the held weapon model (welded to the right hand) and shows a glowing skin at 5 stars (visual only).
-- Remotes: UseWeapon (client to server), WeaponFx (server to clients: kind, weaponId, stars, a, b, n, owner).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("EconomyConfig"))
local WeaponCatalog = require(Shared:WaitForChild("WeaponCatalog"))
local WeaponRules = require(Shared:WaitForChild("WeaponRules"))
local BotService = require(script.Parent:WaitForChild("BotService"))
local CaptureSystem = require(script.Parent:WaitForChild("CaptureSystem"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local MovementSystem = require(script.Parent:WaitForChild("MovementSystem"))
local PopupSystem = require(script.Parent:WaitForChild("PopupSystem"))
local ShoveSystem = require(script.Parent:WaitForChild("ShoveSystem"))
local StealSystem = require(script.Parent:WaitForChild("StealSystem"))
local Events = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("Events"))
local Shield = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("Shield"))

local WeaponSystem = {}

export type Attacker = {
	key: Instance, -- the Player, or a Mogling's model (what Shield uses)
	player: Player?,
	bot: BotService.Bot?,
	root: BasePart,
	humanoid: Humanoid,
	faction: number,
}

type Target = { key: Instance, player: Player?, bot: BotService.Bot?, root: BasePart }

type Context = {
	att: Attacker,
	weapon: WeaponCatalog.Weapon,
	stars: number,
	ax: number, -- flat unit aim direction
	az: number,
	aimed: boolean, -- true when the aim was sent (or chosen for a Mogling), false when we fell back to the facing direction
	charge: number, -- seconds held (the gauntlet)
	now: number,
}

local lastRequest: { [Player]: number } = {}
local lastUse: { [Player]: number } = {}
local fxRemote: RemoteEvent? = nil

local WAR_ONLY = true
local MAX_DY = 12 -- targets more than this far above or below are on another level: out of reach

local function now(): number
	return Workspace:GetServerTimeNow()
end

-- ---------- who is who ----------

local function aliveParts(model: Model?): (Humanoid?, BasePart?)
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	local root = model and model:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return humanoid, root
	end
	return nil, nil
end

function WeaponSystem.attackerOfPlayer(player: Player): Attacker?
	local humanoid, root = aliveParts(player.Character)
	local faction = player:GetAttribute("Faction")
	if not humanoid or not root or type(faction) ~= "number" or faction == 0 then
		return nil
	end
	return { key = player, player = player, bot = nil, root = root, humanoid = humanoid, faction = faction }
end

function WeaponSystem.attackerOfBot(bot: BotService.Bot): Attacker?
	if not BotService.isAlive(bot) then
		return nil
	end
	return { key = bot.model, player = nil, bot = bot, root = bot.root, humanoid = bot.humanoid, faction = bot.faction }
end

-- Every living enemy of this attacker (players and Moglings) on roughly the same level.
local function enemiesOf(att: Attacker): { Target }
	local list: { Target } = {}
	local y = att.root.Position.Y
	for _, other in Players:GetPlayers() do
		local _, root = aliveParts(other.Character)
		local faction = other:GetAttribute("Faction")
		if other ~= att.player and root and type(faction) == "number" and faction ~= 0 and faction ~= att.faction and math.abs(root.Position.Y - y) <= MAX_DY then
			table.insert(list, { key = other, player = other, bot = nil, root = root })
		end
	end
	for _, bot in BotService.list() do
		if bot.model ~= att.key and bot.faction ~= att.faction and math.abs(bot.root.Position.Y - y) <= MAX_DY then
			table.insert(list, { key = bot.model, player = nil, bot = bot, root = bot.root })
		end
	end
	return list
end

local function pointsOf(targets: { Target }): { WeaponRules.Point }
	local points: { WeaponRules.Point } = {}
	for _, target in targets do
		table.insert(points, { x = target.root.Position.X, z = target.root.Position.Z })
	end
	return points
end

-- ---------- effects on one target ----------

local function sendFx(kind: string, weapon: WeaponCatalog.Weapon, stars: number, a: Vector3, b: Vector3, n: number, owner: Instance?)
	if fxRemote then
		fxRemote:FireAllClients(kind, weapon.id, stars, a, b, n, owner)
	end
end

-- Bounce a push back at the attacker (Mirror Shield).
local function bounceBack(att: Attacker, dx: number, dz: number, studs: number, victim: Player, t: number)
	local attackerPlayer = att.player
	if attackerPlayer then
		if not Shield.active(attackerPlayer) then
			attackerPlayer:SetAttribute("PushPenaltyUntil", t + Config.shove.penaltySeconds)
			ShoveSystem.knockPlayer(attackerPlayer, -dx, -dz, studs)
			StealSystem.noteHit(attackerPlayer, victim)
			PopupSystem.send(attackerPlayer, "announce", 1, "REFLECTED!")
		end
	elseif att.bot then
		BotService.weaken(att.bot, t + Config.shove.penaltySeconds)
		BotService.knockback(att.bot, -dx, -dz, studs)
	end
	PopupSystem.send(victim, "announce", 1, "REFLECTED!")
end

-- Push one target away from (dx, dz) by `studs`. Returns true if it landed.
local function hitTarget(ctx: Context, target: Target, dx: number, dz: number, studs: number): boolean
	local att = ctx.att
	studs = WeaponRules.clampStuds(studs)
	if studs <= 0 or (dx == 0 and dz == 0) then
		return false
	end
	local attackerPlayer = att.player
	if Shield.active(target.key) then -- Mewing Shield: immune to knockback
		if attackerPlayer then
			PopupSystem.send(attackerPlayer, "announce", 1, "BLOCKED!")
		end
		return false
	end
	local victim = target.player
	if victim then
		if WeaponRules.reflecting(ctx.now, victim:GetAttribute("ReflectUntil")) then
			bounceBack(att, dx, dz, studs, victim, ctx.now)
			return false
		end
		victim:SetAttribute("PushPenaltyUntil", ctx.now + Config.shove.penaltySeconds)
		ShoveSystem.knockPlayer(victim, dx, dz, studs)
		PopupSystem.send(victim, "bonk", 2, "")
		StealSystem.noteHit(victim, attackerPlayer) -- knock-offs and traps are credited to the attacker
		if attackerPlayer then
			PopupSystem.send(attackerPlayer, "bonk", 1, "")
			CaptureSystem.creditShove(attackerPlayer, victim)
			Events.fire(attackerPlayer, "shove_player", 1)
		end
		if MovementSystem.isFrozen(victim) then
			StealSystem.shoveFrozen(victim, attackerPlayer)
		end
	else
		local bot = target.bot
		if not bot then
			return false
		end
		BotService.weaken(bot, ctx.now + Config.shove.penaltySeconds)
		BotService.knockback(bot, dx, dz, studs)
		if studs > 30 and BotService.isAlive(bot) then -- BotService caps at 30 studs: a bigger punch sets the speed itself
			bot.root.AssemblyLinearVelocity = Vector3.new(dx * studs * 3.5, 25, dz * studs * 3.5)
		end
		if attackerPlayer then
			PopupSystem.send(attackerPlayer, "bonk", 1, "")
			Events.fire(attackerPlayer, "shove_mogling", 1)
		end
	end
	sendFx("hit", ctx.weapon, ctx.stars, target.root.Position, Vector3.new(dx, 0, dz), studs, nil)
	return true
end

local function dirFromAttacker(att: Attacker, target: Target): (number, number)
	local origin = att.root.Position
	local position = target.root.Position
	local dx, dz = WeaponRules.flat(origin.X, origin.Z, position.X, position.Z)
	if dx == 0 and dz == 0 then
		local look = att.root.CFrame.LookVector
		return look.X, look.Z
	end
	return dx, dz
end

local function groundBelow(position: Vector3, ignore: Instance?): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	if ignore then
		params.FilterDescendantsInstances = { ignore }
	end
	local result = Workspace:Raycast(position + Vector3.new(0, 4, 0), Vector3.new(0, -60, 0), params)
	if result then
		return result.Position
	end
	return position - Vector3.new(0, 3, 0)
end

-- ---------- the nine weapons ----------

local effects: { [string]: (Context) -> boolean } = {}

-- Jawline Hammer: slow swing, one target, shoves 2x as far as Shove. Nothing in reach: no cooldown used.
effects.hammer = function(ctx)
	local att, p = ctx.att, ctx.weapon.params
	local origin = att.root.Position
	local reach = WeaponRules.hammerReach(p, ctx.stars)
	local targets = enemiesOf(att)
	local index = WeaponRules.pickNearest(origin.X, origin.Z, ctx.ax, ctx.az, WeaponRules.HAMMER_ANGLE, reach, pointsOf(targets))
	sendFx("hammer", ctx.weapon, ctx.stars, origin, Vector3.new(ctx.ax, 0, ctx.az) * reach, 0, att.root.Parent)
	if not index then
		return false
	end
	local target = targets[index]
	local dx, dz = dirFromAttacker(att, target)
	hitTarget(ctx, target, dx, dz, WeaponRules.hammerKnock(p, ctx.stars, Config.shove.knockbackStuds))
	return true
end

-- Mewing Fan: a wide gust cone that pushes every enemy in it.
effects.gust = function(ctx)
	local att, p = ctx.att, ctx.weapon.params
	local origin = att.root.Position
	local reach = WeaponRules.gustReach(p, ctx.stars)
	local angle = WeaponRules.gustAngle(p)
	local studs = WeaponRules.gustKnock(p, ctx.stars, Config.shove.knockbackStuds)
	sendFx("gust", ctx.weapon, ctx.stars, origin, Vector3.new(ctx.ax, 0, ctx.az) * reach, angle, att.root.Parent)
	for _, target in enemiesOf(att) do
		local position = target.root.Position
		if WeaponRules.inCone(origin.X, origin.Z, ctx.ax, ctx.az, position.X, position.Z, reach, angle) then
			local dx, dz = dirFromAttacker(att, target)
			hitTarget(ctx, target, dx, dz, studs)
		end
	end
	return true
end

-- Sigma Shades: sunglasses fly out along the aim and come back to you; they only hit on the way back.
effects.boomerang = function(ctx)
	local att, p = ctx.att, ctx.weapon.params
	local origin = att.root.Position
	local aim = Vector3.new(ctx.ax, 0, ctx.az)
	local range = WeaponRules.boomerangRange(p, ctx.stars)
	local duration = WeaponRules.boomerangDuration(range)
	local studs = WeaponRules.boomerangKnock(p, ctx.stars, Config.shove.knockbackStuds)
	local turn = origin + aim * range
	sendFx("boomerang", ctx.weapon, ctx.stars, origin, aim * range, duration, att.root.Parent)
	task.spawn(function()
		local started = now()
		local hitAlready: { [Instance]: boolean } = {}
		while true do
			RunService.Heartbeat:Wait()
			local leg, fraction = WeaponRules.boomerangState(now() - started, duration)
			if leg == 3 or att.root.Parent == nil or att.humanoid.Health <= 0 then
				return
			end
			if leg == 2 then
				local home = att.root.Position
				local position = turn:Lerp(home, fraction)
				local backX, backZ = WeaponRules.flat(position.X, position.Z, home.X, home.Z)
				if backX == 0 and backZ == 0 then
					backX, backZ = -ctx.ax, -ctx.az
				end
				for _, target in enemiesOf(att) do
					if not hitAlready[target.key] then
						local there = target.root.Position
						local flat = Vector3.new(there.X - position.X, 0, there.Z - position.Z).Magnitude
						if flat <= WeaponRules.BOOMERANG_HIT_RADIUS and math.abs(there.Y - position.Y) <= 6 then
							hitAlready[target.key] = true
							ctx.now = now()
							hitTarget(ctx, target, backX, backZ, studs)
						end
					end
				end
			end
		end
	end)
	return true
end

-- Rizz Rose: thrown at the nearest enemy in the aim; for a second they walk toward you. No target: no cooldown used.
effects.rose = function(ctx)
	local att, p = ctx.att, ctx.weapon.params
	local origin = att.root.Position
	local range = WeaponRules.roseRange(p, ctx.stars)
	local targets = enemiesOf(att)
	local index = WeaponRules.pickNearest(origin.X, origin.Z, ctx.ax, ctx.az, WeaponRules.ROSE_ANGLE, range, pointsOf(targets))
	if not index then
		sendFx("rose", ctx.weapon, ctx.stars, origin, origin + Vector3.new(ctx.ax, 0, ctx.az) * range, range / WeaponRules.ROSE_SPEED, att.root.Parent)
		return false
	end
	local target = targets[index]
	local travel = (target.root.Position - origin).Magnitude / WeaponRules.ROSE_SPEED
	local seconds = WeaponRules.roseSeconds(p, ctx.stars)
	sendFx("rose", ctx.weapon, ctx.stars, origin, target.root.Position, travel, att.root.Parent)
	task.delay(travel, function()
		if att.root.Parent == nil or not target.root.Parent then
			return
		end
		local attackerPlayer = att.player
		if Shield.active(target.key) then
			if attackerPlayer then
				PopupSystem.send(attackerPlayer, "announce", 1, "BLOCKED!")
			end
			return
		end
		sendFx("hit", ctx.weapon, ctx.stars, target.root.Position, Vector3.zero, 0, nil)
		local victim = target.player
		local bot = target.bot
		if victim then
			StealSystem.noteHit(victim, attackerPlayer)
			PopupSystem.send(victim, "announce", 1, "SMITTEN!")
			if fxRemote then
				fxRemote:FireClient(victim, "pull", ctx.weapon.id, ctx.stars, att.root.Position, Vector3.zero, seconds, att.root.Parent)
			end
		elseif bot then
			task.spawn(function()
				local untilTime = now() + seconds
				while now() < untilTime and BotService.isAlive(bot) and att.root.Parent ~= nil do
					BotService.moveTo(bot, att.root.Position, 0.4)
					task.wait(0.2)
				end
			end)
		end
		if attackerPlayer then
			Events.fire(attackerPlayer, if victim then "shove_player" else "shove_mogling", 1)
		end
	end)
	return true
end

-- Glow-Up Mist: a slippery sparkle puddle ahead of you; enemies inside slide outward for a few seconds.
effects.mist = function(ctx)
	local att, p = ctx.att, ctx.weapon.params
	local origin = att.root.Position
	local cx, cz = WeaponRules.mistCentre(p, ctx.stars, origin.X, origin.Z, ctx.ax, ctx.az)
	local radius = WeaponRules.mistRadius(p, ctx.stars)
	local seconds = WeaponRules.mistSeconds(p)
	local centre = groundBelow(Vector3.new(cx, origin.Y, cz), att.root.Parent)
	sendFx("mist", ctx.weapon, ctx.stars, centre, Vector3.new(radius, seconds, 0), seconds, att.root.Parent)
	task.spawn(function()
		local untilTime = now() + seconds
		while now() < untilTime and att.root.Parent ~= nil do
			for _, target in enemiesOf(att) do
				local position = target.root.Position
				if WeaponRules.inCircle(cx, cz, position.X, position.Z, radius) and math.abs(position.Y - centre.Y) <= 8 and not Shield.active(target.key) then
					local dx, dz = WeaponRules.mistDrift(cx, cz, position.X, position.Z)
					local victim = target.player
					local bot = target.bot
					if victim then
						StealSystem.noteHit(victim, att.player)
						if fxRemote then
							fxRemote:FireClient(victim, "slip", ctx.weapon.id, ctx.stars, centre, Vector3.new(dx, 0, dz) * WeaponRules.MIST_DRIFT, 0.5, nil)
						end
					elseif bot and BotService.isAlive(bot) then
						local velocity = bot.root.AssemblyLinearVelocity
						bot.root.AssemblyLinearVelocity = Vector3.new(dx * WeaponRules.MIST_DRIFT * 1.5, velocity.Y, dz * WeaponRules.MIST_DRIFT * 1.5)
					end
				end
			end
			task.wait(0.3)
		end
	end)
	return true
end

-- Mirror Shield: for a few seconds any shove (or weapon push) that would hit you bounces back. ShoveSystem reads ReflectUntil.
effects.mirror = function(ctx)
	local att = ctx.att
	local player = att.player
	if not player then
		return false -- Moglings never carry one
	end
	local seconds = WeaponRules.reflectSeconds(ctx.weapon.params, ctx.stars)
	player:SetAttribute("ReflectUntil", ctx.now + seconds)
	sendFx("mirror", ctx.weapon, ctx.stars, att.root.Position, Vector3.zero, seconds, att.root.Parent)
	return true
end

-- Protein Shaker: a shockwave pushes every enemy around you outward, and YOU get a speed boost.
effects.shaker = function(ctx)
	local att, p = ctx.att, ctx.weapon.params
	local origin = att.root.Position
	local radius = WeaponRules.shakerRadius(p, ctx.stars)
	local studs = WeaponRules.shakerKnock(p, ctx.stars, Config.shove.knockbackStuds)
	sendFx("shaker", ctx.weapon, ctx.stars, origin, Vector3.zero, radius, att.root.Parent)
	for _, target in enemiesOf(att) do
		local position = target.root.Position
		if WeaponRules.inCircle(origin.X, origin.Z, position.X, position.Z, radius) then
			local dx, dz = dirFromAttacker(att, target)
			hitTarget(ctx, target, dx, dz, studs)
		end
	end
	local player = att.player
	if player then
		MovementSystem.boost(player, "weapon_shaker", WeaponRules.shakerBoost(p, ctx.stars), WeaponRules.shakerSeconds(p))
	end
	return true
end

-- Main Character Mic: everyone nearby freezes and stares at you for a moment.
effects.mic = function(ctx)
	local att, p = ctx.att, ctx.weapon.params
	local origin = att.root.Position
	local radius = WeaponRules.micRadius(p, ctx.stars)
	local seconds = WeaponRules.micSeconds(p, ctx.stars)
	sendFx("mic", ctx.weapon, ctx.stars, origin, Vector3.zero, radius, att.root.Parent)
	for _, target in enemiesOf(att) do
		local position = target.root.Position
		if WeaponRules.inCircle(origin.X, origin.Z, position.X, position.Z, radius) and not Shield.active(target.key) then
			local victim = target.player
			local bot = target.bot
			if victim then
				MovementSystem.freeze(victim, seconds)
				StealSystem.noteHit(victim, att.player)
				PopupSystem.send(victim, "announce", 1, "STARING AT THE MAIN CHARACTER!")
				if fxRemote then
					fxRemote:FireClient(victim, "stare", ctx.weapon.id, ctx.stars, origin, Vector3.zero, seconds, att.root.Parent)
				end
			elseif bot and BotService.isAlive(bot) then
				BotService.stun(bot, seconds)
				bot.model:PivotTo(CFrame.lookAt(position, Vector3.new(origin.X, position.Y, origin.Z)))
			end
		end
	end
	return true
end

-- Gigachad Gauntlet: a charged giant punch at the nearest enemy in front, with a huge knockback. A miss uses no cooldown.
effects.gauntlet = function(ctx)
	local att, p = ctx.att, ctx.weapon.params
	local origin = att.root.Position
	local reach = WeaponRules.gauntletReach(p, ctx.stars)
	local fraction = WeaponRules.chargeFraction(ctx.charge, p)
	local targets = enemiesOf(att)
	local index = WeaponRules.pickNearest(origin.X, origin.Z, ctx.ax, ctx.az, WeaponRules.GAUNTLET_ANGLE, reach, pointsOf(targets))
	sendFx("gauntlet", ctx.weapon, ctx.stars, origin, Vector3.new(ctx.ax, 0, ctx.az) * reach, if index then fraction else 0, att.root.Parent)
	if not index then
		return false
	end
	local target = targets[index]
	local dx, dz = dirFromAttacker(att, target)
	hitTarget(ctx, target, dx, dz, WeaponRules.gauntletKnock(p, ctx.stars, Config.shove.knockbackStuds, fraction))
	return true
end

-- Use a weapon as this attacker (a player or a Mogling). The aim is a flat unit direction, or nil to use the facing direction.
-- Returns true if the weapon was used (the caller then starts the cooldown).
function WeaponSystem.use(att: Attacker, weapon: WeaponCatalog.Weapon, stars: number, aimX: number?, aimZ: number?, charge: number): boolean
	local effect = effects[weapon.kind]
	if not effect then
		return false
	end
	local aimed = aimX ~= nil and aimZ ~= nil
	local ax: number = 0
	local az: number = -1
	if aimX ~= nil and aimZ ~= nil then
		ax, az = aimX, aimZ
	else
		local look = att.root.CFrame.LookVector
		local flat = math.sqrt(look.X * look.X + look.Z * look.Z)
		if flat >= 0.05 then
			ax, az = look.X / flat, look.Z / flat
		end
	end
	local ctx: Context = { att = att, weapon = weapon, stars = math.clamp(math.floor(stars), 1, 5), ax = ax, az = az, aimed = aimed, charge = charge, now = now() }
	local ok, result = pcall(effect, ctx)
	if not ok then
		warn("[mog-wars] weapon " .. weapon.id .. " failed: " .. tostring(result))
		return false
	end
	return result
end

-- ---------- the request (players) ----------

local function onRequest(player: Player, aim: any, charge: any)
	local t = now()
	if WeaponRules.tooFast(t, lastRequest[player] or -1000) then
		return
	end
	lastRequest[player] = t
	if WAR_ONLY and Workspace:GetAttribute("WarPhase") ~= "War" then
		return
	end

	-- payload: aim is nil or a unit Vector3; charge is nil or a finite number
	local ax: number? = nil
	local az: number? = nil
	if aim ~= nil then
		if typeof(aim) ~= "Vector3" then
			return
		end
		local vector = aim :: Vector3
		ax, az = WeaponRules.cleanAim(vector.X, vector.Y, vector.Z)
		if ax == nil or az == nil then
			return
		end
	end
	if charge ~= nil and type(charge) ~= "number" then
		return
	end

	-- the player must own and have equipped the weapon
	local data = DataService.get(player)
	if not data then
		return
	end
	local id = data.equippedWeapon
	local weapon = WeaponCatalog.byId[id]
	local stars = data.collection[id]
	if not weapon or type(stars) ~= "number" or stars < 1 then
		return
	end
	local cleanCharge = 0
	if charge ~= nil then
		local checked = WeaponRules.cleanCharge(charge :: number, weapon.params.charge or 0)
		if checked == nil then
			return
		end
		cleanCharge = checked
	end

	if not WeaponRules.cooldownReady(t, lastUse[player] or -1000, weapon.cooldown) then
		return
	end
	local att = WeaponSystem.attackerOfPlayer(player)
	if not att then
		return
	end
	if WeaponSystem.use(att, weapon, stars, ax, az, cleanCharge) then
		lastUse[player] = t
		player:SetAttribute("WeaponReadyAt", t + weapon.cooldown)
	else
		lastUse[player] = t - weapon.cooldown + 0.7 -- a miss costs a short 0.7 s wait, so nobody can spam effects at everyone
	end
end

-- ---------- held weapon models (simple chunky parts welded to the right hand; ART.md: no Plastic) ----------

type Piece = { shape: string, size: Vector3, pos: Vector3, rot: Vector3, material: Enum.Material, rgb: { number }?, glow: boolean?, alpha: number? }

local WOOD = { 120, 84, 52 }
local METAL = { 150, 150, 160 }
local GOLD = { 255, 200, 60 }
local DARK = { 45, 45, 60 }
local GREEN = { 90, 170, 70 }

local function piece(shape: string, size: Vector3, pos: Vector3, rot: Vector3?, material: Enum.Material, rgb: { number }?, alpha: number?): Piece
	return { shape = shape, size = size, pos = pos, rot = rot or Vector3.zero, material = material, rgb = rgb, alpha = alpha }
end

-- A part is "Cylinder" along its X axis, so rot z = 90 turns it to run along the weapon (Y). Weapons point along +Y from the grip.
local ALONG = Vector3.new(0, 0, 90)

local MODELS: { [string]: { Piece } } = {
	hammer = {
		piece("Cylinder", Vector3.new(3.2, 0.5, 0.5), Vector3.new(0, 1.4, 0), ALONG, Enum.Material.Wood, WOOD),
		piece("Block", Vector3.new(1.2, 1.2, 2.2), Vector3.new(0, 3.2, 0), nil, Enum.Material.Metal, nil),
		piece("Ball", Vector3.new(1.4, 1.4, 1.4), Vector3.new(0, 3.2, 1.2), nil, Enum.Material.Marble, nil),
		piece("Ball", Vector3.new(1.4, 1.4, 1.4), Vector3.new(0, 3.2, -1.2), nil, Enum.Material.Marble, nil),
	},
	gust = {
		piece("Cylinder", Vector3.new(1.8, 0.45, 0.45), Vector3.new(0, 0.7, 0), ALONG, Enum.Material.Wood, WOOD),
		piece("Block", Vector3.new(1, 2.6, 0.4), Vector3.new(0, 2.6, 0), nil, Enum.Material.Fabric, nil),
		piece("Block", Vector3.new(1, 2.6, 0.4), Vector3.new(-0.84, 2.5, 0), Vector3.new(0, 0, 40), Enum.Material.Fabric, nil),
		piece("Block", Vector3.new(1, 2.6, 0.4), Vector3.new(0.84, 2.5, 0), Vector3.new(0, 0, -40), Enum.Material.Fabric, nil),
	},
	boomerang = {
		piece("Cylinder", Vector3.new(1.6, 0.45, 0.45), Vector3.new(0, 0.8, 0), ALONG, Enum.Material.Metal, DARK),
		piece("Block", Vector3.new(0.6, 0.4, 0.5), Vector3.new(0, 2.2, 0), nil, Enum.Material.Metal, DARK),
		piece("Block", Vector3.new(1.6, 1.2, 0.5), Vector3.new(-1.1, 2.2, 0), nil, Enum.Material.Glass, nil, 0.2),
		piece("Block", Vector3.new(1.6, 1.2, 0.5), Vector3.new(1.1, 2.2, 0), nil, Enum.Material.Glass, nil, 0.2),
		piece("Block", Vector3.new(0.4, 0.4, 0.6), Vector3.new(-1.5, 2.5, 0), nil, Enum.Material.Neon, { 255, 255, 255 }),
	},
	rose = {
		piece("Cylinder", Vector3.new(3, 0.4, 0.4), Vector3.new(0, 1.5, 0), ALONG, Enum.Material.Grass, GREEN),
		piece("Ball", Vector3.new(1.5, 1.5, 1.5), Vector3.new(0, 3.3, 0), nil, Enum.Material.Fabric, nil),
		piece("Ball", Vector3.new(0.9, 0.9, 0.9), Vector3.new(0.8, 3.1, 0), nil, Enum.Material.Fabric, nil),
		piece("Ball", Vector3.new(0.9, 0.9, 0.9), Vector3.new(-0.8, 3.1, 0), nil, Enum.Material.Fabric, nil),
		piece("Block", Vector3.new(0.9, 0.4, 0.5), Vector3.new(0.6, 1.8, 0), Vector3.new(0, 0, -35), Enum.Material.Grass, GREEN),
	},
	mist = {
		piece("Cylinder", Vector3.new(2.2, 1.1, 1.1), Vector3.new(0, 1.1, 0), ALONG, Enum.Material.Glass, nil, 0.25),
		piece("Cylinder", Vector3.new(0.7, 0.8, 0.8), Vector3.new(0, 2.45, 0), ALONG, Enum.Material.Metal, GOLD),
		piece("Block", Vector3.new(0.5, 0.5, 0.9), Vector3.new(0, 2.95, 0.3), nil, Enum.Material.Metal, GOLD),
		piece("Ball", Vector3.new(0.5, 0.5, 0.5), Vector3.new(0.5, 3.4, 0.8), nil, Enum.Material.Neon, nil),
	},
	mirror = {
		piece("Cylinder", Vector3.new(1.2, 0.45, 0.45), Vector3.new(0, 0.5, 0), ALONG, Enum.Material.Metal, METAL),
		piece("Cylinder", Vector3.new(0.5, 3.6, 3.6), Vector3.new(0, 2.4, 0), ALONG, Enum.Material.Metal, GOLD),
		piece("Cylinder", Vector3.new(0.7, 3, 3), Vector3.new(0, 2.4, 0), ALONG, Enum.Material.Metal, nil),
	},
	shaker = {
		piece("Cylinder", Vector3.new(2.4, 1.4, 1.4), Vector3.new(0, 1.4, 0), ALONG, Enum.Material.Glass, nil, 0.2),
		piece("Cylinder", Vector3.new(1.2, 1.1, 1.1), Vector3.new(0, 1, 0), ALONG, Enum.Material.Neon, nil),
		piece("Cylinder", Vector3.new(0.6, 1.5, 1.5), Vector3.new(0, 2.9, 0), ALONG, Enum.Material.Metal, METAL),
	},
	mic = {
		piece("Cylinder", Vector3.new(2.2, 0.5, 0.5), Vector3.new(0, 1.1, 0), ALONG, Enum.Material.Metal, DARK),
		piece("Ball", Vector3.new(1.5, 1.5, 1.5), Vector3.new(0, 2.7, 0), nil, Enum.Material.Metal, nil),
		piece("Cylinder", Vector3.new(0.4, 1.7, 1.7), Vector3.new(0, 2.7, 0), ALONG, Enum.Material.Neon, GOLD),
	},
	gauntlet = {
		piece("Cylinder", Vector3.new(1.8, 1.5, 1.5), Vector3.new(0, 0.9, 0), ALONG, Enum.Material.Metal, nil),
		piece("Block", Vector3.new(2, 1.8, 2), Vector3.new(0, 2.6, 0), nil, Enum.Material.Metal, nil),
		piece("Ball", Vector3.new(0.7, 0.7, 0.7), Vector3.new(-0.6, 3.6, 0), nil, Enum.Material.Metal, GOLD),
		piece("Ball", Vector3.new(0.7, 0.7, 0.7), Vector3.new(0, 3.6, 0), nil, Enum.Material.Metal, GOLD),
		piece("Ball", Vector3.new(0.7, 0.7, 0.7), Vector3.new(0.6, 3.6, 0), nil, Enum.Material.Metal, GOLD),
	},
}

local function colorOf(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function buildModel(weapon: WeaponCatalog.Weapon, stars: number): Model
	local model = Instance.new("Model")
	model.Name = "HeldWeapon"
	model:SetAttribute("WeaponId", weapon.id)
	model:SetAttribute("Stars", stars)
	local grip = Instance.new("Part")
	grip.Name = "Grip"
	grip.Size = Vector3.new(0.5, 0.5, 0.5)
	grip.Material = Enum.Material.Wood
	grip.Color = colorOf(WOOD)
	grip.CanCollide = false
	grip.CanQuery = false
	grip.CanTouch = false
	grip.Massless = true
	grip.CFrame = CFrame.new()
	grip.Parent = model
	model.PrimaryPart = grip
	local main = colorOf(weapon.rgb)
	for _, spec in MODELS[weapon.kind] or {} do
		local part = Instance.new("Part")
		part.Name = "Piece"
		part.Shape = (Enum.PartType :: any)[spec.shape] :: Enum.PartType
		part.Size = spec.size
		part.Material = spec.material
		part.Color = if spec.rgb then colorOf(spec.rgb) else main
		part.Transparency = spec.alpha or 0
		if spec.material == Enum.Material.Metal and not spec.rgb then
			part.Reflectance = 0.2
		end
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.CFrame = CFrame.new(spec.pos) * CFrame.Angles(math.rad(spec.rot.X), math.rad(spec.rot.Y), math.rad(spec.rot.Z))
		part.Parent = model
		local weld = Instance.new("Weld")
		weld.Part0 = grip
		weld.Part1 = part
		weld.C0 = grip.CFrame:ToObjectSpace(part.CFrame)
		weld.Parent = part
	end
	-- looks only: Rare and up sparkle, Legendary and up glow, 5 stars wear a glowing gold skin
	local tier = WeaponRules.visualTier(weapon.rarity)
	if tier >= 2 then
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Name = "Sparkle"
		sparkle.Rate = if tier >= 3 then 7 else 4
		sparkle.Lifetime = NumberRange.new(0.6, 1)
		sparkle.Speed = NumberRange.new(0.5, 1.5)
		sparkle.SpreadAngle = Vector2.new(180, 180)
		sparkle.Size = NumberSequence.new(0.35, 0)
		sparkle.LightEmission = 0.8
		sparkle.Color = ColorSequence.new(main)
		sparkle.Parent = grip
	end
	if tier >= 3 or WeaponRules.glowSkin(stars) then
		local light = Instance.new("PointLight")
		light.Name = "Glow"
		light.Color = if WeaponRules.glowSkin(stars) then colorOf(GOLD) else main
		light.Range = if WeaponRules.glowSkin(stars) then 10 else 7
		light.Brightness = 1
		light.Parent = grip
	end
	if WeaponRules.glowSkin(stars) then
		local shine = Instance.new("ParticleEmitter")
		shine.Name = "GoldShine"
		shine.Rate = 6
		shine.Lifetime = NumberRange.new(0.5, 0.9)
		shine.Speed = NumberRange.new(0.5, 1)
		shine.SpreadAngle = Vector2.new(180, 180)
		shine.Size = NumberSequence.new(0.3, 0)
		shine.LightEmission = 1
		shine.Color = ColorSequence.new(colorOf(GOLD))
		shine.Parent = grip
	end
	return model
end

local function handOf(character: Model): BasePart?
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm") or character:FindFirstChild("HumanoidRootPart")
	if hand and hand:IsA("BasePart") then
		return hand
	end
	return nil
end

-- Show this weapon in a character's right hand (replacing whatever is there). Players and Moglings both use this.
function WeaponSystem.attachModel(character: Model, weapon: WeaponCatalog.Weapon, stars: number)
	local existing = character:FindFirstChild("HeldWeapon")
	if existing and existing:GetAttribute("WeaponId") == weapon.id and existing:GetAttribute("Stars") == stars then
		return
	end
	if existing then
		existing:Destroy()
	end
	local hand = handOf(character)
	if not hand then
		return
	end
	local model = buildModel(weapon, stars)
	local grip = model.PrimaryPart :: BasePart
	-- the weapon points along the hand's forward direction (-Z) from just below the palm
	local drop = if hand.Name == "RightHand" then 0.3 elseif hand.Name == "Right Arm" then 0.9 else 0
	local offset = CFrame.new(0, -drop, -0.1) * CFrame.Angles(math.rad(-90), 0, 0)
	model:PivotTo(hand.CFrame * offset)
	model.Parent = character
	local weld = Instance.new("Weld")
	weld.Name = "HandWeld"
	weld.Part0 = hand
	weld.Part1 = grip
	weld.C0 = offset
	weld.Parent = grip
end

function WeaponSystem.detachModel(character: Model)
	local existing = character:FindFirstChild("HeldWeapon")
	if existing then
		existing:Destroy()
	end
end

local function refreshHeld(player: Player)
	local character = player.Character
	if not character or not character.Parent then
		return
	end
	local id = player:GetAttribute("Weapon")
	local weapon = if type(id) == "string" then WeaponCatalog.byId[id] else nil
	if not weapon then
		WeaponSystem.detachModel(character)
		return
	end
	local stars = player:GetAttribute("WeaponStars")
	WeaponSystem.attachModel(character, weapon, if type(stars) == "number" then stars else 1)
end

local function watchPlayer(player: Player)
	local function onCharacter(character: Model)
		task.spawn(function()
			character:WaitForChild("Humanoid", 10)
			if not character:FindFirstChild("RightHand") then
				character:WaitForChild("RightHand", 5)
			end
			refreshHeld(player)
		end)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
	player:GetAttributeChangedSignal("Weapon"):Connect(function()
		refreshHeld(player)
	end)
	player:GetAttributeChangedSignal("WeaponStars"):Connect(function()
		refreshHeld(player)
	end)
end

function WeaponSystem.init()
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	local request = Instance.new("RemoteEvent")
	request.Name = "UseWeapon"
	request.Parent = folder
	local fx = Instance.new("RemoteEvent")
	fx.Name = "WeaponFx"
	fx.Parent = folder
	fxRemote = fx
	request.OnServerEvent:Connect(onRequest)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
		lastUse[player] = nil
	end)
end

function WeaponSystem.start()
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)
end

return WeaponSystem
