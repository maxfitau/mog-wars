--!strict
-- Pure weekly-season rules. A season is one UTC week (Monday to Sunday). Players earn season points for their
-- faction; the faction with the most points across all servers wins the week; members who earned enough
-- points for the winning faction get a cosmetic title. Nothing here gives power, points or boxes.

export type Season = {
	week: number, -- week index of `points`, 0 = never played
	points: { [string]: number }, -- this week's points by faction id (as a string key)
	prevWeek: number, -- the week before, kept so its reward can be claimed
	prevPoints: { [string]: number },
	claimed: number, -- the last week whose reward was already resolved
}

export type Settings = {
	minPoints: number,
	pointsPerZoneValue: number,
	pointsWarWin: number,
	pointsMogOffWin: number,
}

local SeasonRules = {}

local SECONDS_PER_DAY = 86400

-- The thousand-day-old Unix epoch started on a Thursday, so shifting by 3 days makes weeks start on Monday.
function SeasonRules.weekIndex(unixSeconds: number): number
	return math.floor((math.floor(unixSeconds / SECONDS_PER_DAY) + 3) / 7)
end

-- Unix time the given week ends (the start of the next Monday, UTC).
function SeasonRules.weekEnds(week: number): number
	return ((week + 1) * 7 - 3) * SECONDS_PER_DAY
end

function SeasonRules.newSeason(): Season
	return { week = 0, points = {}, prevWeek = 0, prevPoints = {}, claimed = 0 }
end

-- Points for an event. kind is "capture" (value = the zone's value), "warWin" or "mogOffWin".
function SeasonRules.pointsFor(kind: string, value: number, settings: Settings): number
	if kind == "capture" then
		if value ~= value or value <= 0 then
			return 0
		end
		return math.floor(value) * settings.pointsPerZoneValue
	elseif kind == "warWin" then
		return settings.pointsWarWin
	elseif kind == "mogOffWin" then
		return settings.pointsMogOffWin
	end
	return 0
end

-- Move a season forward to `week`. The week just ended becomes "previous" (only if it was exactly the week
-- before; older weeks have no standings left to check). Returns true if anything changed.
function SeasonRules.roll(season: Season, week: number): boolean
	if week <= season.week then
		return false
	end
	if season.week > 0 and season.week == week - 1 then
		season.prevWeek = season.week
		season.prevPoints = season.points
	else
		season.prevWeek = 0
		season.prevPoints = {}
	end
	season.week = week
	season.points = {}
	return true
end

-- Add points earned for a faction in `week` (rolling the season forward first if needed).
-- Returns false for a bad amount or faction.
function SeasonRules.addPoints(season: Season, faction: number, amount: number, week: number): boolean
	if amount ~= amount or amount <= 0 or faction ~= faction or faction < 1 or faction ~= math.floor(faction) then
		return false
	end
	SeasonRules.roll(season, week)
	local key = tostring(faction)
	season.points[key] = (season.points[key] or 0) + math.floor(amount)
	return true
end

-- Total points a player earned this week, across factions.
function SeasonRules.total(points: { [string]: number }): number
	local sum = 0
	for _, value in points do
		sum += value
	end
	return sum
end

-- The faction with the most points, or 0 for a tie at the top or no points at all.
function SeasonRules.winner(standings: { [number]: number }): number
	local best, bestPoints, tied = 0, 0, false
	for faction, points in standings do
		if points > bestPoints then
			best, bestPoints, tied = faction, points, false
		elseif points == bestPoints and points > 0 then
			tied = true
		end
	end
	return if tied then 0 else best
end

-- Does this player earn the champion reward for the previous week? They must not have resolved it yet, the
-- winner must exist, and they must have earned at least `minPoints` for the winning faction.
function SeasonRules.eligible(season: Season, winner: number, settings: Settings): boolean
	if winner == 0 or season.prevWeek <= season.claimed then
		return false
	end
	return (season.prevPoints[tostring(winner)] or 0) >= settings.minPoints
end

function SeasonRules.hasUnresolvedReward(season: Season): boolean
	return season.prevWeek > season.claimed
end

return SeasonRules
