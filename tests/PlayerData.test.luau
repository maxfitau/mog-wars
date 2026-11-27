--!strict
-- Plain-Luau tests, no Roblox needed. Run from the repo root with the standalone Luau runtime:
--   luau tests/PlayerData.test.luau
-- STATUS: written but NOT yet run (no Luau runtime in the cloud session). Run it on a PC first.

local PlayerData = require("../src/shared/PlayerData")

local failures = 0

local function check(name: string, condition: boolean)
	if condition then
		print("PASS " .. name)
	else
		failures += 1
		print("FAIL " .. name)
	end
end

local data = PlayerData.template()
check("template is valid", PlayerData.isValid(data))
check("new players start at Rookie with 0 points", data.rank == 1 and data.points == 0)

check("adding points works", PlayerData.addPoints(data, 50) and data.points == 50)
check("zero is rejected", not PlayerData.addPoints(data, 0) and data.points == 50)
check("negative is rejected", not PlayerData.addPoints(data, -5) and data.points == 50)
check("fraction is rejected", not PlayerData.addPoints(data, 1.5) and data.points == 50)
check("nan is rejected", not PlayerData.addPoints(data, 0 / 0) and data.points == 50)
check("infinity is rejected", not PlayerData.addPoints(data, math.huge) and data.points == 50)

check("spending works", PlayerData.spendPoints(data, 20) and data.points == 30)
check("overspending changes nothing", not PlayerData.spendPoints(data, 31) and data.points == 30)
check("spending a bad amount changes nothing", not PlayerData.spendPoints(data, -1) and data.points == 30)

local rich = PlayerData.template()
rich.points = PlayerData.MAX_POINTS - 1
PlayerData.addPoints(rich, 100)
check("points never pass the cap", rich.points == PlayerData.MAX_POINTS)

check("bad shapes are invalid", not PlayerData.isValid(nil) and not PlayerData.isValid({}))
local function save(overrides: { [string]: any }): any
	local copy: any = PlayerData.template()
	for key, value in overrides do
		copy[key] = value
	end
	return copy
end
check("wrong version is invalid", not PlayerData.isValid(save({ version = 0 })))
check("negative points are invalid", not PlayerData.isValid(save({ points = -1 })))
check("rank 0 is invalid", not PlayerData.isValid(save({ rank = 0 })))
check("negative wars are invalid", not PlayerData.isValid(save({ warsToday = -1 })))

-- migration from version 1
local old: any = { version = 1, points = 120, rank = 3 }
check("migrate upgrades version 1 to the current version", PlayerData.migrate(old) and old.version == PlayerData.CURRENT_VERSION and old.warsToday == 0 and next(old.boxes) == nil)
check("migrated save is valid and keeps progress", PlayerData.isValid(old) and old.points == 120 and old.rank == 3)
check("migrate rejects non-tables", not PlayerData.migrate(nil))
local v2: any = { version = 2, points = 5, rank = 2, warsToday = 1, lastWarDay = 7 }
check("migrate upgrades version 2", PlayerData.migrate(v2) and PlayerData.isValid(v2) and v2.warsToday == 1)

-- boxes
local boxy = PlayerData.template()
check("adding a box works", PlayerData.addBox(boxy, "gold") and boxy.boxes.gold == 1)
check("an empty tier name is rejected", not PlayerData.addBox(boxy, ""))
boxy.boxes.gold = PlayerData.MAX_BOXES_PER_TIER
check("a full stack is rejected", not PlayerData.addBox(boxy, "gold"))
check("boxes with a negative count are invalid", not PlayerData.isValid(save({ boxes = { gold = -1 } })))
check("boxes with a fractional count are invalid", not PlayerData.isValid(save({ boxes = { gold = 1.5 } })))
check("boxes that are not a table are invalid", not PlayerData.isValid(save({ boxes = 5 })))

-- taking boxes
local taker = PlayerData.template()
PlayerData.addBox(taker, "gold")
PlayerData.addBox(taker, "gold")
check("taking a box works", PlayerData.takeBox(taker, "gold") and taker.boxes.gold == 1)
check("taking the last box removes the entry", PlayerData.takeBox(taker, "gold") and taker.boxes.gold == nil)
check("taking from none changes nothing", not PlayerData.takeBox(taker, "gold") and next(taker.boxes) == nil)

