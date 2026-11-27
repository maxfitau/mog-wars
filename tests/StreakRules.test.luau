--!strict
-- Plain-Luau tests, no Roblox needed. Run from the repo root with the standalone Luau runtime:
--   luau tests/StreakRules.test.luau
-- STATUS: written but NOT yet run (no Luau runtime in the cloud session). Run it on a PC first.

local StreakRules = require("../src/shared/StreakRules")
local BarracksRules = require("../src/shared/BarracksRules")
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

local length = #Config.dailyStreak.rewards
check("the streak is 7 days", length == 7)
for day, tier in Config.dailyStreak.rewards do
	check("streak day " .. day .. " names a real box tier", Config.boxes.tiers[tier] ~= nil)
end

-- first claim ever
do
	local ok, reason, day = StreakRules.claim(0, 0, 20000, length)
	check("first claim is day 1", ok and reason == nil and day == 1)
end
-- same day blocked
do
	local ok, reason = StreakRules.claim(3, 20000, 20000, length)
	check("a second claim the same day is refused", not ok and reason == "already_claimed")
end
-- next day continues
do
	local ok, _, day = StreakRules.claim(3, 20000, 20001, length)
	check("the next day continues the streak", ok and day == 4)
end
-- gap resets
do
	local ok, _, day = StreakRules.claim(5, 20000, 20002, length)
	check("skipping a day starts again at day 1", ok and day == 1)
end
-- cycle wraps
do
	local ok, _, day = StreakRules.claim(7, 20000, 20001, length)
	check("after day 7 it wraps to day 1", ok and day == 1)
end
-- clock moved back
do
	local ok, reason = StreakRules.claim(3, 20005, 20000, length)
	check("a saved day in the future is refused", not ok and reason == "clock_error")
end
-- bad input
check("nan is refused", select(2, StreakRules.claim(0 / 0, 0, 1, length)) == "bad_input")
check("zero length is refused", select(2, StreakRules.claim(0, 0, 1, 0)) == "bad_input")

-- preview
do
	local can, day = StreakRules.preview(2, 20000, 20001, length)
	check("preview says claim day 3", can and day == 3)
	local canNot, tomorrow = StreakRules.preview(2, 20000, 20000, length)
	check("preview after claiming shows tomorrow", not canNot and tomorrow == 3)
end

-- a full week of daily claims walks through the days 1 to 7
do
	local streak, last = 0, 0
	local seen = {}
	for step = 1, 7 do
		local ok, _, day = StreakRules.claim(streak, last, 20000 + step, length)
		if ok then
			streak, last = day, 20000 + step
			table.insert(seen, day)
		end
	end
	check("seven days in a row give days 1 to 7", table.concat(seen, ",") == "1,2,3,4,5,6,7")
end

-- barracks
local settings = Config.barracks
check("rank 1 pays the base rate", BarracksRules.ratePerHour(1, settings) == settings.baseRatePerHour)
check("each rank adds to the rate", BarracksRules.ratePerHour(3, settings) == settings.baseRatePerHour + 2 * settings.perRankRatePerHour)
check("an unstarted barracks pays nothing", BarracksRules.pending(100000, 0, 1, settings) == 0)
check("no time passed pays nothing", BarracksRules.pending(5000, 5000, 1, settings) == 0)
do
	local oneHour = BarracksRules.pending(5000 + 3600, 5000, 1, settings)
	check("one hour pays one hour of income", oneHour == settings.baseRatePerHour)
	local capped = BarracksRules.pending(5000 + 3600 * 100, 5000, 1, settings)
	check("income stops at the storage cap", capped == settings.baseRatePerHour * settings.maxStoredHours)
	local future = BarracksRules.pending(5000, 9000, 1, settings)
	check("a start time in the future pays nothing", future == 0)
	check("normalize pulls a future start back to now", BarracksRules.normalize(5000, 9000) == 5000)
end
check("nan time pays nothing", BarracksRules.pending(0 / 0, 5000, 1, settings) == 0)

if failures > 0 then
	error(failures .. " test(s) failed")
end
print("All tests passed")
