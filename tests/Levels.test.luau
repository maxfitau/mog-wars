--!strict
-- luau tests/Levels.test.luau  (STATUS: not run in the cloud session, no Luau runtime)
local Levels = require("../src/shared/Levels")
local failures = 0
local function check(name: string, condition: boolean)
	if not condition then
		failures += 1
		print("FAIL " .. name)
	end
end
local names = { "NPC", "Rookie", "Sigma", "Chadlite", "Chad", "Gigachad", "Mog God" }
check("level 0 is NPC", Levels.name(0, names) == "NPC" and Levels.rankOfLevel(0) == 1)
check("level 1 is Rookie I", Levels.name(1, names) == "Rookie I" and Levels.rankOfLevel(1) == 2)
check("level 10 is Rookie X", Levels.name(10, names) == "Rookie X")
check("level 11 is Sigma I", Levels.name(11, names) == "Sigma I" and Levels.rankOfLevel(11) == 3)
check("level 51 is Mog God I", Levels.name(51, names) == "Mog God I" and Levels.rankOfLevel(51) == 7)
check("level 60 is Mog God X", Levels.name(60, names) == "Mog God X")
check("level 65 is a star level", Levels.name(65, names) == "Mog God ★5" and Levels.rankOfLevel(65) == 7)
check("multiplier grows each level", Levels.multiplier(2) > Levels.multiplier(1) and Levels.multiplier(0) == 1)
check("thresholds rise", Levels.cumulative(5) > Levels.cumulative(4) and Levels.cumulative(0) == 0)
check("level from aura round-trips", Levels.levelForAura(Levels.cumulative(20)) == 20)
check("just under is the level below", Levels.levelForAura(Levels.cumulative(20) - 1) == 19)
check("bad aura is level 0", Levels.levelForAura(0 / 0) == 0 and Levels.levelForAura(-5) == 0)
check("sort key rises with aura", Levels.sortKey(1e15) > Levels.sortKey(1e6))
check("sort key fits a leaderboard", Levels.sortKey(1e300) < 9e18)
if failures > 0 then
	error(failures .. " test(s) failed")
end
print("All tests passed")