-- daily box cap
local earner = PlayerData.template()
local boxDay = 5000
for _ = 1, 12 do
	PlayerData.tryEarnBox(earner, boxDay, 12, "gold")
end
check("12 boxes earned fills the daily cap", earner.boxesToday == 12 and earner.boxes.gold == 12)
check("the 13th box is refused", not PlayerData.tryEarnBox(earner, boxDay, 12, "gold") and earner.boxes.gold == 12)
check("a new day resets the cap", PlayerData.tryEarnBox(earner, boxDay + 1, 12, "gold") and earner.boxesToday == 1)

-- units and cosmetics
local owner = PlayerData.template()
check("adding a unit works", PlayerData.addUnit(owner, "tank") and owner.units.tank == 1)
check("an empty unit id is rejected", not PlayerData.addUnit(owner, ""))
check("taking a unit works", PlayerData.takeUnit(owner, "tank") and owner.units.tank == nil)
check("taking a unit you do not own changes nothing", not PlayerData.takeUnit(owner, "tank"))
PlayerData.addUnit(owner, "tank")
check("adding a cosmetic works once", PlayerData.addCosmetic(owner, "trail_spark") and not PlayerData.addCosmetic(owner, "trail_spark"))
check("invalid unit counts are rejected", not PlayerData.isValid(save({ units = { tank = -1 } })))
check("a cosmetic marked false is invalid", not PlayerData.isValid(save({ cosmetics = { trail_spark = false } })))
check("streak day above 7 is invalid", not PlayerData.isValid(save({ streakDay = 8 })))
check("negative barracks time is invalid", not PlayerData.isValid(save({ barracksSince = -1 })))
check("negative training level is invalid", not PlayerData.isValid(save({ trainingLevel = -1 })))
check("a huge training count is invalid", not PlayerData.isValid(save({ trainingToday = 90000 })))
check("an equipped entry with an empty id is invalid", not PlayerData.isValid(save({ equipped = { trail = "" } })))
check("receipts with a bad time are invalid", not PlayerData.isValid(save({ receipts = { p1 = -4 } })))
check("a season with negative points is invalid", not PlayerData.isValid(save({ season = { week = 5, points = { ["1"] = -3 }, prevWeek = 0, prevPoints = {}, claimed = 0 } })))
check("a season that is not a table is invalid", not PlayerData.isValid(save({ season = 7 })))
check("negative lifetime counts are invalid", not PlayerData.isValid(save({ lifetimeWars = -1 })) and not PlayerData.isValid(save({ lifetimeCaptures = -1 })))
local v8: any = { version = 8, points = 400, rank = 3, warsToday = 0, lastWarDay = 0, boxes = {}, units = {}, cosmetics = {}, boxDay = 0, boxesToday = 0, streakDay = 0, lastClaimDay = 0, barracksSince = 1, trainingLevel = 0, trainingProgress = 0, trainingDay = 0, trainingToday = 0, equipped = {}, receipts = {}, season = { week = 0, points = {}, prevWeek = 0, prevPoints = {}, claimed = 0 } }
check("migrate upgrades version 8; a ranked-up player sees everything", PlayerData.migrate(v8) and PlayerData.isValid(v8) and v8.lifetimeWars == 3 and v8.lifetimeCaptures == 1)
local v8new: any = { version = 8, points = 0, rank = 1, warsToday = 0, lastWarDay = 0, boxes = {}, units = {}, cosmetics = {}, boxDay = 0, boxesToday = 0, streakDay = 0, lastClaimDay = 0, barracksSince = 1, trainingLevel = 0, trainingProgress = 0, trainingDay = 0, trainingToday = 0, equipped = {}, receipts = {}, season = { week = 0, points = {}, prevWeek = 0, prevPoints = {}, claimed = 0 } }
check("migrate keeps a brand-new player at the start", PlayerData.migrate(v8new) and v8new.lifetimeWars == 0 and v8new.lifetimeCaptures == 0)
local v7: any = { version = 7, points = 3, rank = 2, warsToday = 0, lastWarDay = 0, boxes = {}, units = {}, cosmetics = {}, boxDay = 0, boxesToday = 0, streakDay = 0, lastClaimDay = 0, barracksSince = 1, trainingLevel = 1, trainingProgress = 2, trainingDay = 0, trainingToday = 0, equipped = { trail = "trail_spark" }, receipts = { p1 = 5 } }
check("migrate upgrades version 7 and keeps equipped items", PlayerData.migrate(v7) and PlayerData.isValid(v7) and v7.equipped.trail == "trail_spark" and v7.season.week == 0)
local v6: any = { version = 6, points = 3, rank = 2, warsToday = 0, lastWarDay = 0, boxes = {}, units = {}, cosmetics = { trail_spark = true }, boxDay = 0, boxesToday = 0, streakDay = 0, lastClaimDay = 0, barracksSince = 1, trainingLevel = 4, trainingProgress = 7, trainingDay = 0, trainingToday = 0 }
check("migrate upgrades version 6 and keeps training and cosmetics", PlayerData.migrate(v6) and PlayerData.isValid(v6) and v6.trainingLevel == 4 and v6.cosmetics.trail_spark == true)
local v5: any = { version = 5, points = 9, rank = 2, warsToday = 0, lastWarDay = 0, boxes = {}, units = {}, cosmetics = {}, boxDay = 0, boxesToday = 0, streakDay = 2, lastClaimDay = 5, barracksSince = 7 }
check("migrate upgrades version 5 and keeps the streak", PlayerData.migrate(v5) and PlayerData.isValid(v5) and v5.streakDay == 2 and v5.trainingLevel == 0)
local v4: any = { version = 4, points = 9, rank = 2, warsToday = 0, lastWarDay = 0, boxes = {}, units = {}, cosmetics = {}, boxDay = 0, boxesToday = 0 }
check("migrate upgrades version 4", PlayerData.migrate(v4) and PlayerData.isValid(v4) and v4.streakDay == 0)
local v3: any = { version = 3, points = 1, rank = 1, warsToday = 0, lastWarDay = 0, boxes = { gold = 2 } }
check("migrate upgrades version 3 and keeps boxes", PlayerData.migrate(v3) and PlayerData.isValid(v3) and v3.boxes.gold == 2)

