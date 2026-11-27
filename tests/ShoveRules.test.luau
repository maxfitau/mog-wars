--!strict
-- Plain-Luau tests, no Roblox needed. Run from the repo root with the standalone Luau runtime:
--   luau tests/ShoveRules.test.luau
-- STATUS: written but NOT yet run (no Luau runtime in the cloud session). Run it on a PC first.

local ShoveRules = require("../src/shared/ShoveRules")

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
	cooldownSeconds = 6,
	range = 8,
	penaltySeconds = 3,
	penaltyMultiplier = 0.5,
	minRequestInterval = 0.2,
}

-- spam guard and cooldown
check("a request 0.1s after the last is too fast", ShoveRules.tooFast(10.1, 10, settings))
check("a request 0.3s after the last is fine", not ShoveRules.tooFast(10.3, 10, settings))
check("cooldown blocks at 5.9s", not ShoveRules.offCooldown(15.9, 10, settings))
check("cooldown ends at 6s", ShoveRules.offCooldown(16, 10, settings))
check("a never-shoved player can shove", ShoveRules.offCooldown(100, -1000, settings))

-- target picking
local function candidate(id: number, x: number, faction: number, alive: boolean?): ShoveRules.Candidate
	return { id = id, x = x, y = 0, z = 0, faction = faction, alive = alive ~= false }
end

do
	local id = ShoveRules.pickTarget(0, 0, 0, 1, { candidate(2, 5, 2), candidate(3, 3, 3) }, settings)
	check("picks the nearest enemy", id == 3)
end
do
	local id, reason = ShoveRules.pickTarget(0, 0, 0, 1, { candidate(2, 9, 2) }, settings)
	check("out of range is no target", id == nil and reason == "no_target")
end
do
	local id = ShoveRules.pickTarget(0, 0, 0, 1, { candidate(2, 8, 2) }, settings)
	check("exactly at range counts", id == 2)
end
do
	local id = ShoveRules.pickTarget(0, 0, 0, 1, { candidate(2, 2, 1) }, settings)
	check("teammates are never targets", id == nil)
end
do
	local id = ShoveRules.pickTarget(0, 0, 0, 1, { candidate(2, 2, 2, false) }, settings)
	check("dead players are never targets", id == nil)
end
do
	local id = ShoveRules.pickTarget(0, 0, 0, 1, { candidate(2, 2, 0) }, settings)
	check("players without a faction are never targets", id == nil)
end
do
	local id, reason = ShoveRules.pickTarget(0 / 0, 0, 0, 1, { candidate(2, 2, 2) }, settings)
	check("nan position is rejected", id == nil and reason == "bad_input")
end
do
	local id, reason = ShoveRules.pickTarget(0, 0, 0, 0, { candidate(2, 2, 2) }, settings)
	check("shover without a faction is rejected", id == nil and reason == "bad_input")
end
do
	local id = ShoveRules.pickTarget(0, 0, 0, 1, { candidate(5, 4, 2), candidate(4, 4, 3) }, settings)
	check("equal distance picks the lowest id", id == 4)
end

-- direction
do
	local dx, dz = ShoveRules.direction(0, 0, 3, 4)
	check("direction is a unit vector", math.abs(dx - 0.6) < 1e-9 and math.abs(dz - 0.8) < 1e-9)
	local ox, oz = ShoveRules.direction(1, 1, 1, 1)
	check("overlapping gives a safe default", ox == 0 and oz == 1)
end

-- penalty
check("power is halved during the penalty", ShoveRules.powerMultiplier(10, 12, settings) == 0.5)
check("power is normal after the penalty", ShoveRules.powerMultiplier(12, 12, settings) == 1)

if failures > 0 then
	error(failures .. " test(s) failed")
end
print("All tests passed")
