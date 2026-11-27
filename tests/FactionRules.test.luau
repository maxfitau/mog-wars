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

-- friend preference: a friend's faction is chosen unless it is too much bigger
check("a friend's faction is chosen when it is not too big", FactionRules.pickFaction({ [1] = 1, [2] = 2, [3] = 1, [4] = 1 }, 2, 1) == 2)
check("a friend's faction is skipped when it is too big", FactionRules.pickFaction({ [1] = 0, [2] = 2, [3] = 0, [4] = 0 }, 2, 1) == 1)
check("with no tolerance only the smallest tie is chosen", FactionRules.pickFaction({ [1] = 1, [2] = 2, [3] = 1, [4] = 1 }, 2, 0) == 1)
check("an unknown preferred faction is ignored", FactionRules.pickFaction({}, 9, 1) == 1)
-- with friend preference (tolerance 1) the factions never end up more than 2 apart, for any join order
do
	local worst = 0
	for seed = 1, 300 do
		local counts: { [number]: number } = {}
		local state = seed
		for _ = 1, 16 do
			state = (state * 1103515245 + 12345) % 2147483648
			local preferred = state % 5 -- 0 means no friend online
			local id = FactionRules.pickFaction(counts, if preferred == 0 then nil else preferred, 1)
			counts[id] = (counts[id] or 0) + 1
			local low, high = math.huge, 0
			for faction = 1, 4 do
				low = math.min(low, counts[faction] or 0)
				high = math.max(high, counts[faction] or 0)
			end
			worst = math.max(worst, high - low)
		end
	end
	check("friend preference keeps factions within 2 players", worst <= 2)
end
check("detects imbalance", not FactionRules.isBalanced({ [1] = 4, [2] = 1, [3] = 1, [4] = 1 }))

if failures > 0 then
	error(failures .. " test(s) failed")
end
print("All tests passed")