-- daily war limit
local day = PlayerData.dayNumber(86400 * 20000 + 5)
check("day number is days since 1970", day == 20000)
local player = PlayerData.template()
check("new player gets full rewards", PlayerData.rewardMultiplier(player, day, 8, 0.5) == 1)
for _ = 1, 7 do
	PlayerData.recordWar(player, day)
end
check("7 wars still full", PlayerData.rewardMultiplier(player, day, 8, 0.5) == 1)
PlayerData.recordWar(player, day)
check("8 wars then reduced", PlayerData.rewardMultiplier(player, day, 8, 0.5) == 0.5)
check("a new day resets the multiplier", PlayerData.rewardMultiplier(player, day + 1, 8, 0.5) == 1)
PlayerData.recordWar(player, day + 1)
check("a new day restarts the war count", player.warsToday == 1 and player.lastWarDay == day + 1)

-- version 10: weapons
local v9: any = { version = 9, points = 5, rank = 2, warsToday = 0, lastWarDay = 0, boxes = {}, units = {}, cosmetics = {}, boxDay = 0, boxesToday = 0, streakDay = 0, lastClaimDay = 0, barracksSince = 1, trainingLevel = 0, trainingProgress = 0, trainingDay = 0, trainingToday = 0, equipped = {}, receipts = {}, season = { week = 0, points = {}, prevWeek = 0, prevPoints = {}, claimed = 0 }, lifetimeWars = 0, lifetimeCaptures = 0 }
check("migrate upgrades version 9 and adds an empty weapons table", PlayerData.migrate(v9) and PlayerData.isValid(v9) and next(v9.weapons) == nil and v9.version == PlayerData.CURRENT_VERSION)
local weaponPlayer = PlayerData.template()
check("unlockWeapon records a blaster once", PlayerData.unlockWeapon(weaponPlayer, "longshot") == true and PlayerData.unlockWeapon(weaponPlayer, "longshot") == false and weaponPlayer.weapons.longshot == true)

if failures > 0 then
	error(failures .. " test(s) failed")
end
print("All tests passed")
