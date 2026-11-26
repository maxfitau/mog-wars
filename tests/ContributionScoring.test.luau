--!strict
-- Plain-Luau tests, no Roblox needed. Run from the repo root with the standalone Luau runtime:
--   luau tests/ContributionScoring.test.luau
-- STATUS: written but NOT yet run (no Luau runtime in the cloud session). Run it on a PC first.

local ContributionScoring = require("../src/shared/ContributionScoring")

local failures = 0

local function check(name: string, condition: boolean)
	if condition then
		print("PASS " .. name)
	else
		failures += 1
		print("FAIL " .. name)
	end
end

local options = { minContribution = 3, minAward = 5 }

local function sum(payouts: { [number]: number }): number
	local total = 0
	for _, amount in payouts do
		total += amount
	end
	return total
end

check("push scoring is power times seconds", ContributionScoring.fromPush(2, 5) == 10)
check("bad push input scores zero", ContributionScoring.fromPush(-1, 5) == 0 and ContributionScoring.fromPush(0 / 0, 5) == 0 and ContributionScoring.fromPush(math.huge, 5) == 0)

do
	local payouts = ContributionScoring.split(100, { [1] = 30, [2] = 10 }, options)
	check("split follows contribution", payouts[1] == 75 and payouts[2] == 25)
	check("split never exceeds the pool", sum(payouts) <= 100)
end

do
	local payouts = ContributionScoring.split(100, { [1] = 30, [2] = 1 }, options)
	check("idle player below the minimum earns nothing", payouts[2] == nil and payouts[1] == 100)
end

do
	local payouts = ContributionScoring.split(10, { [1] = 100, [2] = 3, [3] = 3 }, options)
	check("minimum awards never push the sum over the pool", sum(payouts) <= 10)
end

do
	local payouts = ContributionScoring.split(100, { [1] = 3, [2] = 3, [3] = 3 }, options)
	check("equal contributors split evenly within a point", sum(payouts) <= 100 and math.abs(payouts[1] - payouts[3]) <= 1)
end

check("empty contributions pay nothing", next(ContributionScoring.split(100, {}, options)) == nil)
check("bad pool pays nothing", next(ContributionScoring.split(0 / 0, { [1] = 10 }, options)) == nil)
check("infinite contribution is ignored", ContributionScoring.split(100, { [1] = math.huge, [2] = 10 }, options)[1] == nil)

if failures > 0 then
	error(failures .. " test(s) failed")
end
print("All tests passed")
