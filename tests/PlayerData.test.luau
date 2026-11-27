--!strict
-- Plain-Luau tests, no Roblox needed. Run from the repo root with the standalone Luau runtime:
--   luau tests/PlayerData.test.luau
-- STATUS: written but NOT yet run (no Luau runtime in the cloud session). Run it on a PC first.

local PlayerData = require("../src/shared/PlayerData")

local failures = 0

local function check(name: string, condition: boolean)
	if condition then
		print("PASS " .. name)
	else
		failures += 1
		print("FAIL " .. name)
	end
end

local data = PlayerData.template()
check("template is valid", PlayerData.isValid(data))
check("new players start at Rookie with 0 points", data.rank == 1 and data.points == 0)

check("adding points works", PlayerData.addPoints(data, 50) and data.points == 50)
check("zero is rejected", not PlayerData.addPoints(data, 0) and data.points == 50)
check("negative is rejected", not PlayerData.addPoints(data, -5) and data.points == 50)
check("fraction is rejected", not PlayerData.addPoints(data, 1.5) and data.points == 50)
check("nan is rejected", not PlayerData.addPoints(data, 0 / 0) and data.points == 50)
check("infinity is rejected", not PlayerData.addPoints(data, math.huge) and data.points == 50)

check("spending works", PlayerData.spendPoints(data, 20) and data.points == 30)
check("overspending changes nothing", not PlayerData.spendPoints(data, 31) and data.points == 30)
check("spending a bad amount changes nothing", not PlayerData.spendPoints(data, -1) and data.points == 30)

local rich = PlayerData.template()
rich.points = PlayerData.MAX_POINTS - 1
PlayerData.addPoints(rich, 100)
check("points never pass the cap", rich.points == PlayerData.MAX_POINTS)

check("bad shapes are invalid", not PlayerData.isValid(nil) and not PlayerData.isValid({}))
check("wrong version is invalid", not PlayerData.isValid({ version = 0, points = 0, rank = 1 }))
check("negative points are invalid", not PlayerData.isValid({ version = 1, points = -1, rank = 1 }))
check("rank 0 is invalid", not PlayerData.isValid({ version = 1, points = 0, rank = 0 }))

if failures > 0 then
	error(failures .. " test(s) failed")
end
print("All tests passed")
