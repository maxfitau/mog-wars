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
check("total to Chad", RankRules.totalToReach(Config, 5) == 400 + 900 + 1900 + 3800)
check("total to Mog God", RankRules.totalToReach(Config, 7) == 400 + 900 + 1900 + 3800 + 12000 + 31000)
check("next cost from NPC", RankRules.nextCost(Config, 1) == 400)
check("no next cost at the top", RankRules.nextCost(Config, 7) == nil)

do
	local result = RankRules.tryRankUp(Config, 1, 450)
	check("rank up spends points", result.ok and result.rank == 2 and result.points == 50)
end
do
	local result = RankRules.tryRankUp(Config, 1, 399)
	check("not enough points changes nothing", not result.ok and result.reason == "not_enough_points" and result.rank == 1 and result.points == 399)
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

-- ranks are earned by total aura
check("0 aura is NPC", RankRules.rankForAura(Config, 0) == 1)
check("399 aura is still NPC", RankRules.rankForAura(Config, 399) == 1)
check("400 aura is Rookie", RankRules.rankForAura(Config, 400) == 2)
check("1300 aura is Sigma", RankRules.rankForAura(Config, 1300) == 3)
check("7000 aura is Chad", RankRules.rankForAura(Config, 7000) == 5)
check("19000 aura is Gigachad", RankRules.rankForAura(Config, 19000) == 6)
check("50000 aura is Mog God", RankRules.rankForAura(Config, 50000) == 7)
check("far past the top stays Mog God", RankRules.rankForAura(Config, 9e9) == 7)
check("bad aura is NPC", RankRules.rankForAura(Config, -5) == 1 and RankRules.rankForAura(Config, 0 / 0) == 1)
do
	local rank, floor, ceiling = RankRules.progress(Config, 500)
	check("progress: Rookie, from 400 to 1300", rank == 2 and floor == 400 and ceiling == 1300)
	local top, topFloor, topCeiling = RankRules.progress(Config, 60000)
	check("progress at the top has no next rank", top == 7 and topFloor == 50000 and topCeiling == nil)
end
local never = true
local last = 1
for aura = 0, 60000, 100 do
	local rank = RankRules.rankForAura(Config, aura)
	if rank < last then
		never = false
	end
	last = rank
end
check("rank never goes down as aura goes up", never)

if failures > 0 then
	error(failures .. " test(s) failed")
end
print("All tests passed")
