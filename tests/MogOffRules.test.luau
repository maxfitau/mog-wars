--!strict
-- Plain-Luau tests, no Roblox needed. Run from the repo root with the standalone Luau runtime:
--   luau tests/MogOffRules.test.luau
-- STATUS: written but NOT yet run (no Luau runtime in the cloud session). Run it on a PC first.

local MogOffRules = require("../src/shared/MogOffRules")

local failures = 0

local function check(name: string, condition: boolean)
	if condition then
		print("PASS " .. name)
	else
		failures += 1
		print("FAIL " .. name)
	end
end

local settings = {
	durationSeconds = 5,
	closeRange = 6,
	closeSeconds = 1.5,
	maxTapsPerSecond = 10,
	cooldownSeconds = 20,
}

check("close enough", MogOffRules.isClose(0, 0, 0, 3, 0, 4, settings))
check("just too far", not MogOffRules.isClose(0, 0, 0, 6.1, 0, 0, settings))
check("nan is never close", not MogOffRules.isClose(0 / 0, 0, 0, 0, 0, 0, settings))
check("cooldown blocks", not MogOffRules.offCooldown(119, 100, settings))
check("cooldown ends", MogOffRules.offCooldown(120, 100, settings))

-- a normal duel: A taps 4 times, B taps 3 times
do
	local duel = MogOffRules.newDuel(1, 2, 100, 0, settings)
	for step = 1, 4 do
		MogOffRules.registerTap(duel, 1, 100 + step * 0.5, settings)
	end
	for step = 1, 3 do
		MogOffRules.registerTap(duel, 2, 100 + step * 0.6, settings)
	end
	local outcome = MogOffRules.resolve(duel)
	check("more taps wins", outcome.winner == 1 and outcome.loser == 2 and outcome.tapsA == 4 and outcome.tapsB == 3)
end

-- timing windows
do
	local duel = MogOffRules.newDuel(1, 2, 100, 0, settings)
	check("a tap before the start is ignored", not MogOffRules.registerTap(duel, 1, 99.9, settings))
	check("a tap at the start counts", MogOffRules.registerTap(duel, 1, 100, settings))
	check("a tap at the end is ignored", not MogOffRules.registerTap(duel, 1, 105, settings))
	check("a stranger cannot tap", not MogOffRules.registerTap(duel, 3, 101, settings))
	check("nan time is ignored", not MogOffRules.registerTap(duel, 1, 0 / 0, settings))
end

-- the rate cap: a flood of 1000 taps in one second only counts 10
do
	local duel = MogOffRules.newDuel(1, 2, 100, 0, settings)
	for step = 1, 1000 do
		MogOffRules.registerTap(duel, 1, 100 + step * 0.0009, settings)
	end
	check("a tap flood is capped at 10 in a second", duel.taps[1] == 10)
	-- after the window passes, taps count again
	check("taps count again a second later", MogOffRules.registerTap(duel, 1, 101.5, settings))
end

-- a steady 10 per second over 5 seconds is the most anyone can get (about 50)
do
	local duel = MogOffRules.newDuel(1, 2, 100, 0, settings)
	for step = 0, 4999 do
		MogOffRules.registerTap(duel, 1, 100 + step * 0.001, settings)
	end
	check("a 5 second flood cannot exceed 50 taps", duel.taps[1] <= 50 and duel.taps[1] >= 40)
end

-- ties
do
	local duel = MogOffRules.newDuel(1, 2, 100, 2, settings)
	MogOffRules.registerTap(duel, 1, 101, settings)
	MogOffRules.registerTap(duel, 2, 101, settings)
	local outcome = MogOffRules.resolve(duel)
	check("a tie goes to the defender", outcome.winner == 2 and outcome.loser == 1)
end
do
	local duel = MogOffRules.newDuel(1, 2, 100, 0, settings)
	local outcome = MogOffRules.resolve(duel)
	check("a tie with no defender is a draw", outcome.winner == 0 and outcome.loser == 0)
end
do
	local duel = MogOffRules.newDuel(1, 2, 100, 99, settings)
	check("a defender who is not in the duel is ignored", duel.defender == 0)
end

if failures > 0 then
	error(failures .. " test(s) failed")
end
print("All tests passed")
