--!strict
-- THE SEASON PASS: the numbers and rewards. THE PASS IS OFF UNTIL UPDATE 1 (Features.seasonPass = false); this file is
-- built and tested but nothing loads it while the flag is off. It is ALL FREE: no Robux, never sold, no power (design
-- rule 1). Pure: no Roblox calls, so tests/SeasonPassConfig.test.luau runs without Studio.
--
-- 20 tiers. Every tier has ONE reward. xp comes from three sources (Config.sources). Reward kinds:
--   aura   = `seconds` of the player's income at their current level (the server turns it into aura)
--   trail  = a trail colour. `id` is a CosmeticCatalog id when `inCatalog` is true; otherwise it is a config-only id that the
--            server records in data.pass.claimed as "grant:<id>" so Update 1 can honour it once the cosmetic exists
--   title  = a small title above the head (config-only id, `text` is the words), recorded the same way
--   skin   = a weapon skin (config-only id, recorded the same way)
--   chest  = one weapon from DataService.rollWeapon(player, "quest")
--   future = the weapon RESERVED FOR UPDATE 1 (futureWeaponId = true). It is NOT in WeaponCatalog; the server only records
--            "grant:<id>" and Update 1 hands the weapon out.
-- NOTE for the integrator: config-only ids (pass_*) are not in CosmeticCatalog yet. Add them there in Update 1.

local SeasonPassConfig = {}

export type Reward = {
	kind: string,
	id: string?,
	name: string?,
	text: string?,
	seconds: number?,
	inCatalog: boolean?,
	futureWeaponId: boolean?,
}

SeasonPassConfig.tierCount = 20

-- xp needed to go from tier n-1 to tier n (index n). Grows slowly: 100 at tier 1, 252 at tier 20, 3520 in all.
SeasonPassConfig.tierXp = {
	100, 108, 116, 124, 132, 140, 148, 156, 164, 172,
	180, 188, 196, 204, 212, 220, 228, 236, 244, 252,
} :: { number }

-- xp each thing earns (the names are Events kinds: "war", "flag", "quest").
SeasonPassConfig.sources = {
	war = 60, -- a war finished (you were in it)
	flag = 10, -- you helped capture a flag
	quest = 40, -- a quest completed
} :: { [string]: number }

-- The reward for each tier (index = tier).
SeasonPassConfig.rewards = {
	{ kind = "aura", seconds = 60 },
	{ kind = "trail", id = "trail_spark", name = "Spark Trail", inCatalog = true },
	{ kind = "title", id = "pass_title_rookie", name = "Title: Pass Rookie", text = "Pass Rookie" },
	{ kind = "aura", seconds = 120 },
	{ kind = "chest" },
	{ kind = "trail", id = "pass_trail_mint", name = "Mint Trail" },
	{ kind = "skin", id = "pass_skin_stripes", name = "Stripes Skin" },
	{ kind = "aura", seconds = 180 },
	{ kind = "title", id = "pass_title_flag_runner", name = "Title: Flag Runner", text = "Flag Runner" },
	{ kind = "chest" },
	{ kind = "aura", seconds = 240 },
	{ kind = "trail", id = "pass_trail_sunset", name = "Sunset Trail" },
	{ kind = "skin", id = "pass_skin_checker", name = "Checker Skin" },
	{ kind = "aura", seconds = 300 },
	{ kind = "chest" },
	{ kind = "title", id = "pass_title_clutch", name = "Title: Clutch Capturer", text = "Clutch Capturer" },
	{ kind = "aura", seconds = 420 },
	{ kind = "skin", id = "pass_skin_sparkle", name = "Sparkle Skin" },
	{ kind = "chest" },
	{ kind = "future", id = "comet_plunger", name = "Comet Plunger", futureWeaponId = true },
} :: { Reward }

local KINDS = { aura = true, trail = true, title = true, skin = true, chest = true, future = true }

