--!strict
-- Plain-Luau tests, no Roblox needed. Run from the repo root with the standalone Luau runtime:
--   luau tests/ZoneGeometry.test.luau
-- STATUS: written but NOT yet run (no Luau runtime in the cloud session). Run it on a PC first.

local ZoneGeometry = require("../src/shared/ZoneGeometry")

local failures = 0

local function check(name: string, condition: boolean)
	if condition then
		print("PASS " .. name)
	else
		failures += 1
		print("FAIL " .. name)
	end
end

local function inside(x: number, y: number, z: number): boolean
	return ZoneGeometry.contains(x, y, z, 30, 1, 30, 8)
end

check("centre standing on the zone is inside", inside(0, 3, 0))
check("edge is inside", inside(15, 1, -15))
check("just outside the footprint is outside", not inside(15.1, 1, 0) and not inside(0, 1, -15.1))
check("too high above is outside", not inside(0, 9, 0))
check("below the zone is outside", not inside(0, -1, 0))
check("nan is outside", not inside(0 / 0, 1, 0))
check("infinity is outside", not inside(math.huge, 1, 0))
check("nan size is outside", not ZoneGeometry.contains(0, 1, 0, 0 / 0, 1, 30, 8))

if failures > 0 then
	error(failures .. " test(s) failed")
end
print("All tests passed")
