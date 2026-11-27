--!strict
-- Plain-Luau tests, no Roblox needed. Run from the repo root with the standalone Luau runtime:
--   luau tests/SquadSeasonRules.test.luau
-- STATUS: written but NOT yet run (no Luau runtime in the cloud session). Run it on a PC first.

local SquadRules = require("../src/shared/SquadRules")
local SeasonRules = require("../src/shared/SeasonRules")
local Config = require("../src/shared/EconomyConfig")

local failures = 0

local function check(name: string, condition: boolean)
	if condition then
		print("PASS " .. name)
	else
		failures += 1
		print("FAIL " .. name)
	end
end

-- ---------- squad ----------
local friends: { [string]: boolean } = { ["1:2"] = true, ["1:3"] = true, ["2:3"] = true, ["4:5"] = true }
local function areFriends(a: number, b: number): boolean
	return friends[math.min(a, b) .. ":" .. math.max(a, b)] == true
end

do
	local counts = SquadRules.friendCounts({
		{ id = 1, faction = 1 },
		{ id = 2, faction = 1 },
		{ id = 3, faction = 1 },
		{ id = 4, faction = 1 },
	}, areFriends)
	check("three mutual friends each have two friends", counts[1] == 2 and counts[2] == 2 and counts[3] == 2)
	check("a player with no friends in the capture has none", counts[4] == 0)
end
do
	local counts = SquadRules.friendCounts({ { id = 1, faction = 1 }, { id = 2, faction = 2 } }, areFriends)
	check("friends on different factions do not count", counts[1] == 0 and counts[2] == 0)
end

local squad = Config.squad
check("no friends gives no bonus", SquadRules.bonusPoints(100, 0, squad) == 0)
check("one friend gives the per-friend bonus", SquadRules.bonusPoints(100, 1, squad) == math.floor(100 * squad.perFriendBonus))
check("the bonus is capped at maxFriends", SquadRules.bonusPoints(100, 99, squad) == SquadRules.bonusPoints(100, squad.maxFriends, squad))
check("a bad base gives nothing", SquadRules.bonusPoints(0 / 0, 2, squad) == 0 and SquadRules.bonusPoints(-5, 2, squad) == 0)
check("a bad friend count gives nothing", SquadRules.bonusPoints(100, 0 / 0, squad) == 0)
check("the top bonus is at most 50 percent (healthy)", squad.perFriendBonus * squad.maxFriends <= 0.5)

-- ---------- season ----------
local settings = Config.season

-- week math: 2026-11-30 is a Monday, so it starts a new week
local monday = 1796000000 -- any time; compute by shifting
local thisWeek = SeasonRules.weekIndex(monday)
check("the week ends exactly when the next week begins", SeasonRules.weekIndex(SeasonRules.weekEnds(thisWeek) - 1) == thisWeek and SeasonRules.weekIndex(SeasonRules.weekEnds(thisWeek)) == thisWeek + 1)
check("a week is seven days", SeasonRules.weekEnds(thisWeek + 1) - SeasonRules.weekEnds(thisWeek) == 7 * 86400)
check("weeks end on a Monday (day number + 3 divisible by 7)", (math.floor(SeasonRules.weekEnds(thisWeek) / 86400) + 3) % 7 == 0)

check("capture points follow zone value", SeasonRules.pointsFor("capture", 2, settings) == 2 * settings.pointsPerZoneValue)
check("a bad zone value gives no points", SeasonRules.pointsFor("capture", -1, settings) == 0 and SeasonRules.pointsFor("capture", 0 / 0, settings) == 0)
check("war and duel wins give their points", SeasonRules.pointsFor("warWin", 1, settings) == settings.pointsWarWin and SeasonRules.pointsFor("mogOffWin", 1, settings) == settings.pointsMogOffWin)
check("an unknown kind gives nothing", SeasonRules.pointsFor("cheat", 99, settings) == 0)

do
	local season = SeasonRules.newSeason()
	check("adding points works", SeasonRules.addPoints(season, 2, 5, 100) and season.week == 100 and season.points["2"] == 5)
	check("more points add up", SeasonRules.addPoints(season, 2, 3, 100) and season.points["2"] == 8)
	check("points can be earned for another faction", SeasonRules.addPoints(season, 3, 4, 100) and SeasonRules.total(season.points) == 12)
	check("a bad amount is refused", not SeasonRules.addPoints(season, 2, 0, 100) and not SeasonRules.addPoints(season, 2, 0 / 0, 100) and not SeasonRules.addPoints(season, 0, 5, 100))
	-- next week: the old week becomes previous
	check("a new week rolls the season forward", SeasonRules.addPoints(season, 1, 7, 101) and season.week == 101 and season.prevWeek == 100 and season.prevPoints["2"] == 8 and season.points["1"] == 7 and season.points["2"] == nil)
	-- skipping a week loses the old standings
	SeasonRules.addPoints(season, 1, 1, 105)
	check("skipping weeks forfeits the old reward", season.prevWeek == 0 and next(season.prevPoints) == nil)
	check("rolling to an older week does nothing", not SeasonRules.roll(season, 50))
end

check("the highest faction wins", SeasonRules.winner({ [1] = 10, [2] = 30, [3] = 5 }) == 2)
check("a tie at the top is nobody", SeasonRules.winner({ [1] = 30, [2] = 30 }) == 0)
check("no points is nobody", SeasonRules.winner({}) == 0 and SeasonRules.winner({ [1] = 0, [2] = 0 }) == 0)

do
	local season = SeasonRules.newSeason()
	season.prevWeek, season.prevPoints, season.claimed = 100, { ["2"] = settings.minPoints }, 99
	check("enough points for the winning faction earns the reward", SeasonRules.eligible(season, 2, settings))
	check("points for another faction do not", not SeasonRules.eligible(season, 3, settings))
	check("no winner means no reward", not SeasonRules.eligible(season, 0, settings))
	season.prevPoints["2"] = settings.minPoints - 1
	check("too few points earns nothing", not SeasonRules.eligible(season, 2, settings))
	season.prevPoints["2"] = settings.minPoints
	season.claimed = 100
	check("an already resolved week cannot be claimed again", not SeasonRules.eligible(season, 2, settings) and not SeasonRules.hasUnresolvedReward(season))
end

if failures > 0 then
	error(failures .. " test(s) failed")
end
print("All tests passed")
