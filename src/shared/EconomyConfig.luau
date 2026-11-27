--!strict
-- Every Mog Wars number lives here and nowhere else. Systems read it; they never hard-code a value.
-- The reasoning behind each number is in docs/economy.md. `python3 tools/pacing.py` reads THIS file to
-- estimate how many days a player needs per rank, so keep each entry on a simple `name = value,` line.
--
-- Mog Points are earned in play only. Nothing here can be bought with Robux.

export type Drop = {
	weight: number, -- percent chance within the tier. Each tier's weights add up to exactly 100.
	kind: string, -- "points", "unit" or "cosmetic"
	amount: number?, -- for "points"
	unit: string?, -- for "unit": "tank" or "horse"
	cosmetic: string?, -- for "cosmetic": a cosmetic id, never anything that changes power
}

export type Tier = {
	displayName: string,
	drops: { Drop },
}

export type Rank = {
	name: string,
	cost: number, -- Mog Points spent to reach this rank from the one before. NPC is the free starting rank.
}

export type BoxRule = {
	minValue: number, -- a zone worth at least this much gives this box tier
	tier: string,
}

export type Config = {
	war: {
		durationSeconds: number,
		intermissionSeconds: number,
		playersPerServer: number,
		winnerBonusPoints: number,
		participantBonusPoints: number,
		minContributionForBonus: number,
		fullRewardWarsPerDay: number,
		reducedRewardMultiplier: number,
	},
	capture: {
		secondsForOneAura: number,
		tickSeconds: number,
		basePool: number,
		sideValue: number,
		centreValue: number,
		decayPerSecond: number,
		minContribution: number,
		minAward: number,
		shoveAssist: number,
		mogOffWin: number,
	},
	aura: {
		perRankBonus: number,
	},
	shove: {
		cooldownSeconds: number,
		range: number,
		knockbackStuds: number,
		penaltySeconds: number,
		penaltyMultiplier: number,
		minRequestInterval: number,
	},
	mogOff: {
		durationSeconds: number,
		closeRange: number,
		closeSeconds: number,
		maxTapsPerSecond: number,
		cooldownSeconds: number,
		stunSeconds: number,
		knockbackStuds: number,
	},
	ranks: { Rank },
	boxes: {
		dailyCap: number,
		tierForValue: { BoxRule },
		duplicateCosmeticPoints: number,
		tiers: { [string]: Tier },
	},
	units: {
		tank: { sellValue: number, captureMultiplier: number },
		horse: { sellValue: number, speedMultiplier: number },
	},
	dailyStreak: {
		rewards: { string }, -- box tier for streak day 1 to 7
	},
	barracks: {
		baseRatePerHour: number,
		perRankRatePerHour: number,
		maxStoredHours: number,
	},
}

