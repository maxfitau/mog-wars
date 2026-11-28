--!strict
-- luau tests/Pacing.test.luau  (STATUS: not run in the cloud session, no Luau runtime; tools/pacing_sim.py is the same model)
-- A pacing simulation for an ACTIVE player and an IDLE player. Prints the time to each rank and fails if the targets are missed.
local Pace = require("../src/shared/Pace")
local Levels = require("../src/shared/Levels")

local failures = 0
local function check(name: string, condition: boolean)
	if not condition then
		failures += 1
		print("FAIL " .. name)
	end
end

local income = Pace.income
-- the model: actions per second at level 0, then the seconds-of-income rewards, then add the passive share
local fixedPerMinute = (income.flagHoldSecondsPerMinute * Pace.presence.onFlag + income.flagFlipsPerMinute * Pace.rewards.flagCapturedAura + income.territoryCapturesPerMinute * income.averageTierAura + income.stashesPerMinute * Pace.stash.aura + income.questsPerMinute * income.averageQuestAura + income.stealAuraPerMinute + income.chestPerMinute * income.averageChestAura) * income.comboCritFactor
local actions = fixedPerMinute / 60 / (1 - income.eventSecondsPerMinute / 60)
local active = actions / (1 - income.passiveFraction)
print(("active %.2f aura/s (actions %.2f + passive %.2f); nominalIncome is %.2f; presence.base is %.2f"):format(active, actions, active - actions, Pace.levels.nominalIncome, Pace.presence.base))
check("nominalIncome matches the model", math.abs(active - Pace.levels.nominalIncome) / active < 0.05)
check("passive is about 15 percent", math.abs(Pace.presence.base / active - income.passiveFraction) < 0.03)

-- every level takes longer than the one before it
local previous = 0
for level = 0, 79 do
	local seconds = Levels.secondsFor(level)
	check("level " .. level .. " takes longer than the last", seconds > previous)
	previous = seconds
end

-- active player: time to each rank (the cumulative seconds of the levels before it)
local function reach(level: number): number
	local total = 0
	for index = 0, level - 1 do
		total += Levels.secondsFor(index)
	end
	return total
end
local targets = { { "Rookie", 1, 30, 90 }, { "Sigma", 11, 480, 720 }, { "Chadlite", 21, 1500, 2100 }, { "Chad", 31, 3000, 4200 }, { "Gigachad", 41, 9000, 13000 }, { "Mog God", 51, 3 * 86400, 5 * 86400 } }
for _, target in targets do
	local seconds = reach(target[2] :: number)
	print(("active: %-9s in %8.1f minutes (%.2f hours, %.2f days)"):format(target[1] :: string, seconds / 60, seconds / 3600, seconds / 86400))
	check(target[1] .. " time in range", seconds >= (target[3] :: number) and seconds <= (target[4] :: number))
end

-- idle player: only the passive tick, and it stops at the end of Rookie
local aura, level, time = 0, 0, 0
while time < 14 * 86400 and level < Pace.levels.passiveMaxLevel do
	aura += Pace.presence.base * Levels.multiplier(level)
	time += 1
	level = Levels.levelForAura(aura)
end
print(("idle: stops at level %d (Rookie X) after %.1f hours and never earns more"):format(level, time / 3600))
check("idle never reaches Sigma", Levels.rankOfLevel(level) <= 2)

if failures > 0 then
	error(failures .. " test(s) failed")
end
print("All tests passed")
