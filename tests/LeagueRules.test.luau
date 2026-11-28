--!strict
-- Plain-Luau tests, no Roblox needed. Run from the repo root with the standalone Luau runtime:
--   luau tests/LeagueRules.test.luau
-- STATUS: written but NOT yet run (no Luau runtime in the cloud session). Run it on a PC first.

local LeagueRules = require("../src/shared/LeagueRules")

local failures = 0

local function check(name: string, condition: boolean)
	if condition then
		print("PASS " .. name)
	else
		failures += 1
		print("FAIL " .. name)
	end
end

-- weeks start Monday 00:00 UTC: 2026-11-23 is a Monday
local MONDAY = 1795392000
local week = LeagueRules.weekIndex(MONDAY)
check("Monday 00:00 starts the week", LeagueRules.weekStart(week) == MONDAY)
check("the last second of Sunday is the week before", LeagueRules.weekIndex(MONDAY - 1) == week - 1)
check("Saturday is still the same week", LeagueRules.weekIndex(MONDAY + 5 * 86400 + 3600) == week)
check("next Monday is the next week", LeagueRules.weekIndex(MONDAY + 7 * 86400) == week + 1)
check("seconds to the next week", LeagueRules.secondsToNextWeek(MONDAY + 86400) == 6 * 86400)
check("the epoch's first week", LeagueRules.weekIndex(4 * 86400) == 0 and LeagueRules.weekIndex(4 * 86400 - 1) == -1)

local tally = LeagueRules.newTally()
check("new tally has four teams", #tally.wins == 4)
check("nobody wins an empty week", LeagueRules.winner(tally) == 0)

check("add a win", LeagueRules.addWin(tally, 2))
check("the win counted", LeagueRules.winsOf(tally, 2) == 1 and tally.total == 1)
check("one win makes a winner", LeagueRules.winner(tally) == 2)
check("team 0 is refused", not LeagueRules.addWin(tally, 0))
check("team 5 is refused", not LeagueRules.addWin(tally, 5))
check("a fraction is refused", not LeagueRules.addWin(tally, 1.5))
check("a string is refused", not LeagueRules.addWin(tally, "2"))
check("refused wins change nothing", tally.total == 1)

-- most wars wins
LeagueRules.addWin(tally, 3)
LeagueRules.addWin(tally, 3)
check("most wars won wins the week", LeagueRules.winner(tally) == 3)

-- tie-break: the team that reached the number first (team 2 got its 1st win at #1, team 3 got its 2nd at #3)
LeagueRules.addWin(tally, 2) -- #4: 2 and 3 both have 2 wins; team 3 reached 2 at #3, team 2 at #4
check("tie goes to the team that got there first", LeagueRules.winner(tally) == 3)
LeagueRules.addWin(tally, 2) -- team 2 now has 3
check("then the leader wins again", LeagueRules.winner(tally) == 2)

local standings = LeagueRules.standings(tally)
check("standings are sorted", standings[1].team == 2 and standings[1].wins == 3 and standings[2].team == 3)
check("standings list every team", #standings == 4)
check("losers are last", standings[4].wins == 0)

-- equal at zero: the lowest team id, but nobody wins
local empty = LeagueRules.newTally()
check("zero wins everywhere sorts by team id", LeagueRules.standings(empty)[1].team == 1)
check("zero wins is no winner", LeagueRules.winner(empty) == 0)

-- sanitize: junk from a DataStore never breaks anything
local junk = LeagueRules.sanitize("hello")
check("a string becomes an empty tally", junk.total == 0 and #junk.wins == 4)
local half = LeagueRules.sanitize({ wins = { 3, "x", -2 }, total = 3 })
check("half-filled keeps good numbers", half.wins[1] == 3)
check("bad and negative numbers become 0", half.wins[2] == 0 and half.wins[3] == 0 and half.wins[4] == 0)
check("nil becomes an empty tally", LeagueRules.sanitize(nil).total == 0)
local copy = LeagueRules.copy(tally)
LeagueRules.addWin(copy, 1)
check("a copy is separate", LeagueRules.winsOf(tally, 1) == 0 and LeagueRules.winsOf(copy, 1) == 1)
check("a copy keeps the numbers", copy.total == tally.total + 1 and copy.wins[2] == 3)

if failures > 0 then
	error(("%d test(s) failed"):format(failures))
end
print("all LeagueRules tests passed")
