--!strict
-- Mog combat (aura blasts, ego, mogging). The server decides EVERYTHING: the client only says "I fired toward this direction".
-- Every shot is checked in this order: rate limit, types, war running, alive and not on Training Island, weapon
-- unlocked, then CombatRules.canFire (shield, reload, ammo, fire interval). The server keeps the ammo, makes the
-- ray(s) itself from the shooter's head, and applies damage. Bots use the same ego, shield and mog code.
-- Every hit pays a little aura (with a combo); a mog pays aura and Mog Points (half for a bot), assists, streaks,
-- the kill feed, AURA RUSH (a short speed boost) and a defend bonus. A mogged player turns grey: REDUCED TO NPC.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatRules = require(Shared:WaitForChild("CombatRules"))
local FactionRules = require(Shared:WaitForChild("FactionRules"))
local Weapons = require(Shared:WaitForChild("Weapons"))
local BotService = require(script.Parent:WaitForChild("BotService"))
local CaptureSystem = require(script.Parent:WaitForChild("CaptureSystem"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local PopupSystem = require(script.Parent:WaitForChild("PopupSystem"))
local MovementSystem = require(script.Parent:WaitForChild("MovementSystem"))
local Pace = require(Shared:WaitForChild("Pace"))
local Stats = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("Stats"))

local CombatSystem = {}

local combat = Weapons.combat

type Combatant = {
	id: number, -- user id, or the bot's negative id
	player: Player?,
	bot: BotService.Bot?,
	health: number,
	shieldUntil: number,
	streak: number,
	combo: number, -- hits in a row, each within the combo window of the last
	lastHitAt: number,
	log: { [number]: { time: number, amount: number } }, -- who hurt me lately
	lastPaid: { [number]: number }, -- victim id -> time I was last paid for mogging them
	weapon: string,
	ammo: { [string]: number },
	reloadingUntil: number,
	reloadToken: number,
	lastFire: number,
	requestTimes: { number },
	botFireAt: number,
}

local states: { [number]: Combatant } = {}
local remotes: { [string]: RemoteEvent } = {}
local rng = Random.new()

local function fresh(id: number, player: Player?, bot: BotService.Bot?): Combatant
	local ammo: { [string]: number } = {}
	for weaponId, weapon in Weapons.list do
		ammo[weaponId] = weapon.magazine
	end
	return {
		id = id,
		player = player,
		bot = bot,
		health = combat.health,
		shieldUntil = 0,
		streak = 0,
		combo = 0,
		lastHitAt = -1000,
		log = {},
		lastPaid = {},
		weapon = "aurablaster",
		ammo = ammo,
		reloadingUntil = 0,
		reloadToken = 0,
		lastFire = -1000,
		requestTimes = {},
		botFireAt = 0,
	}
end

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function stateOfPlayer(player: Player): Combatant
	local state = states[player.UserId]
	if not state then
		state = fresh(player.UserId, player, nil)
		states[player.UserId] = state
	end
	return state
end

local function stateOfBot(bot: BotService.Bot): Combatant
	local state = states[bot.id]
	if not state then
		state = fresh(bot.id, nil, bot)
		states[bot.id] = state
	end
	return state
end

local function nameOf(state: Combatant): string
	if state.player then
		return state.player.DisplayName
	end
	return if state.bot then state.bot.name else "?"
end

local function factionOf(state: Combatant): number
	if state.player then
		local faction = state.player:GetAttribute("Faction")
		return if type(faction) == "number" then faction else 0
	end
	return if state.bot then state.bot.faction else 0
end

local function factionColor(faction: number): Color3
	local info = FactionRules.byId(faction)
	return if info then FactionRules.color(info) else Color3.new(1, 1, 1)
end

local function characterOf(state: Combatant): Model?
	if state.player then
		return state.player.Character
	end
	return if state.bot then state.bot.model else nil
end

local function rootOf(state: Combatant): BasePart?
	local character = characterOf(state)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function aliveInWar(state: Combatant): boolean
	if state.health <= 0 then
		return false
	end
	if state.player then
		local humanoid = state.player.Character and state.player.Character:FindFirstChildOfClass("Humanoid")
		return humanoid ~= nil and humanoid.Health > 0 and state.player:GetAttribute("Island") ~= "training"
	end
	return state.bot ~= nil and BotService.isAlive(state.bot)
end

local function mirror(state: Combatant)
	local player = state.player
	if not player then
		return
	end
	local weapon = Weapons.list[state.weapon]
	player:SetAttribute("Weapon", state.weapon)
	player:SetAttribute("Ammo", state.ammo[state.weapon])
	player:SetAttribute("MagSize", weapon.magazine)
	player:SetAttribute("ReloadUntil", if state.reloadingUntil > now() then state.reloadingUntil else 0)
	player:SetAttribute("CombatHealth", state.health)
	player:SetAttribute("ShieldUntil", state.shieldUntil)
end

local function ownedString(player: Player): string
	local data = DataService.get(player)
	local rank = player:GetAttribute("Rank")
	local owned = if data then data.weapons else {}
	local list = {}
	for _, id in Weapons.order do
		if CombatRules.unlocked(Weapons.list[id], id, if type(rank) == "number" then rank else 1, owned) then
			table.insert(list, id)
		end
	end
	return table.concat(list, ",")
end

local function isUnlocked(player: Player, id: string): boolean
	for _, owned in string.split(ownedString(player), ",") do
		if owned == id then
			return true
		end
	end
	return false
end

local function fx(kind: string, a: any, b: any, c: any, d: any?)
	local remote = remotes.CombatFx
	if remote then
		remote:FireAllClients(kind, a, b, c, d)
	end
end

local function giveShield(state: Combatant, seconds: number)
	state.shieldUntil = now() + seconds
	mirror(state)
	local character = characterOf(state)
	if character then
		local field = Instance.new("ForceField")
		field.Visible = true
		field.Parent = character
		task.delay(seconds, function()
			field:Destroy()
		end)
	end
end

local function startReload(state: Combatant)
	local weapon = Weapons.list[state.weapon]
	if state.reloadingUntil > now() or state.ammo[state.weapon] >= weapon.magazine then
		return
	end
	state.reloadToken += 1
	local token = state.reloadToken
	state.reloadingUntil = now() + weapon.reloadSeconds
	mirror(state)
	task.delay(weapon.reloadSeconds, function()
		if state.reloadToken == token then
			state.ammo[state.weapon] = weapon.magazine
			state.reloadingUntil = 0
			mirror(state)
		end
	end)
end

-- The rank damage bonus (never more than +10 percent) for a shooter.
local function damageFor(state: Combatant, weaponId: string): number
	local rank = 1
	if state.player then
		local value = state.player:GetAttribute("Rank")
		rank = if type(value) == "number" then value else 1
	end
	return CombatRules.damage(Weapons.list[weaponId].damage, rank, combat)
end

-- The combo multiplier a player has right now (1 when the last hit was too long ago).
local function comboMultiplier(state: Combatant, t: number): number
	if t - state.lastHitAt <= combat.comboWindowSeconds and state.combo >= 1 then
		return math.min(state.combo, combat.comboMax)
	end
	return 1
end

local GREY = Color3.fromRGB(150, 150, 158)

-- REDUCED TO NPC: the body turns grey, the face goes blank and a "..." bubble floats over the head. Returns a
-- function that puts everything back (bots use it when they pop back at their base).
local function knockoutLook(character: Model): () -> ()
	local undo: { () -> () } = {}
	for _, item in character:GetDescendants() do
		if item:IsA("BasePart") and item.Name ~= "HumanoidRootPart" then
			local part = item
			local color = part.Color
			part.Color = GREY
			table.insert(undo, function()
				part.Color = color
			end)
		elseif item:IsA("Decal") and item.Parent and item.Parent.Name == "Head" then
			local decal = item
			local transparency = decal.Transparency
			decal.Transparency = 1 -- a blank NPC face
			table.insert(undo, function()
				decal.Transparency = transparency
			end)
		elseif item:IsA("Shirt") or item:IsA("Pants") then
			local clothing: any = item
			local template = if item:IsA("Shirt") then clothing.ShirtTemplate else clothing.PantsTemplate
			if item:IsA("Shirt") then
				clothing.ShirtTemplate = ""
			else
				clothing.PantsTemplate = ""
			end
			table.insert(undo, function()
				if item:IsA("Shirt") then
					clothing.ShirtTemplate = template
				else
					clothing.PantsTemplate = template
				end
			end)
		end
	end
	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		local gui = Instance.new("BillboardGui")
		gui.Name = "NpcBubble"
		gui.Size = UDim2.new(0, 90, 0, 50)
		gui.StudsOffset = Vector3.new(0, 3, 0)
		gui.Adornee = head
		gui.Parent = head
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundColor3 = Color3.new(1, 1, 1)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(35, 25, 60)
		label.Text = "..."
		label.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 14)
		corner.Parent = label
		table.insert(undo, function()
			gui:Destroy()
		end)
	end
	return function()
		for _, step in undo do
			step()
		end
	end
