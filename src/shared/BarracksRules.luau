--!strict
-- Pure barracks (offline income) rules. Income builds while away at a slow rate, up to a storage cap, and
-- is collected on return. Times are unix seconds from the server clock.

export type Settings = {
	baseRatePerHour: number,
	perRankRatePerHour: number,
	maxStoredHours: number,
}

local BarracksRules = {}

local function finite(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge
end

-- Points per hour at a rank (rank 1 pays the base rate).
function BarracksRules.ratePerHour(rank: number, settings: Settings): number
	if not finite(rank) or rank < 1 then
		return 0
	end
	return settings.baseRatePerHour + settings.perRankRatePerHour * (math.floor(rank) - 1)
end

-- A start time in the future (the clock moved back) is treated as "now" so income never goes negative.
function BarracksRules.normalize(now: number, since: number): number
	if since > now then
		return now
	end
	return since
end

-- Whole points waiting to be collected. A start time of 0 means the barracks has not started yet.
function BarracksRules.pending(now: number, since: number, rank: number, settings: Settings): number
	if not (finite(now) and finite(since)) or since <= 0 then
		return 0
	end
	local elapsed = now - BarracksRules.normalize(now, since)
	if elapsed <= 0 then
		return 0
	end
	local hours = math.min(elapsed / 3600, settings.maxStoredHours)
	return math.floor(BarracksRules.ratePerHour(rank, settings) * hours)
end

return BarracksRules
