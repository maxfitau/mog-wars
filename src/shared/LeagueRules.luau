--!strict
-- THE TEAM LEAGUE (pure). Every war a team wins adds one win to that week's tally; weeks start Monday 00:00 UTC. The team with
-- the most wars won at the end of the week is that week's winner. Tie-break: the team that got to that many wins FIRST.
-- A tally is plain numbers so it saves in a DataStore: { wins = {n per team}, last = {sequence of each team's latest win}, total = n }.

export type Tally = { wins: { number }, last: { number }, total: number }

local LeagueRules = {}

LeagueRules.TEAM_COUNT = 4
LeagueRules.WEEK_SECONDS = 7 * 86400

local FIRST_MONDAY = 4 * 86400 -- 1970-01-05 00:00 UTC, the first Monday

-- Week number of a moment (Monday 00:00 UTC starts a new one).
function LeagueRules.weekIndex(unix: number): number
	return math.floor((unix - FIRST_MONDAY) / LeagueRules.WEEK_SECONDS)
end

function LeagueRules.weekStart(week: number): number
	return FIRST_MONDAY + week * LeagueRules.WEEK_SECONDS
end

function LeagueRules.secondsToNextWeek(unix: number): number
	return LeagueRules.weekStart(LeagueRules.weekIndex(unix) + 1) - unix
end

function LeagueRules.newTally(teamCount: number?): Tally
	local count = teamCount or LeagueRules.TEAM_COUNT
	local wins, last = {}, {}
	for index = 1, count do
		wins[index] = 0
		last[index] = 0
	end
	return { wins = wins, last = last, total = 0 }
end

local function wholeNumber(value: any): number
	if type(value) == "number" and value == value and value >= 0 and value < 1e9 then
		return math.floor(value)
	end
	return 0
end

-- Make a tally from anything read from a DataStore (nil, junk or a half-filled table all become a safe tally).
function LeagueRules.sanitize(raw: any, teamCount: number?): Tally
	local tally = LeagueRules.newTally(teamCount)
	if type(raw) ~= "table" then
		return tally
	end
	local wins, last = raw.wins, raw.last
	for index = 1, #tally.wins do
		tally.wins[index] = if type(wins) == "table" then wholeNumber(wins[index]) else 0
		tally.last[index] = if type(last) == "table" then wholeNumber(last[index]) else 0
	end
	tally.total = wholeNumber(raw.total)
	return tally
end

function LeagueRules.copy(tally: Tally): Tally
	return LeagueRules.sanitize(tally, #tally.wins)
end

-- Add one war won by `team` (1..n). Returns false for a team that does not exist (nothing changes).
function LeagueRules.addWin(tally: Tally, team: any): boolean
	if type(team) ~= "number" or team ~= math.floor(team) or team < 1 or team > #tally.wins then
		return false
	end
	tally.total += 1
	tally.wins[team] += 1
	tally.last[team] = tally.total
	return true
end

function LeagueRules.winsOf(tally: Tally, team: number): number
	return tally.wins[team] or 0
end

-- The best team first: most wins, then whoever got there earlier. Each entry is { team, wins }.
function LeagueRules.standings(tally: Tally): { { team: number, wins: number } }
	local list = {}
	for team, wins in tally.wins do
		table.insert(list, { team = team, wins = wins })
	end
	table.sort(list, function(a, b)
		if a.wins ~= b.wins then
			return a.wins > b.wins
		end
		local lastA, lastB = tally.last[a.team] or 0, tally.last[b.team] or 0
		if lastA ~= lastB then
			return lastA < lastB
		end
		return a.team < b.team
	end)
	return list
end

-- The winning team of a tally, or 0 when no war was won.
function LeagueRules.winner(tally: Tally): number
	local best = LeagueRules.standings(tally)[1]
	if best and best.wins > 0 then
		return best.team
	end
	return 0
end

return LeagueRules