end

local function mog(victim: Combatant, killer: Combatant)
	local t = now()
	local victimRoot = rootOf(victim)
	local position = if victimRoot then victimRoot.Position else Vector3.zero
	local victimFaction = factionOf(victim)
	local killerFaction = factionOf(killer)
	victim.health = 0
	victim.streak = 0
	victim.combo = 0

	fx("poof", position, factionColor(victimFaction), nil)
	if remotes.KillFeed then
		remotes.KillFeed:FireAllClients(nameOf(killer), killerFaction, nameOf(victim), victimFaction)
	end

	-- rewards: real players only, never for hurting your own side, and the same victim pays the same player once per cooldown
	local assisters = CombatRules.assisters(victim.log, killer.id, t, combat)
	local function pay(who: Combatant, isAssist: boolean)
		local player = who.player
		if not player then
			return
		end
		local aura, points = CombatRules.reward(isAssist, victim.bot ~= nil, combat)
		if not isAssist then
			if t - (who.lastPaid[victim.id] or -1000) < combat.farmCooldownSeconds then
				return
			end
			who.lastPaid[victim.id] = t
			local root = rootOf(who)
			if root and CaptureSystem.ownerAt(root.Position) == factionOf(who) then
				aura += combat.defendBonusAura -- defending your own zone
			end
			aura *= comboMultiplier(who, t)
		end
		points = math.floor(points * DataService.rewardMultiplier(player) + 0.5)
		local shown = DataService.addAura(player, aura)
		DataService.addPoints(player, points)
		Stats.add(player, "aura", shown)
		if isAssist then
			Stats.add(player, "assists", 1)
		else
			Stats.add(player, "mogs", 1)
			PopupSystem.send(player, "mogged", 1, "")
		end
		PopupSystem.send(player, "aura", shown, "")
		PopupSystem.send(player, "points", points, "")
	end

	if killer.player then
		killer.streak += 1
		pay(killer, false)
		local message = CombatRules.streakMessage(killer.streak, combat)
		if message then
			PopupSystem.send(killer.player, "announce", killer.streak, message)
		end
		MovementSystem.boost(killer.player, "rush", Pace.speed.rush.boost, Pace.speed.rush.seconds) -- AURA RUSH
		PopupSystem.send(killer.player, "rush", Pace.speed.rush.seconds, "")
		if remotes.CombatFeedback then
			remotes.CombatFeedback:FireClient(killer.player, "hit", true)
		end
	else
		killer.streak += 1
	end
	for _, assisterId in assisters do
		local assister = states[assisterId]
		if assister and assister.player and assister ~= killer and factionOf(assister) ~= victimFaction then
			pay(assister, true)
		end
	end
	victim.log = {}

	-- the victim is reduced to NPC for the respawn time, then respawns at the faction corner
	if victim.player then
		local player = victim.player
		player:SetAttribute("KnockoutRespawn", true)
		player:SetAttribute("RespawnAt", t + combat.respawnSeconds)
		local character = player.Character
		if character then
			knockoutLook(character)
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.Health = 0
			end
		end
		PopupSystem.send(player, "knockout", 1, "")
		mirror(victim)
	elseif victim.bot then
		local bot = victim.bot
		local restore = knockoutLook(bot.model)
		task.delay(combat.respawnSeconds, function()
			if BotService.isAlive(bot) then
				restore()
				victim.health = combat.health
				BotService.respawn(bot, 0.1)
				giveShield(victim, combat.shieldSeconds)
			end
		end)
	end