local config: Config = {
	war = {
		durationSeconds = 600,
		intermissionSeconds = 20, -- break between wars while the map resets and winners are shown
		playersPerServer = 16,
		winnerBonusPoints = 60,
		participantBonusPoints = 20,
		minContributionForBonus = 5,
		fullRewardWarsPerDay = 8, -- after this many wars in a day rewards are halved, so play never feels like a chore
		reducedRewardMultiplier = 0.5,
	},
	capture = {
		secondsForOneAura = 24, -- one player with aura power 1 captures an empty zone alone in this many seconds
		tickSeconds = 0.25,
		basePool = 100, -- Mog Points shared among contributors when a zone worth 1 is captured
		sideValue = 1,
		centreValue = 2,
		decayPerSecond = 0.02, -- an abandoned, half-captured zone slowly falls back (fraction of the bar per second)
		minContribution = 3, -- contribution units needed before a player is paid at all (stops standing-by freeloading)
		minAward = 5, -- smallest payout for a paid contributor
		shoveAssist = 1.5, -- contribution for a shove that helps a capture
		mogOffWin = 3, -- contribution for winning a mog-off
	},
	aura = {
		perRankBonus = 0.15, -- each rank adds 15 percent aura power: Mog God (rank 7) is 1.9 times an NPC
	},
	shove = {
		cooldownSeconds = 6, -- time before the same player can shove again
		range = 8, -- studs; the nearest enemy inside this range is the target
		knockbackStuds = 14, -- how far the target is pushed back
		penaltySeconds = 3, -- the target pushes at reduced strength for this long
		penaltyMultiplier = 0.5, -- aura power while shoved (half)
		minRequestInterval = 0.2, -- requests faster than this are ignored, whatever their result
	},
	mogOff = {
		durationSeconds = 5, -- length of the tapping duel
		closeRange = 6, -- studs: two enemies this close inside a zone can start a duel
		closeSeconds = 1.5, -- how long they must stay that close first
		maxTapsPerSecond = 10, -- taps above this rate are ignored, so an autoclicker gains nothing
		cooldownSeconds = 20, -- a player cannot be dragged into another duel for this long
		stunSeconds = 1.5, -- the loser cannot move for this long
		knockbackStuds = 18, -- the loser is pushed back this far
	},
	ranks = {
		{ name = "NPC", cost = 0 },
		{ name = "Rookie", cost = 350 },
		{ name = "Sigma", cost = 800 },
		{ name = "Chadlite", cost = 1500 },
		{ name = "Chad", cost = 2600 },
		{ name = "Gigachad", cost = 10000 },
		{ name = "Mog God", cost = 24000 },
	},
	boxes = {
		dailyCap = 12, -- most boxes a player can earn from captures in one UTC day
		-- A capture gives every paid contributor one box. The tier depends on the zone's value.
		-- Listed from the highest minimum value down; the first match wins.
		tierForValue = {
			{ minValue = 3, tier = "ultra" },
			{ minValue = 2, tier = "diamond" },
			{ minValue = 1, tier = "gold" },
		},
		duplicateCosmeticPoints = 50, -- a cosmetic you already own pays this many Mog Points instead
		tiers = {
			gold = {
				displayName = "Gold Box",
				drops = {
					{ weight = 50, kind = "points", amount = 20 },
					{ weight = 25, kind = "points", amount = 40 },
					{ weight = 8, kind = "points", amount = 80 },
					{ weight = 5, kind = "unit", unit = "horse" },
					{ weight = 2, kind = "unit", unit = "tank" },
					{ weight = 10, kind = "cosmetic", cosmetic = "trail_spark" },
				},
			},
			diamond = {
				displayName = "Diamond Box",
				drops = {
					{ weight = 30, kind = "points", amount = 80 },
					{ weight = 25, kind = "points", amount = 150 },
					{ weight = 12, kind = "points", amount = 300 },
					{ weight = 10, kind = "unit", unit = "horse" },
					{ weight = 8, kind = "unit", unit = "tank" },
					{ weight = 15, kind = "cosmetic", cosmetic = "aura_frost" },
				},
			},
			ultra = {
				displayName = "Ultra Box",
				drops = {
					{ weight = 20, kind = "points", amount = 200 },
					{ weight = 22, kind = "points", amount = 400 },
					{ weight = 13, kind = "points", amount = 800 },
					{ weight = 15, kind = "unit", unit = "horse" },
					{ weight = 15, kind = "unit", unit = "tank" },
					{ weight = 15, kind = "cosmetic", cosmetic = "aura_gold" },
				},
			},
		},
	},
	units = {
		tank = { sellValue = 150, captureMultiplier = 1.5 }, -- 50 percent faster capture for its faction in one zone
		horse = { sellValue = 100, speedMultiplier = 1.3 }, -- 30 percent faster movement for one player
	},
	dailyStreak = {
		rewards = { "gold", "gold", "gold", "diamond", "diamond", "diamond", "ultra" }, -- the daily box, day 1 to 7, then the cycle repeats
	},
	barracks = {
		baseRatePerHour = 6,
		perRankRatePerHour = 2,
		maxStoredHours = 8, -- income stops filling after this long away, so there is no reward for never playing
	},
}

return table.freeze(config)
