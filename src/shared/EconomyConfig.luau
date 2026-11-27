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
	weapon: string?, -- for "weapon": a weapon id (aurablaster, flexblast, sideeye)
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
		decayPerSecond: number,
		minContribution: number,
		minAward: number,
		shoveAssist: number,
		mogOffWin: number,
	},
	training: {
		maxLevel: number,
		perLevelBonus: number,
		firstLevelSeconds: number,
		stepSeconds: number,
		dailyStrideCap: number,
		auraPerStride: number,
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
	squad: {
		perFriendBonus: number,
		maxFriends: number,
		friendTolerance: number,
	},
	season: {
		minPoints: number,
		pointsPerZoneValue: number,
		pointsWarWin: number,
		pointsMogOffWin: number,
		flushSeconds: number,
		refreshSeconds: number,
	},
	bots: {
		minFighters: number,
		rewardFactor: number,
		tapRateBase: number,
		tapRatePerRank: number,
		tapRateSpread: number,
		tapRateNewPlayerFactor: number,
		tapRateMin: number,
		tapRateMax: number,
		auraPerRank: number,
		manageSeconds: number,
		thinkSeconds: number,
		walkSpeed: number,
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
		rewards: { string }, -- box tier for streak day 1 to 7 (old, unused while boxes are off)
		auraRewards: { number }, -- aura for streak day 1 to 7
	},
	barracks: {
		baseRatePerHour: number,
		perRankRatePerHour: number,
		maxStoredHours: number,
	},
}

local config: Config = {
	war = {
		durationSeconds = 360, -- 6 minutes; fast wars (WarRules keeps it between 3 and 15 minutes)
		intermissionSeconds = 5, -- the results screen, then straight into the next war
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
		decayPerSecond = 0.02, -- an abandoned, half-captured zone slowly falls back (fraction of the bar per second)
		minContribution = 3, -- contribution units needed before a player is paid at all (stops standing-by freeloading)
		minAward = 5, -- smallest payout for a paid contributor
		shoveAssist = 1.5, -- contribution for a shove that helps a capture
		mogOffWin = 3, -- contribution for winning a mog-off
	},
	training = {
		maxLevel = 20, -- training levels; aura power is 1x at level 0 and 1.9x at the top
		perLevelBonus = 0.045, -- each training level adds 4.5 percent aura power
		firstLevelSeconds = 45, -- seconds of running to reach level 1
		stepSeconds = 60, -- each later level needs this many more seconds than the one before
		dailyStrideCap = 600, -- at most 10 minutes of training count per UTC day (healthy play)
		auraPerStride = 10, -- one second on a treadmill is 10 aura; territory rewards are paid in the same aura points
	},
	shove = {
		cooldownSeconds = 1.5, -- time before the same player can shove again
		range = 9, -- studs; the nearest enemy inside this range is the target
		knockbackStuds = 14, -- how far the target is pushed back
		penaltySeconds = 1.5, -- the target pushes at reduced strength for this long
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
	squad = {
		perFriendBonus = 0.1, -- capture with a friend on your faction: +10 percent of your points per friend
		maxFriends = 3, -- at most +30 percent
		friendTolerance = 1, -- a joining player may pick a friend's faction if it is at most this many players bigger than the smallest
	},
	season = {
		minPoints = 50, -- season points for the winning faction needed to earn the champion title
		pointsPerZoneValue = 1, -- a capture gives this many season points per zone value
		pointsWarWin = 3, -- for contributors on the faction that wins a war
		pointsMogOffWin = 1,
		flushSeconds = 30, -- how often a server adds its new season points to the shared faction totals
		refreshSeconds = 60, -- how often a server reads the shared faction totals
	},
	bots = {
		minFighters = 8, -- a war with fewer fighters than this is filled up with bots
		rewardFactor = 0.4, -- Mog Points for beating a bot are 40 percent of the normal amount
		tapRateBase = 3.0, -- taps a second a bot taps against an NPC-rank player in a mog-off
		tapRatePerRank = 0.4, -- plus this much for each rank of the player it faces
		tapRateSpread = 0.9, -- how much each duel varies, so bots sometimes win and sometimes lose
		tapRateNewPlayerFactor = 0.8, -- bots tap this much slower against a player who has not finished a war yet
		tapRateMin = 1.5,
		tapRateMax = 8.5, -- always below the server's cap of 10 taps a second
		auraPerRank = 0.03, -- bot aura power grows this much per average player rank (small)
		manageSeconds = 1, -- how often the server adds or removes ONE bot
		thinkSeconds = 0.5, -- how often bots choose where to run
		walkSpeed = 20,
	},
	ranks = {
		{ name = "NPC", cost = 0 },
		{ name = "Rookie", cost = 150 }, -- aura needed to reach this rank from the one before; ranks are earned by total aura
		{ name = "Sigma", cost = 1050 },
		{ name = "Chadlite", cost = 3800 },
		{ name = "Chad", cost = 20000 },
		{ name = "Gigachad", cost = 55000 },
		{ name = "Mog God", cost = 120000 },
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
					{ weight = 48, kind = "points", amount = 20 },
					{ weight = 2, kind = "weapon", weapon = "flexblast" },
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
					{ weight = 27, kind = "points", amount = 80 },
					{ weight = 3, kind = "weapon", weapon = "sideeye" },
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
		rewards = { "gold", "gold", "gold", "diamond", "diamond", "diamond", "ultra" }, -- (old daily box tiers, unused while boxes are off)
		auraRewards = { 40, 60, 80, 120, 160, 220, 400 }, -- the daily reward: aura, day 1 to 7, then the cycle repeats
	},
	barracks = {
		baseRatePerHour = 6,
		perRankRatePerHour = 2,
		maxStoredHours = 8, -- income stops filling after this long away, so there is no reward for never playing
	},
}

return table.freeze(config)