end

-- Damage one combatant. Friendly fire does nothing. Returns true if it was a hit that counted.
local function hurt(victim: Combatant, shooter: Combatant, amount: number): boolean
	local t = now()
	if not aliveInWar(victim) or victim.shieldUntil > t or factionOf(victim) == factionOf(shooter) or victim == shooter then
		return false
	end
	local newHealth, knockedOut = CombatRules.applyDamage(victim.health, amount)
	victim.health = newHealth
	local entry = victim.log[shooter.id]
	victim.log[shooter.id] = { time = t, amount = (if entry and t - entry.time <= combat.assistWindowSeconds then entry.amount else 0) + amount }
	if victim.player and remotes.CombatFeedback then
		local root = rootOf(shooter)
		local from = if root then root.Position else Vector3.zero
		remotes.CombatFeedback:FireClient(victim.player, "damage", from, amount)
	end
	-- every hit pays a little aura, and hits close together build the combo (x2, x3 ...)
	local shooterPlayer = shooter.player
	if shooterPlayer then
		local count, multiplier = CombatRules.comboNext(shooter.combo, shooter.lastHitAt, t, combat)
		shooter.combo, shooter.lastHitAt = count, t
		local shown = DataService.addAura(shooterPlayer, CombatRules.hitAura(victim.bot ~= nil, multiplier, combat))
		Stats.add(shooterPlayer, "aura", shown)
		PopupSystem.send(shooterPlayer, "aura", shown, "")
		PopupSystem.send(shooterPlayer, "combo", multiplier, "")
		if remotes.CombatFeedback and not knockedOut then
			remotes.CombatFeedback:FireClient(shooterPlayer, "hit", false)
		end
	end
	if knockedOut then
		mog(victim, shooter)
	else
		mirror(victim)
	end
	return true
