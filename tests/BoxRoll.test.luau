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

local recruit = Config.boxes.tiers.recruit
check("roll 0 gives the first drop", BoxRoll.roll(recruit, function() return 0 end) == recruit.drops[1])
check("roll just under 1 gives the last drop", BoxRoll.roll(recruit, function() return 0.999999 end) == recruit.drops[#recruit.drops])
check("a bad random value is safe", BoxRoll.roll(recruit, function() return 0 / 0 end) == recruit.drops[1])
check("a random value of 1 is safe", BoxRoll.roll(recruit, function() return 1 end) == recruit.drops[#recruit.drops])

-- boundary: 40 percent is where the first drop ends
check("0.399 is still the first drop", BoxRoll.roll(recruit, function() return 0.399 end) == recruit.drops[1])
check("0.401 is the second drop", BoxRoll.roll(recruit, function() return 0.401 end) == recruit.drops[2])

-- odds shown equal the weights
local shown = BoxRoll.odds(recruit)
local total = 0
for index, entry in shown do
	check("shown odds match weight " .. index, entry.percent == recruit.drops[index].weight)
	total += entry.percent
end
check("shown odds add up to 100", total == 100)

-- every box tier named anywhere in the config must exist
check("winner box tier exists", Config.boxes.tiers[Config.war.winnerBoxTier] ~= nil)
check("participant box tier exists", Config.boxes.tiers[Config.war.participantBoxTier] ~= nil)
for _, rank in Config.ranks do
	check("rank box tier exists for " .. rank.name, rank.rewardBox == "" or Config.boxes.tiers[rank.rewardBox] ~= nil)
end

-- a bad tier is rejected
local bad = { displayName = "Bad", drops = { { weight = 50, kind = "points", amount = 10 } } }
local okBad, reasonBad = BoxRoll.validate(bad)
check("weights not summing to 100 are rejected", not okBad and reasonBad == "weights_not_100")
check("empty tier is rejected", select(2, BoxRoll.validate({ displayName = "x", drops = {} })) == "no_drops")

-- simulated frequencies stay close to the weights (deterministic sweep, not random)
local counts: { [BoxRoll.Drop]: number } = {}
local steps = 10000
for step = 0, steps - 1 do
	local drop = BoxRoll.roll(recruit, function() return step / steps end)
	counts[drop] = (counts[drop] or 0) + 1
end
local close = true
for _, drop in recruit.drops do
	if math.abs((counts[drop] or 0) / steps * 100 - drop.weight) > 0.1 then
		close = false
	end
end
check("sweep matches weights", close)

if failures > 0 then
	error(failures .. " test(s) failed")
end
print("All tests passed")
