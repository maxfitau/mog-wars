--!strict
-- Pure rank rules. Ranks are numbers from 1 (NPC) up; the config supplies names and aura amounts.
-- Ranks are EARNED BY TOTAL AURA: each rank's `cost` is the extra aura needed to reach it from the one before, and
-- the rank rises by itself as aura is earned and never goes down. (The old spend-points rank-up is kept below.)

export type RankEntry = { name: string, cost: number }

export type RankConfig = {
	ranks: { RankEntry },
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

-- The rank a player has earned with `aura` total aura (1 = NPC up to the top rank).
function RankRules.rankForAura(config: RankConfig, aura: number): number
	if aura ~= aura or aura < 0 then
		return 1
	end
	local rank = 1
	for index = 2, #config.ranks do
		if aura >= RankRules.totalToReach(config, index) then
			rank = index
		end
	end
	return rank
end

-- For the rank progress bar: the player's rank, the aura where that rank started, and the aura where the next one
-- starts (nil at the top rank).
function RankRules.progress(config: RankConfig, aura: number): (number, number, number?)
	local rank = RankRules.rankForAura(config, aura)
	local floor = RankRules.totalToReach(config, rank)
	local ceiling = if rank < #config.ranks then RankRules.totalToReach(config, rank + 1) else nil
	return rank, floor, ceiling
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