end

-- Find who owns a part the ray hit (a player's or a bot's body).
local function combatantFromPart(part: Instance): Combatant?
	local model = part:FindFirstAncestorOfClass("Model")
	if not model then
		return nil
	end
	local player = Players:GetPlayerFromCharacter(model)
	if player then
		return stateOfPlayer(player)
	end
	if CollectionService:HasTag(model, "Bot") then
		for _, bot in BotService.list() do
			if bot.model == model then
				return stateOfBot(bot)
			end
		end
	end
	return nil
end

-- One ray. Parts you cannot walk through (CanCollide off: signs, zones, steam) never stop a ball.
local function cast(origin: Vector3, direction: Vector3, range: number, shooterCharacter: Model?): (Vector3, Instance?, Vector3)
	local ignore: { Instance } = {}
	if shooterCharacter then
		table.insert(ignore, shooterCharacter)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	for _ = 1, 5 do
		params.FilterDescendantsInstances = ignore
		local result = Workspace:Raycast(origin, direction * range, params)
		if not result then
			return origin + direction * range, nil, Vector3.yAxis
		end
		local part = result.Instance
		if part.CanCollide or part:FindFirstAncestorOfClass("Model") and combatantFromPart(part) ~= nil then
			return result.Position, part, result.Normal
		end
		table.insert(ignore, part)
	end
	return origin + direction * range, nil, Vector3.yAxis
end

