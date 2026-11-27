--!strict
-- Pure Mog combat rules (aura blasts, ego, mogging). No Roblox calls, so they can be tested anywhere. The server uses them to check
-- every shot; the client only ever sends "I fired toward this direction".

export type Weapon = { damage: number, pellets: number, spreadDeg: number, range: number, fireInterval: number, magazine: number, unlockRank: number }

export type ShooterState = {
	alive: boolean,
	shieldUntil: number,
	reloadingUntil: number,
	ammo: number,
	lastFire: number,
}

export type Settings = {
	damageBonusCap: number,
	damageBonusPerRank: number,
	assistWindowSeconds: number,
	assistMinDamage: number,
	assistFraction: number,
	botRewardFactor: number,
	hitAura: number,
	mogAura: number,
	mogPoints: number,
	comboWindowSeconds: number,
	comboMax: number,
	streaks: { [number]: string },
}

local CombatRules = {}

local function finite(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge
end

-- Damage per ball after the rank bonus, which can never pass +cap (10 percent). Rounded to a whole number.
function CombatRules.damage(base: number, rank: number, settings: Settings): number
	local bonus = if finite(rank) then math.min(settings.damageBonusCap, math.max(0, settings.damageBonusPerRank * (rank - 1))) else 0
	return math.floor(base * (1 + bonus) + 0.5)
end

-- Is this a sane aim direction? It must be finite and close to length 1.
function CombatRules.directionValid(x: number, y: number, z: number): boolean
	if not (finite(x) and finite(y) and finite(z)) then
		return false
	end
	local length = math.sqrt(x * x + y * y + z * z)
	return length > 0.9 and length < 1.1
end

-- May this shooter fire right now? Returns ok and a stable reason.
function CombatRules.canFire(state: ShooterState, now: number, weapon: Weapon): (boolean, string?)
	if not state.alive then
		return false, "dead"
	end
	if state.shieldUntil > now then
		return false, "shielded" -- no shooting while the spawn shield is up
	end
	if state.reloadingUntil > now then
		return false, "reloading"
	end
	if state.ammo < 1 then
		return false, "empty"
	end
	if now - state.lastFire < weapon.fireInterval - 0.02 then
		return false, "too_soon"
	end
	return true, nil
end

-- Take damage. Returns the new ego (never below 0) and whether the target is mogged (reduced to NPC).
function CombatRules.applyDamage(health: number, damage: number): (number, boolean)
	if not finite(health) or not finite(damage) or damage <= 0 then
		return health, false
	end
	local remaining = math.max(0, health - damage)
	return remaining, remaining <= 0
end

-- The directions of each ball of a shot. One ball goes where you aimed (plus nothing); several balls are spread
-- evenly around a cone of `spreadDeg`. (dx, dy, dz) must be a unit vector.
function CombatRules.pelletDirections(dx: number, dy: number, dz: number, pellets: number, spreadDeg: number): { { number } }
	if pellets <= 1 then
		return { { dx, dy, dz } }
	end
	-- two directions at right angles to the aim
	local upX, upY, upZ = 0, 1, 0
	if math.abs(dy) > 0.95 then
		upX, upY, upZ = 1, 0, 0
	end
	local ux, uy, uz = dy * upZ - dz * upY, dz * upX - dx * upZ, dx * upY - dy * upX
	local uLength = math.sqrt(ux * ux + uy * uy + uz * uz)
	ux, uy, uz = ux / uLength, uy / uLength, uz / uLength
	local vx, vy, vz = dy * uz - dz * uy, dz * ux - dx * uz, dx * uy - dy * ux
	local angle = math.rad(spreadDeg)
	local result = {}
	for index = 0, pellets - 1 do
		local phi = 2 * math.pi * index / pellets
		local sideX = ux * math.cos(phi) + vx * math.sin(phi)
		local sideY = uy * math.cos(phi) + vy * math.sin(phi)
		local sideZ = uz * math.cos(phi) + vz * math.sin(phi)
		table.insert(result, {
			dx * math.cos(angle) + sideX * math.sin(angle),
			dy * math.cos(angle) + sideY * math.sin(angle),
			dz * math.cos(angle) + sideZ * math.sin(angle),
		})
	end
	return result
end

-- Who gets an assist for a mog? `log` maps attacker id to { time, amount }. The killer is excluded; attackers
-- need to have done enough damage recently. Returns the ids in a stable order.
function CombatRules.assisters(log: { [number]: { time: number, amount: number } }, killerId: number, now: number, settings: Settings): { number }
	local ids = {}
	for attackerId, entry in log do
		if attackerId ~= killerId and now - entry.time <= settings.assistWindowSeconds and entry.amount >= settings.assistMinDamage then
			table.insert(ids, attackerId)
		end
	end
	table.sort(ids)
	return ids
end

-- Aura and Mog Points for a mog or an assist. A bot victim pays `botRewardFactor` of it.
function CombatRules.reward(isAssist: boolean, victimIsBot: boolean, settings: Settings): (number, number)
	local factor = if isAssist then settings.assistFraction else 1
	if victimIsBot then
		factor *= settings.botRewardFactor
	end
	return math.floor(settings.mogAura * factor + 0.5), math.floor(settings.mogPoints * factor + 0.5)
end

-- The streak announcement for a number of mogs in a row, or nil.
function CombatRules.streakMessage(count: number, settings: Settings): string?
	return settings.streaks[count]
end

-- The combo: hits closer together than the window build x2, x3, x4 ... up to the cap. Returns the new hit count and
-- the multiplier to use now (1 for the first hit).
function CombatRules.comboNext(count: number, lastHitAt: number, now: number, settings: Settings): (number, number)
	local nextCount = if now - lastHitAt <= settings.comboWindowSeconds and count >= 1 then count + 1 else 1
	return nextCount, math.min(nextCount, settings.comboMax)
end

-- Aura for one hit, with the combo multiplier. A bot victim pays botRewardFactor (never less than 1).
function CombatRules.hitAura(victimIsBot: boolean, multiplier: number, settings: Settings & { botRewardFactor: number }): number
	local base = settings.hitAura * multiplier
	if victimIsBot then
		base *= settings.botRewardFactor
	end
	return math.max(1, math.floor(base + 0.5))
end

-- Is this weapon unlocked for a player of `rank` who owns the weapons in `owned`?
function CombatRules.unlocked(weapon: Weapon, id: string, rank: number, owned: { [string]: boolean }): boolean
	return (finite(rank) and rank >= weapon.unlockRank) or owned[id] == true
end

-- MOBILE AIM ASSIST (display side only; the server still checks the shot). Given the aim direction and the
-- positions of enemies (relative to the camera), returns the direction to the closest enemy that is within
-- `assistDegrees` of the aim, or the aim itself when there is none.
function CombatRules.aimAssist(
	aimX: number,
	aimY: number,
	aimZ: number,
	enemies: { { number } },
	assistDegrees: number
): (number, number, number)
	local bestAngle, bx, by, bz = assistDegrees, aimX, aimY, aimZ
	for _, enemy in enemies do
		local ex, ey, ez = enemy[1], enemy[2], enemy[3]
		local length = math.sqrt(ex * ex + ey * ey + ez * ez)
		if length > 0.001 and finite(length) then
			local dot = (aimX * ex + aimY * ey + aimZ * ez) / length
			local angle = math.deg(math.acos(math.clamp(dot, -1, 1)))
			if angle < bestAngle then
				bestAngle, bx, by, bz = angle, ex / length, ey / length, ez / length
			end
		end
	end
	return bx, by, bz
end

return CombatRules
