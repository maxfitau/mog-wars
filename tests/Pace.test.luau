--!strict
-- Plain-Luau tests, no Roblox needed: luau tests/Pace.test.luau
-- STATUS: written but NOT yet run (no Luau runtime in the cloud session). Run it on the Mac first.

local CaptureBar = require("../src/shared/CaptureBar")
local Config = require("../src/shared/EconomyConfig")
local Pace = require("../src/shared/Pace")
local WarRules = require("../src/shared/WarRules")
local Weapons = require("../src/shared/Weapons")

local failures = 0
local function check(name: string, condition: boolean)
	if condition then
		print("PASS " .. name)
	else
		failures += 1
		print("FAIL " .. name)
	end
end

check("walk 22 and jump 55 on War Island", Pace.speed.war.walk == 22 and Pace.speed.war.jump == 55)
check("Training Island stays normal", Pace.speed.normal.walk == 16 and Pace.speed.normal.jump == 50)
check("speed pad is +50 percent for 3 seconds", Pace.speed.pad.boost == 0.5 and Pace.speed.pad.seconds == 3)
check("AURA RUSH is +20 percent for 2 seconds", Pace.speed.rush.boost == 0.2 and Pace.speed.rush.seconds == 2)
check("dash cooldown is 4 seconds", Pace.speed.dash.cooldownSeconds == 4)
check("respawn is 2 seconds", Weapons.combat.respawnSeconds == 2)
check("war is 6 minutes and allowed by the war rules", Config.war.durationSeconds == 360 and WarRules.clampWarSeconds(Config.war.durationSeconds) == 360)
check("results screen is 5 seconds and so is the gap between wars", Pace.results.seconds == 5 and Config.war.intermissionSeconds == 5)
check("overtime is the last 60 seconds, aura x2", Pace.overtime.seconds == 60 and Pace.overtime.auraMultiplier == 2 and Pace.overtime.seconds < Config.war.durationSeconds)

-- capture speed per tier: how long does one player alone need?
local function secondsToCapture(seconds: number, power: number): number
	local state = CaptureBar.newState()
	local params = { secondsForOneAura = seconds, decayPerSecond = 0 }
	local t = 0
	while t < 60 do
		local result = CaptureBar.step(state, { [1] = power }, 0.1, params)
		state = result.state
		t += 0.1
		if result.captured then
			return t
		end
	end
	return 999
end
local gold = secondsToCapture(Pace.capture.secondsPerFlag.gold, 1)
local diamond = secondsToCapture(Pace.capture.secondsPerFlag.diamond, 1)
local ultra = secondsToCapture(Pace.capture.secondsPerFlag.ultra, 1)
check("Gold flag takes about 4 seconds", math.abs(gold - 4) < 0.3)
check("Diamond flag takes about 6 seconds", math.abs(diamond - 6) < 0.3)
check("Ultra flag takes about 8 seconds", math.abs(ultra - 8) < 0.3)
local function teamPower(count: number): number
	return math.min(Pace.capture.maxMultiplier, 1 + Pace.capture.extraPlayerBonus * (count - 1))
end
check("each extra player adds 25 percent", teamPower(2) == 1.25 and teamPower(3) == 1.5)
check("team speed is capped at double", teamPower(5) == 2 and teamPower(12) == 2)
check("two players capture a Gold flag faster", secondsToCapture(Pace.capture.secondsPerFlag.gold, teamPower(2)) < gold)

-- rewards and pickups
check("+1 aura tick and +25 flag aura", Pace.rewards.flagTickAura == 1 and Pace.rewards.flagCapturedAura == 25)
check("hit +2, mog +10, assist +5", Weapons.combat.hitAura == 2 and Weapons.combat.mogAura == 10 and Weapons.combat.mogAura * Weapons.combat.assistFraction == 5)
local weights = 0
for _, kind in Pace.pickups.kinds do
	weights += kind.weight
end
check("three pickups, all with weight", #Pace.pickups.kinds == 3 and weights > 0)
check("pickups come about every 30 seconds", Pace.pickups.everySeconds == 30)
check("Main Character Mode doubles aura for 15 seconds", Pace.pickups.mainCharacterAuraMultiplier == 2 and Pace.pickups.mainCharacterSeconds == 15)

-- the constant "+X" counter and the abilities
check("+1 aura a second in the war, +3 on a flag, +1 per territory held", Pace.presence.base == 1 and Pace.presence.onFlag == 3 and Pace.presence.perTerritory == 1)
check("Shove is NPC, Dash is Rookie, Mog Stare is Sigma", Pace.abilities.shove.rank == 1 and Pace.abilities.dash.rank == 2 and Pace.abilities.stare.rank == 3)
check("Mog Stare freezes for 1 second on an 8 second cooldown", Pace.abilities.stare.freezeSeconds == 1 and Pace.abilities.stare.cooldownSeconds == 8)
check("a hidden stash is a big burst", Pace.stash.aura == 100)
do
	-- Rookie takes about a minute of normal play: one second on a flag earns about +4 (3 for the flag, 1 per territory held)
	local Config = require("../src/shared/EconomyConfig")
	local perSecond = Pace.presence.onFlag + Pace.presence.perTerritory
	local seconds = Config.ranks[2].cost / perSecond
	check("Rookie takes about a minute of play", seconds > 25 and seconds < 90)
end

if failures > 0 then
	error(failures .. " test(s) failed")
end
print("All tests passed")
