--!strict
-- Plain-Luau tests, no Roblox needed. Run from the repo root with the standalone Luau runtime:
--   luau tests/WarRules.test.luau
-- STATUS: written but NOT yet run (no Luau runtime in the cloud session). Run it on a PC first.

local WarRules = require("../src/shared/WarRules")

local failures = 0

local function check(name: string, condition: boolean)
	if condition then
		print("PASS " .. name)
	else
		failures += 1
		print("FAIL " .. name)
	end
end

local zones = {
	{ owner = 1, value = 1 },
	{ owner = 1, value = 1 },
	{ owner = 2, value = 2 },
	{ owner = 0, value = 1 },
	{ owner = 3, value = 1 },
}
local scores = WarRules.scores(zones)
check("scores add zone values per faction", scores[1] == 2 and scores[2] == 2 and scores[3] == 1)
check("unowned zones score for nobody", scores[0] == nil)

check("a clear lead wins", WarRules.winner({ [1] = 3, [2] = 2 }, {}) == 1)
check("a tie goes to more captures", WarRules.winner({ [1] = 2, [2] = 2 }, { [1] = 1, [2] = 3 }) == 2)
check("a tie with equal captures is a draw", WarRules.winner({ [1] = 2, [2] = 2 }, { [1] = 2, [2] = 2 }) == 0)
check("nobody holding anything is a draw", WarRules.winner({}, {}) == 0)
check("a three-way tie is decided by captures", WarRules.winner({ [1] = 1, [2] = 1, [3] = 1 }, { [3] = 2 }) == 3)

local options = { winnerBonus = 60, participantBonus = 20, minUnits = 5 }
local players = {
	[10] = { faction = 1, units = 30 }, -- winner and contributed
	[11] = { faction = 1, units = 2 }, -- winner but idle
	[12] = { faction = 2, units = 8 }, -- loser who contributed
}
local bonuses = WarRules.bonuses(1, players, options)
check("winner contributor gets both bonuses", bonuses[10] == 80)
check("idle winner gets nothing", bonuses[11] == nil)
check("loser contributor gets the participant bonus", bonuses[12] == 20)
check("a draw has no winner bonus", WarRules.bonuses(0, players, options)[10] == 20)

check("multiplier halves", WarRules.applyMultiplier(80, 0.5) == 40)
check("multiplier never rounds a reward to zero", WarRules.applyMultiplier(1, 0.5) == 1)
check("bad multiplier pays nothing", WarRules.applyMultiplier(80, 0) == 0 and WarRules.applyMultiplier(80, 0 / 0) == 0)
check("bad amount pays nothing", WarRules.applyMultiplier(-5, 1) == 0)

check("a 12 minute war is allowed", WarRules.clampWarSeconds(720) == 720)
check("a 6 minute war is allowed", WarRules.clampWarSeconds(360) == 360)
check("a 1 minute war is raised to 3", WarRules.clampWarSeconds(60) == 180)
check("a 30 minute war is cut to 15", WarRules.clampWarSeconds(1800) == 900)
check("a nan length falls back to 3 minutes", WarRules.clampWarSeconds(0 / 0) == 180)

check("phase cycle", WarRules.nextPhase("War") == "Intermission" and WarRules.nextPhase("Intermission") == "War")
check("phase lengths", WarRules.phaseSeconds("War", 600, 20) == 600 and WarRules.phaseSeconds("Intermission", 600, 20) == 20)

if failures > 0 then
	error(failures .. " test(s) failed")
end
print("All tests passed")
