--!strict
-- Plain-Luau tests, no Roblox needed. Run from the repo root with the standalone Luau runtime:
--   luau tests/RankRules.test.luau
-- STATUS: written but NOT yet run (no Luau runtime in the cloud session). Run it on a PC first.

local RankRules = require("../src/shared/RankRules")
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

check("ten ranks", RankRules.maxRank(Config) == 10)
check("Chad is rank 7", Config.ranks[7].name == "Chad")
check("Mog God is the top rank", Config.ranks[10].name == "Mog God")
check("total to Chad is 4600", RankRules.totalToReach(Config, 7) == 4600)
check("total to Mog God is 32100", RankRules.totalToReach(Config, 10) == 32100)
check("next cost from Rookie", RankRules.nextCost(Config, 1) == 250)
check("no next cost at the top", RankRules.nextCost(Config, 10) == nil)
check("aura at Rookie is 1", RankRules.auraMultiplier(Config, 1) == 1)
check("aura at Mog God is about 1.9", math.abs(RankRules.auraMultiplier(Config, 10) - 1.9) < 1e-9)
check("aura clamps out of range ranks", RankRules.auraMultiplier(Config, 99) == RankRules.auraMultiplier(Config, 10))

do
	local result = RankRules.tryRankUp(Config, 1, 300)
	check("rank up spends points", result.ok and result.rank == 2 and result.points == 50 and result.rewardBox == "recruit")
end
do
	local result = RankRules.tryRankUp(Config, 1, 249)
	check("not enough points changes nothing", not result.ok and result.reason == "not_enough_points" and result.rank == 1 and result.points == 249)
end
do
	local result = RankRules.tryRankUp(Config, 10, 99999)
	check("top rank cannot rank up", not result.ok and result.reason == "max_rank" and result.points == 99999)
end
check("fractional points rejected", RankRules.tryRankUp(Config, 1, 300.5).reason == "bad_input")
check("nan points rejected", RankRules.tryRankUp(Config, 1, 0 / 0).reason == "bad_input")
check("negative points rejected", RankRules.tryRankUp(Config, 1, -5).reason == "bad_input")
check("rank 0 rejected", RankRules.tryRankUp(Config, 0, 500).reason == "bad_input")

-- costs only ever rise, so later ranks never feel cheaper than earlier ones
local rising = true
for index = 3, #Config.ranks do
	if Config.ranks[index].cost <= Config.ranks[index - 1].cost then
		rising = false
	end
end
check("rank costs strictly rise", rising)

if failures > 0 then
	error(failures .. " test(s) failed")
end
print("All tests passed")
