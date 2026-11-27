--!strict
-- Plain-Luau tests, no Roblox needed. Run from the repo root with the standalone Luau runtime:
--   luau tests/UnitRules.test.luau
-- STATUS: written but NOT yet run (no Luau runtime in the cloud session). Run it on a PC first.

local UnitRules = require("../src/shared/UnitRules")
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

-- the real config boosts are inside the limits
check("tank boost is inside the limits", UnitRules.validMultiplier(Config.units.tank.captureMultiplier))
check("horse boost is inside the limits", UnitRules.validMultiplier(Config.units.horse.speedMultiplier))
check("units have positive sell values", Config.units.tank.sellValue > 0 and Config.units.horse.sellValue > 0)

-- limits
check("1 is allowed", UnitRules.validMultiplier(1))
check("2 is allowed", UnitRules.validMultiplier(2))
check("2.01 is not allowed", not UnitRules.validMultiplier(2.01))
check("below 1 is not allowed", not UnitRules.validMultiplier(0.9))
check("nan is not allowed", not UnitRules.validMultiplier(0 / 0))
check("infinity is not allowed", not UnitRules.validMultiplier(math.huge))

-- tank power
check("tank boosts power", UnitRules.boostedPower(4, 1.5) == 6)
check("a bad boost is ignored", UnitRules.boostedPower(4, 50) == 4)
check("negative power becomes zero", UnitRules.boostedPower(-3, 1.5) == 0)
check("nan power becomes zero", UnitRules.boostedPower(0 / 0, 1.5) == 0)

-- horse speed
check("a horse speeds you up", math.abs(UnitRules.walkSpeed(16, true, 1.3) - 20.8) < 1e-9)
check("not riding keeps the speed", UnitRules.walkSpeed(16, false, 1.3) == 16)
check("a bad base speed falls back to 16", UnitRules.walkSpeed(0 / 0, true, 1.3) == 16)
check("a bad boost leaves the speed alone", UnitRules.walkSpeed(16, true, 5) == 16)

-- deploy rules
local ready = { warOn = true, owned = 1, alive = true, inZone = true, tankInZone = false, riding = false }
local function with(overrides: { [string]: any }): UnitRules.DeployContext
	local copy: any = table.clone(ready)
	for key, value in overrides do
		copy[key] = value
	end
	return copy
end

check("a tank can be deployed in a zone", UnitRules.canDeploy("tank", ready))
check("a horse can be deployed anywhere", UnitRules.canDeploy("horse", with({ inZone = false })))
check("unknown units are refused", select(2, UnitRules.canDeploy("rocket", ready)) == "unknown_unit")
check("nothing deploys between wars", select(2, UnitRules.canDeploy("tank", with({ warOn = false }))) == "not_war")
check("dead players cannot deploy", select(2, UnitRules.canDeploy("tank", with({ alive = false }))) == "not_alive")
check("you need to own one", select(2, UnitRules.canDeploy("tank", with({ owned = 0 }))) == "no_unit")
check("a tank needs a zone", select(2, UnitRules.canDeploy("tank", with({ inZone = false }))) == "not_in_zone")
check("one tank per zone per faction", select(2, UnitRules.canDeploy("tank", with({ tankInZone = true }))) == "tank_exists")
check("no double horses", select(2, UnitRules.canDeploy("horse", with({ riding = true }))) == "already_riding")

if failures > 0 then
	error(failures .. " test(s) failed")
end
print("All tests passed")
