--!strict
-- Plain-Luau tests, no Roblox needed. Run from the repo root with the standalone Luau runtime:
--   luau tests/FactionRules.test.luau
-- STATUS: written but NOT yet run (no Luau runtime in the cloud session). Run it on a PC first.

local FactionRules = require("../src/shared/FactionRules")

local failures = 0

local function check(name: string, condition: boolean)
	if condition then
		print("PASS " .. name)
	else
		failures += 1
		print("FAIL " .. name)
	end
end

check("four factions", FactionRules.count() == 4)
check("ids match positions", FactionRules.byId(3) ~= nil and (FactionRules.byId(3) :: any).id == 3)
check("unknown id is nil", FactionRules.byId(0) == nil and FactionRules.byId(5) == nil)
check("empty server picks faction 1", FactionRules.pickFaction({}) == 1)
check("picks the smallest faction", FactionRules.pickFaction({ [1] = 3, [2] = 2, [3] = 1, [4] = 2 }) == 3)
check("ties go to the lowest id", FactionRules.pickFaction({ [1] = 2, [2] = 1, [3] = 1, [4] = 1 }) == 2)

-- adding players one at a time stays balanced for 1 to 16 players
for total = 1, 16 do
	local counts: { [number]: number } = {}
	for _ = 1, total do
		local id = FactionRules.pickFaction(counts)
		counts[id] = (counts[id] or 0) + 1
	end
	check("balanced with " .. total .. " players", FactionRules.isBalanced(counts))
end

check("detects imbalance", not FactionRules.isBalanced({ [1] = 4, [2] = 1, [3] = 1, [4] = 1 }))

if failures > 0 then
	error(failures .. " test(s) failed")
end
print("All tests passed")