-- cumulative[n] = total xp to reach tier n (cumulative[0] = 0). Built once from tierXp.
local cumulative: { [number]: number } = { [0] = 0 }
for tier = 1, SeasonPassConfig.tierCount do
	cumulative[tier] = cumulative[tier - 1] + SeasonPassConfig.tierXp[tier]
end

SeasonPassConfig.totalXp = cumulative[SeasonPassConfig.tierCount]

-- Total xp needed to reach `tier` (clamped to 0..tierCount).
function SeasonPassConfig.xpToReach(tier: number): number
	return cumulative[math.clamp(math.floor(tier), 0, SeasonPassConfig.tierCount)]
end

-- The tier reached with `xp` (0 to tierCount). Bad numbers give 0.
function SeasonPassConfig.tierForXp(xp: number): number
	if xp ~= xp or xp <= 0 then
		return 0
	end
	local tier = 0
	for n = 1, SeasonPassConfig.tierCount do
		if xp >= cumulative[n] then
			tier = n
		else
			break
		end
	end
	return tier
end

-- (xp into the current tier, xp the current tier needs). At the last tier: (1, 1), a full bar.
function SeasonPassConfig.progress(xp: number): (number, number)
	local tier = SeasonPassConfig.tierForXp(xp)
	if tier >= SeasonPassConfig.tierCount then
		return 1, 1
	end
	return math.max(0, xp) - cumulative[tier], SeasonPassConfig.tierXp[tier + 1]
end

-- xp for an Events kind, or 0 when it earns nothing.
function SeasonPassConfig.xpForSource(kind: string): number
	return SeasonPassConfig.sources[kind] or 0
end

-- Add xp and cap at the end of the pass. Returns the new xp.
function SeasonPassConfig.addXp(xp: number, amount: number): number
	if amount ~= amount or amount <= 0 then
		return xp
	end
	return math.min(SeasonPassConfig.totalXp, math.max(0, xp) + amount)
end

function SeasonPassConfig.rewardFor(tier: number): Reward?
	return SeasonPassConfig.rewards[tier]
end

-- The id a claim is saved under in data.pass.claimed: "t5".
function SeasonPassConfig.claimId(tier: number): string
	return "t" .. tostring(tier)
end

-- A claim request from the client: a number tier or a string id ("t5" or "5"). Returns the tier or nil. Anything else is nil.
function SeasonPassConfig.parseTier(value: any): number?
	local tier: number? = nil
	if type(value) == "number" then
		tier = value
	elseif type(value) == "string" and #value <= 3 then
		local digits = string.match(value, "^t?(%d+)$")
		tier = if digits then tonumber(digits) else nil
	end
	if tier == nil or tier ~= tier or tier ~= math.floor(tier) then
		return nil
	end
	if tier < 1 or tier > SeasonPassConfig.tierCount then
		return nil
	end
	return tier
end

-- The key saved for a reward that has nothing to give yet (config-only ids and the future weapon).
function SeasonPassConfig.grantKey(reward: Reward): string
	return "grant:" .. (reward.id or reward.kind)
end

-- A short ASCII label for a tile.
function SeasonPassConfig.describe(reward: Reward): string
	if reward.kind == "aura" then
		local seconds = reward.seconds or 0
		return if seconds >= 60 then ("%d min aura"):format(seconds // 60) else ("%d s aura"):format(seconds)
	elseif reward.kind == "chest" then
		return "Weapon chest"
	end
	return reward.name or reward.kind
end

-- The aura an aura reward gives for a given income per second (the server passes Levels.nominalIncome(level)).
function SeasonPassConfig.auraAmount(reward: Reward, incomePerSecond: number): number
	if reward.kind ~= "aura" or incomePerSecond ~= incomePerSecond or incomePerSecond <= 0 then
		return 0
	end
	return math.floor((reward.seconds or 0) * incomePerSecond)
end

-- Is this a reward kind the server knows how to give?
function SeasonPassConfig.validKind(kind: string): boolean
	return KINDS[kind] == true
end

return SeasonPassConfig
