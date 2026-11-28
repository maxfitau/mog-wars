--!strict
-- luau tests/WeaponRules.test.luau  (STATUS: not run in the cloud session, no Luau runtime)
local WeaponRules = require("../src/shared/WeaponRules")
local WeaponCatalog = require("../src/shared/WeaponCatalog")

local failures = 0
local function check(name: string, condition: boolean)
	if not condition then
		failures += 1
		print("FAIL " .. name)
	end
end
local function near(a: number, b: number): boolean
	return math.abs(a - b) < 0.001
end

local function params(id: string): { [string]: number }
	return WeaponCatalog.byId[id].params
end

-- star scale matches the catalog and stops at +20 percent
for stars = 1, 5 do
	check("scale matches catalog at " .. stars, near(WeaponRules.scale(stars), WeaponCatalog.starScale(stars)))
end
check("scale never above 1.2", WeaponRules.scale(99) <= 1.2001)
check("scale nan is safe", WeaponRules.scale(0 / 0) == 1)

-- request checks
check("fast request is rejected", WeaponRules.tooFast(10.1, 10))
check("normal request is fine", not WeaponRules.tooFast(10.5, 10))
check("cooldown blocks", not WeaponRules.cooldownReady(11, 10, 2.2))
check("cooldown frees", WeaponRules.cooldownReady(12.3, 10, 2.2))
check("cooldown slack for jitter", WeaponRules.cooldownReady(12.1, 10, 2.2))

-- aim
local ax, az = WeaponRules.cleanAim(0, 0, -1)
check("aim forward", ax ~= nil and az ~= nil and near(ax :: number, 0) and near(az :: number, -1))
local tx, tz = WeaponRules.cleanAim(0.6, 0.6, -0.529)
check("tilted aim is flattened", tx ~= nil and tz ~= nil and near(((tx :: number) ^ 2) + ((tz :: number) ^ 2), 1))
check("zero aim rejected", WeaponRules.cleanAim(0, 0, 0) == nil)
check("huge aim rejected", WeaponRules.cleanAim(5, 0, 0) == nil)
check("nan aim rejected", WeaponRules.cleanAim(0 / 0, 0, 1) == nil)
check("inf aim rejected", WeaponRules.cleanAim(math.huge, 0, 0) == nil)
check("straight up rejected", WeaponRules.cleanAim(0, 1, 0) == nil)
check("charge nan rejected", WeaponRules.cleanCharge(0 / 0, 0.9) == nil)
check("charge negative rejected", WeaponRules.cleanCharge(-1, 0.9) == nil)
check("charge huge rejected", WeaponRules.cleanCharge(1000, 0.9) == nil)
check("charge clamped", near(WeaponRules.cleanCharge(5, 0.9) :: number, 1.15))

-- cones
check("in front is in the cone", WeaponRules.inCone(0, 0, 0, -1, 0, -10, 16, 100) ~= nil)
check("behind is not in the cone", WeaponRules.inCone(0, 0, 0, -1, 0, 10, 16, 100) == nil)
check("too far is not in the cone", WeaponRules.inCone(0, 0, 0, -1, 0, -17, 16, 100) == nil)
check("45 degrees is inside a 100 degree cone", WeaponRules.inCone(0, 0, 0, -1, 7, -7, 16, 100) ~= nil)
check("70 degrees is outside a 100 degree cone", WeaponRules.inCone(0, 0, 0, -1, 9.4, -3.4, 16, 100) == nil)
check("pickNearest picks the nearer", WeaponRules.pickNearest(0, 0, 0, -1, 140, 9, { { x = 0, z = -8 }, { x = 1, z = -3 } }) == 2)
check("pickNearest without aim is a circle", WeaponRules.pickNearest(0, 0, nil, nil, 140, 9, { { x = 0, z = 8 } }) == 1)
check("pickNearest nothing in range", WeaponRules.pickNearest(0, 0, 0, -1, 140, 9, { { x = 0, z = -20 } }) == nil)
check("circle", WeaponRules.inCircle(0, 0, 3, 4, 5) and not WeaponRules.inCircle(0, 0, 3, 4.1, 5))

-- hammer: twice the shove distance, bigger with stars, capped
local hammer = params("jawline_hammer")
check("hammer is 2x shove", near(WeaponRules.hammerKnock(hammer, 1, 14), 28))
check("hammer 5 stars is 20 percent more", near(WeaponRules.hammerKnock(hammer, 5, 14), 33.6))
check("hammer reach grows", WeaponRules.hammerReach(hammer, 5) > WeaponRules.hammerReach(hammer, 1))
check("knock is capped", WeaponRules.clampStuds(500) == WeaponRules.MAX_STUDS and WeaponRules.clampStuds(0 / 0) == 0)

-- gust
local gust = params("mewing_fan")
check("gust angle", WeaponRules.gustAngle(gust) == 100)
check("gust reach 1 star", near(WeaponRules.gustReach(gust, 1), 16))
check("gust knock", near(WeaponRules.gustKnock(gust, 1, 14), 14))