-- Fire from a combatant toward a unit direction. Assumes every check has already passed.
local function shoot(state: Combatant, direction: Vector3, spreadOverride: number?)
	local weapon = Weapons.list[state.weapon]
	local character = characterOf(state)
	local head = character and character:FindFirstChild("Head")
	local root = rootOf(state)
	local origin = if head and head:IsA("BasePart") then head.Position elseif root then root.Position + Vector3.new(0, 1.5, 0) else nil
	if not origin then
		return
	end
	local damage = damageFor(state, weapon.id)
	local pellets = CombatRules.pelletDirections(direction.X, direction.Y, direction.Z, weapon.pellets, spreadOverride or weapon.spreadDeg)
	if weapon.style == "cone" then
		fx("flex", origin, direction, factionColor(factionOf(state)), weapon.range) -- the flex shockwave
	end
	for _, pellet in pellets do
		local pelletDirection = Vector3.new(pellet[1], pellet[2], pellet[3])
		local endPoint, part, normal = cast(origin, pelletDirection, weapon.range, character)
		local victim = if part then combatantFromPart(part) else nil
		fx("shot", origin, endPoint, factionColor(factionOf(state)), weapon.style)
		if victim then
			hurt(victim, state, damage)
		elseif part then
			fx("mark", endPoint, normal, factionColor(factionOf(state)))
		end
	end
end

local function handleFire(player: Player, dx: any, dy: any, dz: any)
	local state = stateOfPlayer(player)
	local t = now()
	-- rate limit first (a sliding one-second window), then types, then rules
	local recent = state.requestTimes
	while #recent > 0 and t - recent[1] > 1 do
		table.remove(recent, 1)
	end
	if #recent >= combat.maxRequestsPerSecond then
		return
	end
	table.insert(recent, t)
	if type(dx) ~= "number" or type(dy) ~= "number" or type(dz) ~= "number" or not CombatRules.directionValid(dx, dy, dz) then
		return
	end
	if Workspace:GetAttribute("WarPhase") ~= "War" or not aliveInWar(state) then
		return
	end
	local weapon = Weapons.list[state.weapon]
	local ok = CombatRules.canFire({
		alive = true,
		shieldUntil = state.shieldUntil,
		reloadingUntil = state.reloadingUntil,
		ammo = state.ammo[state.weapon],
		lastFire = state.lastFire,
	}, t, weapon)
	if not ok then
		return
	end
	local length = math.sqrt(dx * dx + dy * dy + dz * dz)
	state.lastFire = t
	state.ammo[state.weapon] -= 1
	mirror(state)
	shoot(state, Vector3.new(dx / length, dy / length, dz / length), nil)
	if state.ammo[state.weapon] <= 0 then
		startReload(state) -- automatic reload
	end
end

-- Bots: look for the nearest enemy in range with a clear line, strafe, hide behind cover when hurt, and fire
-- with a worse aim than a player.
local function botThink(bot: BotService.Bot)
	local state = stateOfBot(bot)
	local t = now()
	if Workspace:GetAttribute("WarPhase") ~= "War" or not aliveInWar(state) or bot.humanoid.WalkSpeed <= 0 then
		return
	end
	local position = bot.root.Position
	local best: Combatant? = nil
	local bestDistance = combat.botRange
	for _, other in states do
		if other ~= state and aliveInWar(other) and factionOf(other) ~= bot.faction and other.shieldUntil <= t then
			local root = rootOf(other)
			if root then
				local distance = (root.Position - position).Magnitude
				if distance < bestDistance then
					best, bestDistance = other, distance
				end
			end
		end
	end
	local enemy = best
	local enemyRoot = if enemy then rootOf(enemy) else nil
	if not enemy or not enemyRoot then
		return
	end
	local toEnemy = enemyRoot.Position - position
	local flat = Vector3.new(toEnemy.X, 0, toEnemy.Z)
	if flat.Magnitude < 0.1 then
		return
	end
	local direction = (toEnemy + Vector3.new(0, 0.5, 0)).Unit
	local origin = position + Vector3.new(0, 1.5, 0)
	local endPoint, part = cast(origin, direction, bestDistance + 2, bot.model)
	local clear = part ~= nil and combatantFromPart(part) == enemy
	local lowHealth = state.health <= combat.botCoverHealth
	if lowHealth then
		-- hide behind the nearest prop tagged "Cover", on the side away from the enemy
		local bestCover: BasePart? = nil
		local coverDistance = 30
		for _, cover in CollectionService:GetTagged("Cover") do
			if cover:IsA("BasePart") then
				local distance = (cover.Position - position).Magnitude
				if distance < coverDistance then
					bestCover, coverDistance = cover, distance
				end
			end
		end
		if bestCover then
			local away = (bestCover.Position - enemyRoot.Position)
			away = Vector3.new(away.X, 0, away.Z).Unit
			BotService.moveTo(bot, bestCover.Position + away * (bestCover.Size.Magnitude * 0.5 + 3), 1.5)
			return
		end
	end
	if clear then
		-- strafe sideways while shooting
		local side = Vector3.new(-flat.Z, 0, flat.X).Unit * (if rng:NextNumber() < 0.5 then 1 else -1)
		BotService.moveTo(bot, position + side * 7, 0.8)
		if t >= state.botFireAt and state.shieldUntil <= t then
			state.botFireAt = t + combat.botFireIntervalMin + rng:NextNumber() * (combat.botFireIntervalMax - combat.botFireIntervalMin)
			state.weapon = "aurablaster"
			shoot(state, direction, combat.botSpreadDeg)
		end
	end
