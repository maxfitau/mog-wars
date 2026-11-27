--!strict
-- Pure rank rules. Ranks are numbers from 1 (Rookie) up; the config supplies names and costs.
-- Rank-up is all-or-nothing: either the points are spent and the rank rises, or nothing changes.

export type RankEntry = { name: string, cost: number }

export type RankConfig = {
	ranks: { RankEntry },
	aura: { perRankBonus: number },
}

export type RankUpResult = {
	ok: boolean,
	reason: string?, -- stable reason when not ok
	rank: number, -- the rank after the attempt
	points: number, -- the points after the attempt
}

local RankRules = {}

local function isWholeNumber(value: any): boolean
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
		and value == math.floor(value)
end

function RankRules.maxRank(config: RankConfig): number
	return #config.ranks
end

-- Cost to go from `rank` to `rank + 1`, or nil at the top rank.
function RankRules.nextCost(config: RankConfig, rank: number): number?
	local nextEntry = config.ranks[rank + 1]
	return if nextEntry then nextEntry.cost else nil
end

-- Total points spent to reach `rank` from Rookie.
function RankRules.totalToReach(config: RankConfig, rank: number): number
	local total = 0
	for index = 2, math.min(rank, #config.ranks) do
		total += config.ranks[index].cost
	end
	return total
end

-- Aura power multiplier for a rank: 1 at Rookie, plus a fixed bonus per rank.
function RankRules.auraMultiplier(config: RankConfig, rank: number): number
	local clamped = math.clamp(math.floor(rank), 1, #config.ranks)
	return 1 + config.aura.perRankBonus * (clamped - 1)
end

function RankRules.tryRankUp(config: RankConfig, rank: number, points: number): RankUpResult
	local unchanged: RankUpResult = { ok = false, reason = nil, rank = rank, points = points }
	if not isWholeNumber(rank) or not isWholeNumber(points) or rank < 1 or points < 0 then
		unchanged.reason = "bad_input"
		return unchanged
	end
	if rank >= #config.ranks then
		unchanged.reason = "max_rank"
		return unchanged
	end
	local nextEntry = config.ranks[rank + 1]
	if points < nextEntry.cost then
		unchanged.reason = "not_enough_points"
		return unchanged
	end
	return {
		ok = true,
		reason = nil,
		rank = rank + 1,
		points = points - nextEntry.cost,
	}
end

return RankRules