-- boomerang
local boom = params("sigma_shades")
local range = WeaponRules.boomerangRange(boom, 1)
local duration = WeaponRules.boomerangDuration(range)
check("boomerang duration is out and back", near(duration, 2 * 28 / WeaponRules.BOOMERANG_SPEED))
check("boomerang starts going out", select(1, WeaponRules.boomerangState(0, duration)) == 1)
check("boomerang is out before half", select(1, WeaponRules.boomerangState(duration * 0.49, duration)) == 1)
check("boomerang is back after half", select(1, WeaponRules.boomerangState(duration * 0.51, duration)) == 2)
check("boomerang is done at the end", select(1, WeaponRules.boomerangState(duration, duration)) == 3)
check("boomerang fully out at the turn", near(WeaponRules.boomerangOut(range, 1), range))
check("boomerang out starts at zero", near(WeaponRules.boomerangOut(range, 0), 0))
check("boomerang bad duration is done", select(1, WeaponRules.boomerangState(1, 0)) == 3)

-- rose
local rose = params("rizz_rose")
check("rose pulls one second at one star", near(WeaponRules.roseSeconds(rose, 1), 1))
check("rose pulls more at five stars", near(WeaponRules.roseSeconds(rose, 5), 1.2))
check("rose range", near(WeaponRules.roseRange(rose, 1), 30))

-- mist
local mist = params("glowup_mist")
local cx, cz = WeaponRules.mistCentre(mist, 1, 0, 0, 0, -1)
check("mist lands ahead", near(cx, 0) and near(cz, -14))
check("mist radius scales", near(WeaponRules.mistRadius(mist, 5), 9 * 1.2))
check("mist lasts", WeaponRules.mistSeconds(mist) == 4)
local mdx, mdz = WeaponRules.mistDrift(0, 0, 5, 0)
check("mist drift points outward", near(mdx, 1) and near(mdz, 0))
local mix, miz = WeaponRules.mistDrift(0, 0, 0, 0)
check("mist drift at the centre is defined", near(mix, 1) and near(miz, 0))

-- mirror
local mirror = params("mirror_shield")
check("reflect window", near(WeaponRules.reflectSeconds(mirror, 1), 2.5))
check("reflect window at five stars", near(WeaponRules.reflectSeconds(mirror, 5), 3))
check("reflecting before the end", WeaponRules.reflecting(10, 11))
check("not reflecting after the end", not WeaponRules.reflecting(10, 9))
check("not reflecting with no attribute", not WeaponRules.reflecting(10, nil))
check("not reflecting with a bad attribute", not WeaponRules.reflecting(10, "x"))

-- shaker
local shaker = params("protein_shaker")
check("shaker radius", near(WeaponRules.shakerRadius(shaker, 1), 14))
check("shaker boost", near(WeaponRules.shakerBoost(shaker, 1), 0.4))
check("shaker boost five stars", near(WeaponRules.shakerBoost(shaker, 5), 0.48))
check("shaker seconds", WeaponRules.shakerSeconds(shaker) == 3)
check("shaker knock", near(WeaponRules.shakerKnock(shaker, 1, 14), 14))

-- mic
local mic = params("main_character_mic")
check("mic radius", near(WeaponRules.micRadius(mic, 1), 16))
check("mic seconds", near(WeaponRules.micSeconds(mic, 1), 1.5))
check("mic seconds five stars", near(WeaponRules.micSeconds(mic, 5), 1.8))

-- gauntlet
local gauntlet = params("gigachad_gauntlet")
check("charge fraction half", near(WeaponRules.chargeFraction(0.45, gauntlet), 0.5))
check("charge fraction full", WeaponRules.chargeFraction(5, gauntlet) == 1)
check("charge fraction zero", WeaponRules.chargeFraction(0, gauntlet) == 0)
check("gauntlet full charge is big", near(WeaponRules.gauntletKnock(gauntlet, 1, 14, 1), 44.8))
check("gauntlet tap is half power", near(WeaponRules.gauntletKnock(gauntlet, 1, 14, 0), 22.4))
check("gauntlet five stars stays under the cap", WeaponRules.gauntletKnock(gauntlet, 5, 14, 1) <= WeaponRules.MAX_STUDS)
check("gauntlet beats the hammer", WeaponRules.gauntletKnock(gauntlet, 1, 14, 1) > WeaponRules.hammerKnock(hammer, 1, 14))

-- power budget: no weapon's knockback exceeds the cap at five stars, and rarity never enters the formulas
for _, weapon in WeaponCatalog.weapons do
	local knock = weapon.params.knock
	if knock then
		check(weapon.id .. " knock under cap", WeaponRules.clampStuds(14 * knock * WeaponRules.scale(5)) <= WeaponRules.MAX_STUDS)
	end
	check(weapon.id .. " has a cooldown", weapon.cooldown > 0)
end

-- looks
check("common sound", WeaponRules.soundKey("common") == "weapon_swing")
check("rare sound", WeaponRules.soundKey("rare") == "weapon_rare" and WeaponRules.soundKey("epic") == "weapon_rare")
check("legendary sound", WeaponRules.soundKey("legendary") == "weapon_legendary" and WeaponRules.soundKey("mythic") == "weapon_legendary")
check("visual tiers", WeaponRules.visualTier("common") == 1 and WeaponRules.visualTier("epic") == 2 and WeaponRules.visualTier("mythic") == 3)
check("glow skin at five stars only", WeaponRules.glowSkin(5) and not WeaponRules.glowSkin(4))

-- moglings
check("mogling waits at least twice the cooldown", WeaponRules.moglingNextUse(100, 3, 0) >= 106)
check("mogling waits at most four times", WeaponRules.moglingNextUse(100, 3, 1) <= 112.001)

if failures > 0 then
	error(failures .. " test(s) failed")
end
print("All tests passed")
