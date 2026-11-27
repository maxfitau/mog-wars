--!strict
-- Plain-Luau tests, no Roblox needed. Run from the repo root with the standalone Luau runtime:
--   luau tests/HintRules.test.luau
-- STATUS: written but NOT yet run (no Luau runtime in the cloud session). Run it on a PC first.

local HintRules = require("../src/shared/HintRules")

local failures = 0

local function check(name: string, condition: boolean)
	if condition then
		print("PASS " .. name)
	else
		failures += 1
		print("FAIL " .. name)
	end
end

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-6
end

-- facing north (negative z)
check("a target straight ahead is 0 degrees", near(HintRules.arrowAngle(0, -10, 0, -1), 0))
check("a target to the right is 90 degrees", near(HintRules.arrowAngle(10, 0, 0, -1), 90))
check("a target to the left is -90 degrees", near(HintRules.arrowAngle(-10, 0, 0, -1), -90))
check("a target behind is 180 degrees", near(math.abs(HintRules.arrowAngle(0, 10, 0, -1)), 180))
-- facing east (positive x): north is now on the left
check("facing east, a target to the north is to the left", near(HintRules.arrowAngle(0, -10, 1, 0), -90))
check("look direction length does not matter", near(HintRules.arrowAngle(10, 0, 0, -5), 90))
check("diagonal ahead and right is 45 degrees", near(HintRules.arrowAngle(10, -10, 0, -1), 45))
check("bad input gives 0", HintRules.arrowAngle(0 / 0, 1, 0, -1) == 0 and HintRules.arrowAngle(1, 1, 0, 0) == 0 and HintRules.arrowAngle(0, 0, 0, -1) == 0)

local zones = { { x = 60, z = 0 }, { x = -10, z = 5 }, { x = 0, z = -60 } }
check("the nearest zone is found", HintRules.nearest(0, 0, zones) == 2)
check("it changes as you move", HintRules.nearest(55, 3, zones) == 1)
check("no zones gives nil", HintRules.nearest(0, 0, {}) == nil)
check("a bad position gives nil", HintRules.nearest(0 / 0, 0, zones) == nil)
check("ties go to the earlier zone", HintRules.nearest(0, 0, { { x = 5, z = 0 }, { x = -5, z = 0 } }) == 1)

if failures > 0 then
	error(failures .. " test(s) failed")
end
print("All tests passed")
