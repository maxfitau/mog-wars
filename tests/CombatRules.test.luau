--!strict
-- Plain-Luau tests, no Roblox needed: luau tests/CombatRules.test.luau
-- STATUS: written but NOT yet run (no Luau runtime in the cloud session). Run it on the Mac first.

local CombatRules = require("../src/shared/CombatRules")
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

local combat = Weapons.combat
local blaster = Weapons.list.aurablaster

-- damage and the 10 percent cap
check("rank 1 does base damage", CombatRules.damage(25, 1, combat) == 25)
check("high rank bonus is capped at +10 percent", CombatRules.damage(100, 7, combat) == 109 or CombatRules.damage(100, 7, combat) <= 110)
check("absurd rank never passes +10 percent", CombatRules.damage(100, 9999, combat) == 110)
check("nan rank gives base damage", CombatRules.damage(25, 0 / 0, combat) == 25)
check(
	"three hits mog a 100 ego player",
	select(2, CombatRules.applyDamage(66, 34)) == false -- the second hit (100 -> 66 -> 32) does not mog yet
		and select(2, CombatRules.applyDamage(32, 34)) == true -- the third hit does
		and 3 * blaster.damage >= combat.health
		and 2 * blaster.damage < combat.health
)
check("health never below 0", (CombatRules.applyDamage(10, 50)) == 0)
check("bad damage is ignored", (CombatRules.applyDamage(100, -5)) == 100 and (CombatRules.applyDamage(100, 0 / 0)) == 100)

-- direction check
check("unit direction is valid", CombatRules.directionValid(0, 0, 1))
check("zero direction is invalid", not CombatRules.directionValid(0, 0, 0))
check("huge direction is invalid", not CombatRules.directionValid(0, 0, 50))
check("nan direction is invalid", not CombatRules.directionValid(0 / 0, 0, 1))

-- canFire reasons
local ready = { alive = true, shieldUntil = 0, reloadingUntil = 0, ammo = 5, lastFire = -100 }
local function reason(changes: { [string]: any }): string
	local state: any = table.clone(ready)
	for key, value in changes do
		state[key] = value
	end
	local ok, why = CombatRules.canFire(state, 10, blaster)
	return if ok then "ok" else tostring(why)
end
check("ready can fire", reason({}) == "ok")
check("dead cannot fire", reason({ alive = false }) == "dead")
check("shielded cannot fire", reason({ shieldUntil = 11 }) == "shielded")
check("reloading cannot fire", reason({ reloadingUntil = 11 }) == "reloading")
check("empty cannot fire", reason({ ammo = 0 }) == "empty")
check("too soon cannot fire", reason({ lastFire = 9.8 }) == "too_soon")

-- pellets
check("one pellet goes where you aim", #CombatRules.pelletDirections(0, 0, 1, 1, 7) == 1)
local pellets = CombatRules.pelletDirections(0, 0, 1, 3, 7)
check("three pellets", #pellets == 3)
local allClose = true
for _, p in pellets do
	local length = math.sqrt(p[1] ^ 2 + p[2] ^ 2 + p[3] ^ 2)
	local angle = math.deg(math.acos(math.clamp(p[3], -1, 1)))
	if math.abs(length - 1) > 1e-6 or math.abs(angle - 7) > 1e-3 then
		allClose = false
	end
end
check("pellets are unit length and 7 degrees off", allClose)

-- assists, rewards, streaks
local log = { [1] = { time = 9, amount = 50 }, [2] = { time = 9, amount = 5 }, [3] = { time = -50, amount = 60 }, [4] = { time = 9, amount = 30 } }
local helpers = CombatRules.assisters(log, 4, 10, combat)
check("assist needs recent damage and enough of it, and excludes the killer", #helpers == 1 and helpers[1] == 1)
local aura, points = CombatRules.reward(false, false, combat)
check("a mog pays 10 aura and some points", aura == 10 and points == combat.mogPoints)
local botAura = CombatRules.reward(false, true, combat)
check("a bot mog pays half", botAura == 5)
local assistAura = CombatRules.reward(true, false, combat)
check("an assist pays half", assistAura == 5)
check("streak 2 is DOUBLE MOG", CombatRules.streakMessage(2, combat) == "DOUBLE MOG")
check("streak 3 is TRIPLE MOG", CombatRules.streakMessage(3, combat) == "TRIPLE MOG")
check("streak 5 is MOG GOD STREAK", CombatRules.streakMessage(5, combat) == "MOG GOD STREAK")
check("streak 4 has no announcement", CombatRules.streakMessage(4, combat) == nil)

-- unlocks
local flex = Weapons.list.flexblast
local sniper = Weapons.list.sideeye
check("starter is always unlocked", CombatRules.unlocked(blaster, "blaster", 1, {}))
check("Flex Blast needs Rookie", not CombatRules.unlocked(flex, "flexblast", 1, {}) and CombatRules.unlocked(flex, "flexblast", 2, {}))
check("Side-Eye Sniper needs Sigma", not CombatRules.unlocked(sniper, "sideeye", 2, {}) and CombatRules.unlocked(sniper, "sideeye", 3, {}))
check("a box drop unlocks early", CombatRules.unlocked(sniper, "sideeye", 1, { sideeye = true }))

-- aim assist
local ax, ay, az = CombatRules.aimAssist(0, 0, 1, { { 0.05, 0, 1 } }, 6)
check("aim assist pulls toward a close enemy", ax > 0 and ax < 0.06 and az > 0.99)
local bx, _, bz = CombatRules.aimAssist(0, 0, 1, { { 1, 0, 1 } }, 6)
check("aim assist ignores a far-off enemy", bx == 0 and bz == 1)

-- balance: each weapon is best in its own band (time to mog in seconds, perfect aim, one target)
local function ttk(w: Weapons.Weapon, hits: number): number
	local shots = math.ceil(combat.health / (w.damage * hits))
	return (shots - 1) * w.fireInterval
end
check("Flex Blast mogs fastest up close (all three blasts hit)", ttk(flex, 3) < ttk(blaster, 1) and ttk(flex, 3) < ttk(sniper, 1))
check("Aura Blaster reaches further than Flex Blast and Side-Eye Sniper further still", flex.range < blaster.range and blaster.range < sniper.range)
check("every weapon has a reason to use it: damage per second differs", ttk(sniper, 1) ~= ttk(blaster, 1))

-- combo and hit aura
local count, mult = CombatRules.comboNext(0, -100, 10, combat)
check("the first hit is x1", count == 1 and mult == 1)
count, mult = CombatRules.comboNext(count, 10, 11.5, combat)
check("a hit within 3 seconds is x2", count == 2 and mult == 2)
count, mult = CombatRules.comboNext(count, 11.5, 20, combat)
check("a slow hit restarts the combo", count == 1 and mult == 1)
count, mult = CombatRules.comboNext(9, 20, 21, combat)
check("the combo multiplier is capped", count == 10 and mult == combat.comboMax)
check("a hit pays +2 aura", CombatRules.hitAura(false, 1, combat) == 2)
check("a hit on a bot pays half but never zero", CombatRules.hitAura(true, 1, combat) == 1)
check("the combo multiplies hit aura", CombatRules.hitAura(false, 3, combat) == 6)
check("weapon names: weapons are Aura Blaster, Flex Blast and Side-Eye Sniper", Weapons.list.aurablaster.name == "Aura Blaster" and Weapons.list.flexblast.name == "Flex Blast" and Weapons.list.sideeye.name == "Side-Eye Sniper")

if failures > 0 then
	error(failures .. " test(s) failed")
end
print("All tests passed")
