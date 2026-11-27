--!strict
-- Plain-Luau tests, no Roblox needed. Run from the repo root with the standalone Luau runtime:
--   luau tests/TrainingRules.test.luau
-- STATUS: written but NOT yet run (no Luau runtime in the cloud session). Run it on a PC first.

local TrainingRules = require("../src/shared/TrainingRules")
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

local settings = Config.training

check("level 0 costs the first-level time", TrainingRules.levelCost(0, settings) == settings.firstLevelSeconds)
check("each level costs a step more", TrainingRules.levelCost(3, settings) == settings.firstLevelSeconds + 3 * settings.stepSeconds)
check("a bad level costs the first-level time", TrainingRules.levelCost(0 / 0, settings) == settings.firstLevelSeconds)

check("aura at level 0 is 1", TrainingRules.auraMultiplier(0, settings) == 1)
check("aura at the top level is about 1.9", math.abs(TrainingRules.auraMultiplier(settings.maxLevel, settings) - 1.9) < 1e-9)
check("aura never goes past the top level", TrainingRules.auraMultiplier(999, settings) == TrainingRules.auraMultiplier(settings.maxLevel, settings))
check("negative levels count as 0", TrainingRules.auraMultiplier(-3, settings) == 1)
check("the top aura is at most 2x (PRD limit)", TrainingRules.auraMultiplier(settings.maxLevel, settings) <= 2)

-- daily cap
check("strides are allowed under the cap", TrainingRules.allowedStrides(0, 1, settings) == 1)
check("strides stop at the cap", TrainingRules.allowedStrides(settings.dailyStrideCap, 1, settings) == 0)
check("a big offer is trimmed to what is left", TrainingRules.allowedStrides(settings.dailyStrideCap - 5, 100, settings) == 5)
check("a negative offer is nothing", TrainingRules.allowedStrides(0, -4, settings) == 0)
check("nan offers are nothing", TrainingRules.allowedStrides(0 / 0, 1, settings) == 0)

-- adding strides
do
	local level, progress, gained = TrainingRules.addStrides(0, 0, settings.firstLevelSeconds - 1, settings)
	check("one stride short of a level gains nothing", level == 0 and progress == settings.firstLevelSeconds - 1 and gained == 0)
	local level2, progress2, gained2 = TrainingRules.addStrides(level, progress, 1, settings)
	check("the last stride gains a level", level2 == 1 and progress2 == 0 and gained2 == 1)
end
do
	local first, second = settings.firstLevelSeconds, settings.firstLevelSeconds + settings.stepSeconds
	local level, progress, gained = TrainingRules.addStrides(0, 0, first + second + 7, settings)
	check("a big batch can gain several levels", level == 2 and progress == 7 and gained == 2)
end
do
	local level, progress, gained = TrainingRules.addStrides(settings.maxLevel, 0, 500, settings)
	check("nothing is gained at the top level", level == settings.maxLevel and progress == 0 and gained == 0)
	local nearTop = TrainingRules.totalToReach(settings.maxLevel, settings)
	local l, p = TrainingRules.addStrides(0, 0, nearTop + 999, settings)
	check("the total to reach the top lands exactly on the top level", l == settings.maxLevel and p == 0)
end
check("zero strides change nothing", select(3, TrainingRules.addStrides(2, 10, 0, settings)) == 0)
check("nan strides change nothing", select(3, TrainingRules.addStrides(2, 10, 0 / 0, settings)) == 0)

-- pacing target: the top level takes about three weeks at the daily cap (not instant, not endless)
local days = TrainingRules.totalToReach(settings.maxLevel, settings) / settings.dailyStrideCap
check("the top level takes between 2 and 6 weeks at the daily cap", days >= 14 and days <= 42)

-- running check
check("walking on a treadmill counts", TrainingRules.isRunning(1, true, true))
check("standing still does not count", not TrainingRules.isRunning(0, true, true))
check("walking off the treadmill does not count", not TrainingRules.isRunning(1, false, true))
check("a dead player does not count", not TrainingRules.isRunning(1, true, false))
check("nan movement does not count", not TrainingRules.isRunning(0 / 0, true, true))

if failures > 0 then
	error(failures .. " test(s) failed")
end
print("All tests passed")
