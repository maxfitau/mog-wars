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

check("seven ranks", RankRules.maxRank(Config) == 7)
check("the ranks are in the design order", Config.ranks[1].name == "NPC" and Config.ranks[2].name == "Rookie" and Config.ranks[3].name == "Sigma" and Config.ranks[4].name == "Chadlite" and Config.ranks[5].name == "Chad" and Config.ranks[6].name == "Gigachad" and Config.ranks[7].name == "Mog God")
check("NPC is free", Config.ranks[1].cost == 0)
check("total to Chad", RankRules.totalToReach(Config, 5) == 320 + 720 + 1350 + 2350)
check("total to Mog God", RankRules.totalToReach(Config, 7) == 320 + 720 + 1350 + 2350 + 8800 + 21000)
check("next cost from NPC", RankRules.nextCost(Config, 1) == 320)
check("no next cost at the top", RankRules.nextCost(Config, 7) == nil)

do
	local result = RankRules.tryRankUp(Config, 1, 370)
	check("rank up spends points", result.ok and result.rank == 2 and result.points == 50)
end
do
	local result = RankRules.tryRankUp(Config, 1, 319)
	check("not enough points changes nothing", not result.ok and result.reason == "not_enough_points" and result.rank == 1 and result.points == 319)
end
do
	local result = RankRules.tryRankUp(Config, 7, 99999)
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
