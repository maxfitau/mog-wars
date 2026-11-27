--!strict
-- Plain-Luau tests, no Roblox needed. Run from the repo root with the standalone Luau runtime:
--   luau tests/BoxRoll.test.luau
-- STATUS: written but NOT yet run (no Luau runtime in the cloud session). Run it on a PC first.

local BoxRoll = require("../src/shared/BoxRoll")
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

for id, tier in Config.boxes.tiers do
	local ok, reason = BoxRoll.validate(tier)
	check(id .. " tier is valid (" .. tostring(reason) .. ")", ok)
end

local gold = Config.boxes.tiers.gold
check("roll 0 gives the first drop", BoxRoll.roll(gold, function() return 0 end) == gold.drops[1])
check("roll just under 1 gives the last drop", BoxRoll.roll(gold, function() return 0.999999 end) == gold.drops[#gold.drops])
check("a bad random value is safe", BoxRoll.roll(gold, function() return 0 / 0 end) == gold.drops[1])
check("a random value of 1 is safe", BoxRoll.roll(gold, function() return 1 end) == gold.drops[#gold.drops])

-- boundary: the first drop's own weight is where it ends
local firstWeight = gold.drops[1].weight
check(
	(firstWeight - 0.01) .. " is still the first drop",
	BoxRoll.roll(gold, function() return (firstWeight - 0.01) / 100 end) == gold.drops[1]
)
check(
	(firstWeight + 0.01) .. " is the second drop",
	BoxRoll.roll(gold, function() return (firstWeight + 0.01) / 100 end) == gold.drops[2]
)

-- odds shown equal the weights
local shown = BoxRoll.odds(gold)
local total = 0
for index, entry in shown do
	check("shown odds match weight " .. index, entry.percent == gold.drops[index].weight)
	total += entry.percent
end
check("shown odds add up to 100", total == 100)

-- every box tier named anywhere in the config must exist
for _, rule in Config.boxes.tierForValue do
	check("capture rule tier exists: " .. rule.tier, Config.boxes.tiers[rule.tier] ~= nil)
end
for _, tier in Config.dailyStreak.rewards do
	check("daily box tier exists: " .. tier, Config.boxes.tiers[tier] ~= nil)
end

-- which tier a capture gives
check("a zone worth 1 gives gold", BoxRoll.tierForValue(1, Config.boxes.tierForValue) == "gold")
check("a zone worth 2 gives diamond", BoxRoll.tierForValue(2, Config.boxes.tierForValue) == "diamond")
check("a zone worth 3 gives ultra", BoxRoll.tierForValue(3, Config.boxes.tierForValue) == "ultra")
check("a zone worth 10 still gives ultra", BoxRoll.tierForValue(10, Config.boxes.tierForValue) == "ultra")
check("a worthless zone gives no box", BoxRoll.tierForValue(0, Config.boxes.tierForValue) == nil)
check("nan gives no box", BoxRoll.tierForValue(0 / 0, Config.boxes.tierForValue) == nil)

-- a bad tier is rejected
local bad = { displayName = "Bad", drops = { { weight = 50, kind = "points", amount = 10 } } }
local okBad, reasonBad = BoxRoll.validate(bad)
check("weights not summing to 100 are rejected", not okBad and reasonBad == "weights_not_100")
check("empty tier is rejected", select(2, BoxRoll.validate({ displayName = "x", drops = {} })) == "no_drops")

-- simulated frequencies stay close to the weights (deterministic sweep, not random)
local counts: { [BoxRoll.Drop]: number } = {}
local steps = 10000
for step = 0, steps - 1 do
	local drop = BoxRoll.roll(gold, function() return step / steps end)
	counts[drop] = (counts[drop] or 0) + 1
end
local close = true
for _, drop in gold.drops do
	if math.abs((counts[drop] or 0) / steps * 100 - drop.weight) > 0.1 then
		close = false
	end
end
check("sweep matches weights", close)

check("a weapon drop without a weapon id is rejected", not (BoxRoll.validate({ displayName = "x", drops = { { weight = 100, kind = "weapon" } } })))
check("a weapon drop with an id is accepted", (BoxRoll.validate({ displayName = "x", drops = { { weight = 100, kind = "weapon", weapon = "sideeye" } } })))

if failures > 0 then
	error(failures .. " test(s) failed")
end
print("All tests passed")
