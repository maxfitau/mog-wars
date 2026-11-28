--!strict
-- Plain-Luau tests, no Roblox needed. Run from the repo root with the standalone Luau runtime:
--   luau tests/SeasonPassConfig.test.luau
-- STATUS: written but NOT yet run (no Luau runtime in the cloud session). Run it on a PC first.
-- The Season Pass is OFF until Update 1; these tests keep its numbers honest meanwhile.

local Config = require("../src/shared/SeasonPassConfig")
local CosmeticCatalog = require("../src/shared/CosmeticCatalog")
local WeaponCatalog = require("../src/shared/WeaponCatalog")

local failures = 0

local function check(name: string, condition: boolean)
	if condition then
		print("PASS " .. name)
	else
		failures += 1
		print("FAIL " .. name)
	end
end

check("20 tiers of xp", #Config.tierXp == 20 and Config.tierCount == 20)
check("20 rewards", #Config.rewards == 20)

local growing = true
for tier = 2, 20 do
	if Config.tierXp[tier] < Config.tierXp[tier - 1] or Config.tierXp[tier] > Config.tierXp[tier - 1] * 1.2 then
		growing = false
	end
end
check("xp per tier grows slowly", growing)

local sum = 0
for _, xp in Config.tierXp do
	sum += xp
end
check("total xp is the sum", Config.totalXp == sum and Config.xpToReach(20) == sum and Config.xpToReach(0) == 0)

check("tier 0 at 0 xp", Config.tierForXp(0) == 0)
check("tier 0 below the first threshold", Config.tierForXp(99) == 0)
check("tier 1 at 100", Config.tierForXp(100) == 1)
check("tier 2 at 208", Config.tierForXp(208) == 2 and Config.tierForXp(207) == 1)
check("tier 20 at the total and beyond", Config.tierForXp(sum) == 20 and Config.tierForXp(sum * 5) == 20)
check("bad xp is tier 0", Config.tierForXp(-5) == 0 and Config.tierForXp(0 / 0) == 0)

local into, need = Config.progress(150)
check("progress inside tier 1", into == 50 and need == 108)
local fullInto, fullNeed = Config.progress(sum)
check("progress at the end is a full bar", fullInto == fullNeed)

check("sources", Config.xpForSource("war") > 0 and Config.xpForSource("flag") > 0 and Config.xpForSource("quest") > 0)
check("unknown source earns nothing", Config.xpForSource("shove_player") == 0)
check("addXp caps", Config.addXp(sum - 1, 500) == sum and Config.addXp(10, -3) == 10 and Config.addXp(10, 5) == 15)

check("parse number", Config.parseTier(5) == 5)
check("parse string id", Config.parseTier("t12") == 12 and Config.parseTier("7") == 7)
check("parse rejects bad", Config.parseTier(0) == nil and Config.parseTier(21) == nil and Config.parseTier(2.5) == nil)
check("parse rejects types", Config.parseTier({}) == nil and Config.parseTier(nil) == nil and Config.parseTier(true) == nil)
check("parse rejects junk strings", Config.parseTier("t5; drop") == nil and Config.parseTier("") == nil and Config.parseTier("t") == nil)
check("parse rejects nan and inf", Config.parseTier(0 / 0) == nil and Config.parseTier(math.huge) == nil)

local kindsOk, catalogOk, chests, futures = true, true, 0, 0
local ids: { [string]: boolean } = {}
for tier, reward in Config.rewards do
	if not Config.validKind(reward.kind) then
		kindsOk = false
	end
	if reward.kind == "trail" and reward.inCatalog and CosmeticCatalog.byId[reward.id :: string] == nil then
		catalogOk = false
	end
	if reward.kind == "chest" then
		chests += 1
	end
	if reward.kind == "future" then
		futures += 1
		check("the future weapon is on tier 20", tier == 20 and reward.futureWeaponId == true)
		check("the future weapon is not in WeaponCatalog yet", WeaponCatalog.byId[reward.id :: string] == nil)
	end
	if reward.id then
		check("unique reward id " .. reward.id, not ids[reward.id])
		ids[reward.id] = true
	end
	check("describe tier " .. tier, #Config.describe(reward) > 0)
end
check("all reward kinds are known", kindsOk)
check("catalog trails exist", catalogOk)
check("a few chests", chests >= 3 and chests <= 5)
check("exactly one future weapon", futures == 1)

check("aura reward maths", Config.auraAmount({ kind = "aura", seconds = 60 }, 11.3) == 678)
check(
	"aura maths ignores other kinds and bad income",
	Config.auraAmount({ kind = "chest" }, 5) == 0 and Config.auraAmount({ kind = "aura", seconds = 60 }, -1) == 0
)
check("claim id", Config.claimId(5) == "t5")

if failures > 0 then
	error(("%d test(s) failed"):format(failures))
end
print("All SeasonPassConfig tests passed")
