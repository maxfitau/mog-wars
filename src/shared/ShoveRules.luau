--!strict
-- Pure shove rules. The client only asks "shove"; the server picks the target with these functions.

export type Settings = {
	cooldownSeconds: number,
	range: number,
	penaltySeconds: number,
	penaltyMultiplier: number,
	minRequestInterval: number,
}

export type Candidate = {
	id: number,
	x: number,
	y: number,
	z: number,
	faction: number,
	alive: boolean,
}

local ShoveRules = {}

local function finite(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge
end

-- True when a request arrives too soon after the previous one (spam guard, whatever the outcome).
function ShoveRules.tooFast(now: number, lastRequest: number, settings: Settings): boolean
	return now - lastRequest < settings.minRequestInterval
end

-- True when the player may shove now.
function ShoveRules.offCooldown(now: number, lastShove: number, settings: Settings): boolean
	return now - lastShove >= settings.cooldownSeconds
end

-- The nearest living enemy within range, or nil and a stable reason ("bad_input", "no_target").
function ShoveRules.pickTarget(
	x: number,
	y: number,
	z: number,
	faction: number,
	candidates: { Candidate },
	settings: Settings
): (number?, string?)
	if not (finite(x) and finite(y) and finite(z)) or faction == 0 then
		return nil, "bad_input"
	end
	local bestId, bestDistance = nil, math.huge
	for _, candidate in candidates do
		if
			candidate.alive
			and candidate.faction ~= 0
			and candidate.faction ~= faction
			and finite(candidate.x)
			and finite(candidate.y)
			and finite(candidate.z)
		then
			local dx, dy, dz = candidate.x - x, candidate.y - y, candidate.z - z
			local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
			if distance <= settings.range and (distance < bestDistance or (distance == bestDistance and bestId ~= nil and candidate.id < bestId)) then
				bestId, bestDistance = candidate.id, distance
			end
		end
	end
	if bestId == nil then
		return nil, "no_target"
	end
	return bestId, nil
end

-- Flat unit direction pointing from the shover to the target. Straight ahead (0, 1) if they overlap.
function ShoveRules.direction(fromX: number, fromZ: number, toX: number, toZ: number): (number, number)
	local dx, dz = toX - fromX, toZ - fromZ
	local length = math.sqrt(dx * dx + dz * dz)
	if not finite(length) or length < 1e-6 then
		return 0, 1
	end
	return dx / length, dz / length
end

-- Aura power multiplier for a player shoved recently: reduced until `penaltyUntil`, then 1.
function ShoveRules.powerMultiplier(now: number, penaltyUntil: number, settings: Settings): number
	if penaltyUntil > now then
		return settings.penaltyMultiplier
	end
	return 1
end

return ShoveRules
