--!strict
-- Pure unit rules for the tank and the horse. Units last one war and are used up when deployed.
-- Tank: multiplies a faction's push in ONE zone. Horse: multiplies one player's walk speed.

export type DeployContext = {
	warOn: boolean,
	owned: number, -- how many of this unit the player owns
	alive: boolean,
	inZone: boolean, -- the player is standing in a zone (needed for a tank)
	tankInZone: boolean, -- their faction already has a tank in that zone
	riding: boolean, -- they are already riding a horse
}

local UnitRules = {}

local MIN_MULTIPLIER = 1 -- a boost never weakens anything
local MAX_MULTIPLIER = 2 -- and never more than doubles it: the hard limit for every unit boost

UnitRules.UNITS = { tank = true, horse = true }

local function finite(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge
end

-- True when a configured boost is inside the allowed limits (1 to 2).
function UnitRules.validMultiplier(multiplier: number): boolean
	return finite(multiplier) and multiplier >= MIN_MULTIPLIER and multiplier <= MAX_MULTIPLIER
end

-- Power after a tank boost. A bad multiplier is ignored so the boost can never break the bar.
function UnitRules.boostedPower(power: number, multiplier: number): number
	if not finite(power) or power < 0 then
		return 0
	end
	if not UnitRules.validMultiplier(multiplier) then
		return power
	end
	return power * multiplier
end

-- Walk speed for a player, with the horse boost if riding.
function UnitRules.walkSpeed(base: number, riding: boolean, multiplier: number): number
	if not finite(base) or base <= 0 then
		return 16
	end
	if riding and UnitRules.validMultiplier(multiplier) then
		return base * multiplier
	end
	return base
end

-- Whether a deploy is allowed. Returns ok and a stable reason string. Checks run in a fixed order.
function UnitRules.canDeploy(unit: string, context: DeployContext): (boolean, string?)
	if not UnitRules.UNITS[unit] then
		return false, "unknown_unit"
	end
	if not context.warOn then
		return false, "not_war"
	end
	if not context.alive then
		return false, "not_alive"
	end
	if context.owned < 1 then
		return false, "no_unit"
	end
	if unit == "tank" then
		if not context.inZone then
			return false, "not_in_zone"
		end
		if context.tankInZone then
			return false, "tank_exists"
		end
	elseif unit == "horse" then
		if context.riding then
			return false, "already_riding"
		end
	end
	return true, nil
end

return UnitRules