end

local function onPlayer(player: Player)
	local state = stateOfPlayer(player)
	player.CharacterAdded:Connect(function(character)
		task.spawn(function()
			local humanoid = character:WaitForChild("Humanoid", 5)
			if humanoid and humanoid:IsA("Humanoid") then
				humanoid.BreakJointsOnDeath = false -- a mogged player stands there, grey, instead of falling apart
			end
		end)
		state.combo = 0
		state.health = combat.health
		state.streak = 0
		state.log = {}
		state.reloadToken += 1
		state.reloadingUntil = 0
		for weaponId, weapon in Weapons.list do
			state.ammo[weaponId] = weapon.magazine
		end
		player:SetAttribute("KnockoutRespawn", nil)
		giveShield(state, combat.shieldSeconds)
		task.defer(function()
			player:SetAttribute("WeaponsOwned", ownedString(player))
		end)
	end)
	player:SetAttribute("WeaponsOwned", ownedString(player))
	mirror(state)
end

-- Aura Refill: full aura charge and full ego, reload cancelled.
function CombatSystem.refill(player: Player)
	local state = stateOfPlayer(player)
	state.reloadToken += 1
	state.reloadingUntil = 0
	state.health = combat.health
	for weaponId, weapon in Weapons.list do
		state.ammo[weaponId] = weapon.magazine
	end
	mirror(state)
end

function CombatSystem.init()
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for _, name in { "FireWeapon", "EquipWeapon", "ReloadRequest", "CombatFx", "CombatFeedback", "KillFeed" } do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		remotes[name] = remote
	end
	remotes.FireWeapon.OnServerEvent:Connect(handleFire)
	remotes.EquipWeapon.OnServerEvent:Connect(function(player: Player, id: any)
		if type(id) ~= "string" or Weapons.list[id] == nil or not isUnlocked(player, id) then
			return
		end
		local state = stateOfPlayer(player)
		if state.weapon ~= id then
			state.weapon = id
			state.reloadToken += 1 -- switching cancels a reload in progress
			state.reloadingUntil = 0
			if state.ammo[id] <= 0 then
				startReload(state)
			end
			mirror(state)
		end
	end)
	remotes.ReloadRequest.OnServerEvent:Connect(function(player: Player)
		local state = stateOfPlayer(player)
		if aliveInWar(state) then
			startReload(state)
		end
	end)
	local okRespawn = pcall(function()
		Players.RespawnTime = combat.respawnSeconds
	end)
	if not okRespawn then
		warn("[mog-wars] could not set Players.RespawnTime; set it to 3 in the Players service")
	end
	Players.PlayerAdded:Connect(onPlayer)
	Players.PlayerRemoving:Connect(function(player)
		states[player.UserId] = nil
	end)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

function CombatSystem.start()
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local owned = ownedString(player)
				if player:GetAttribute("WeaponsOwned") ~= owned then
					player:SetAttribute("WeaponsOwned", owned)
				end
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.25)
			for _, bot in BotService.list() do
				local ok, err = pcall(botThink, bot)
				if not ok then
					warn("[mog-wars] bot combat error: " .. tostring(err))
				end
			end
		end
	end)
end

return CombatSystem
