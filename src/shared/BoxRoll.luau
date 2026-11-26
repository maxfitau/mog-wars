--!strict
-- Pure box rolling. The same weights are shown to players and used to roll, so they cannot drift apart.
-- Randomness is injected (a function returning a number from 0 up to but not including 1).

export type Drop = {
	weight: number,
	kind: string,
	amount: number?,
	unit: string?,
	cosmetic: string?,
}

export type Tier = {
	displayName: string,
	drops: { Drop },
}

local BoxRoll = {}

local VALID_KINDS = { points = true, unit = true, cosmetic = true }

-- Returns true when the tier is well formed, otherwise false and a stable reason string.
function BoxRoll.validate(tier: Tier): (boolean, string?)
	if #tier.drops == 0 then
		return false, "no_drops"
	end
	local sum = 0
	for _, drop in tier.drops do
		if drop.weight ~= drop.weight or drop.weight <= 0 then
			return false, "bad_weight"
		end
		if not VALID_KINDS[drop.kind] then
			return false, "bad_kind"
		end
		if drop.kind == "points" and (drop.amount == nil or drop.amount <= 0) then
			return false, "bad_amount"
		end
		if drop.kind == "unit" and drop.unit == nil then
			return false, "bad_unit"
		end
		if drop.kind == "cosmetic" and drop.cosmetic == nil then
			return false, "bad_cosmetic"
		end
		sum += drop.weight
	end
	if math.abs(sum - 100) > 1e-9 then
		return false, "weights_not_100"
	end
	return true, nil
end

-- The odds to show on screen: one entry per drop, as a percentage.
function BoxRoll.odds(tier: Tier): { { drop: Drop, percent: number } }
	local list = {}
	for _, drop in tier.drops do
		table.insert(list, { drop = drop, percent = drop.weight })
	end
	return list
end

-- Pick a drop. `random` must return a value in [0, 1). Out-of-range values are clamped safely.
function BoxRoll.roll(tier: Tier, random: () -> number): Drop
	local value = random()
	if value ~= value or value < 0 then
		value = 0
	elseif value >= 1 then
		value = 0.999999999
	end
	local target = value * 100
	local running = 0
	for _, drop in tier.drops do
		running += drop.weight
		if target < running then
			return drop
		end
	end
	return tier.drops[#tier.drops]
end

-- Expected points per box (units and cosmetics are not counted). Used by the pacing check.
function BoxRoll.expectedPoints(tier: Tier): number
	local total = 0
	for _, drop in tier.drops do
		if drop.kind == "points" and drop.amount then
			total += drop.weight / 100 * drop.amount
		end
	end
	return total
end

return BoxRoll
