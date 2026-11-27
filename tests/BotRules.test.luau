--!strict
-- Plain-Luau tests, no Roblox needed. Run from the repo root with the standalone Luau runtime:
--   luau tests/BotRules.test.luau
-- STATUS: written but NOT yet run (no Luau runtime in the cloud session). Run it on a PC first.

local BotRules = require("../src/shared/BotRules")
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

local settings = Config.bots

-- how many bots
check("an empty war needs 8 bots", BotRules.desiredBots(0, 8) == 8)
check("3 players need 5 bots", BotRules.desiredBots(3, 8) == 5)
check("8 players need none", BotRules.desiredBots(8, 8) == 0)
check("16 players need none", BotRules.desiredBots(16, 8) == 0)
check("bad numbers need none", BotRules.desiredBots(0 / 0, 8) == 0 and BotRules.desiredBots(2, 0 / 0) == 0)
check("the config fills to 8", settings.minFighters == 8)

-- balanced across factions: adding bots one at a time to an empty war ends with 2 per faction
do
	local totals: { [number]: number } = {}
	for _ = 1, 8 do
		local id = BotRules.factionForAdd(totals, 4)
		totals[id] = (totals[id] or 0) + 1
	end
	check("8 bots across 4 factions is 2 each", totals[1] == 2 and totals[2] == 2 and totals[3] == 2 and totals[4] == 2)
end
check("the next bot goes to the smallest faction", BotRules.factionForAdd({ [1] = 3, [2] = 1, [3] = 2, [4] = 2 }, 4) == 2)
-- real players first, then bots fill the gaps evenly
do
	local totals: { [number]: number } = { [1] = 2, [2] = 1, [3] = 0, [4] = 0 } -- 3 real players
	for _ = 1, 5 do
		local id = BotRules.factionForAdd(totals, 4)
		totals[id] = (totals[id] or 0) + 1
	end
	local low, high = math.huge, 0
	for id = 1, 4 do
		low = math.min(low, totals[id] or 0)
		high = math.max(high, totals[id] or 0)
	end
	check("bots fill around 3 real players and the factions end within 1 of each other", high - low <= 1 and (totals[1] + totals[2] + totals[3] + totals[4]) == 8)
end

-- removing bots one at a time
check("removal comes from the biggest faction that has a bot", BotRules.factionForRemoval({ [1] = 1, [2] = 1, [3] = 0, [4] = 1 }, { [1] = 3, [2] = 2, [3] = 2, [4] = 2 }, 4) == 1)
check("a faction with no bots is never chosen for removal", BotRules.factionForRemoval({ [1] = 0, [2] = 1 }, { [1] = 9, [2] = 1 }, 4) == 2)
check("no bots means nothing to remove", BotRules.factionForRemoval({}, { [1] = 2 }, 4) == nil)

-- tap speeds are human-like, inside the limits and below the server cap
local function fixed(value: number): () -> number
	return function()
		return value
	end
end
check("the tap cap is above every bot rate", settings.tapRateMax < 10)
do
	local newKid = BotRules.duelRate(1, 0, fixed(0.5), settings)
	local veteran = BotRules.duelRate(1, 3, fixed(0.5), settings)
	check("bots tap slower against a brand-new player", newKid < veteran)
	check("the middle rate against NPC rank after a war is the base rate", math.abs(veteran - settings.tapRateBase) < 1e-9)
	check("bots tap faster against higher ranks", BotRules.duelRate(5, 3, fixed(0.5), settings) > veteran)
	check("a Mog God bot is still below the human cap", BotRules.duelRate(7, 3, fixed(0.99), settings) <= settings.tapRateMax)
end
do
	local lowest = BotRules.duelRate(1, 0, fixed(0), settings)
	local highest = BotRules.duelRate(7, 3, fixed(0.999999), settings)
	check("rates never go below the minimum", lowest >= settings.tapRateMin)
	check("rates never go above the maximum", highest <= settings.tapRateMax)
end
check("bad input falls back to rank 1", math.abs(BotRules.duelRate(0 / 0, 0 / 0, fixed(0.5), settings) - settings.tapRateBase * settings.tapRateNewPlayerFactor) < 1e-9)

-- a bot's taps over a 5 second duel never pass the server cap
do
	local owed, total = 0, 0
	for step = 1, 50 do
		local jitter = 0.7 + (step % 7) * 0.1
		local taps
		taps, owed = BotRules.tapsThisStep(settings.tapRateMax, 0.1, owed, jitter)
		total += taps
	end
	check("a fast bot makes a sensible number of taps in 5 seconds", total >= 30 and total <= 60)
end
do
	local taps, owed = BotRules.tapsThisStep(0, 0.1, 0.4, 1)
	check("zero rate makes no taps", taps == 0 and owed == 0.4)
	taps = BotRules.tapsThisStep(0 / 0, 0.1, 0, 1)
	check("a bad rate makes no taps", taps == 0)
end

-- aura
check("bot aura starts at 1", BotRules.aura(1, settings) == 1)
check("bot aura stays small", BotRules.aura(7, settings) <= 1.25)

-- choosing a zone
do
	local zones = {
		{ x = 0, z = 0, owner = 0, value = 2 },
		{ x = 60, z = 0, owner = 1, value = 1 },
		{ x = -60, z = 0, owner = 0, value = 1 },
	}
	local zero = fixed(0)
	check("a bot prefers a zone it does not own", BotRules.chooseZone(1, 55, 0, zones, {}, zero) ~= 2)
	check("a bot near a free zone goes there", BotRules.chooseZone(2, -50, 0, zones, {}, zero) == 3)
	check("bots spread out: a crowded zone is skipped", BotRules.chooseZone(2, -50, 0, zones, { [3] = 3 }, zero) ~= 3)
	check("no zones gives nil", BotRules.chooseZone(1, 0, 0, {}, {}, zero) == nil)
	check("a bad position gives nil", BotRules.chooseZone(1, 0 / 0, 0, zones, {}, zero) == nil)
end

-- rewards
check("taking a zone from a bots-only faction pays less", BotRules.capturePoolFactor(2, 0, settings) == settings.rewardFactor)
check("taking a zone from a faction with real players pays in full", BotRules.capturePoolFactor(2, 3, settings) == 1)
check("taking a free zone pays in full", BotRules.capturePoolFactor(0, 0, settings) == 1)
check("beating a bot pays less than beating a player", settings.rewardFactor < 1)

if failures > 0 then
	error(failures .. " test(s) failed")
end
print("All tests passed")
