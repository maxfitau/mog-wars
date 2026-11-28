--!strict
-- THE pace settings file: speed, dashes, faster wars, overtime, pickups, the "+1" aura ticks and the results screen.
-- Every number that makes Mog Wars fast lives here so you can tune it. Nothing here can be bought with Robux.
-- Combat numbers (damage, fire rates, respawn time, hit and mog aura, combo) are in Weapons.luau.
-- Capture speed per flag is below; the war length and the gap between wars are in EconomyConfig.war.

local Pace = {}

Pace.speed = {
	war = { walk = 22, jump = 55 }, -- War Island
	normal = { walk = 16, jump = 50 }, -- Training Island stays normal
	pad = { boost = 0.5, seconds = 3, cooldownSeconds = 1.5 }, -- speed pads on the paths: +50 percent for 3 seconds
	rush = { boost = 0.2, seconds = 2 }, -- AURA RUSH after mogging someone
	shake = { boost = 0.5, seconds = 8 }, -- Protein Shake pickup
	dash = { cooldownSeconds = 4, speed = 85, seconds = 0.22, doubleTapSeconds = 0.3 }, -- short dash (double-tap on PC, a button on mobile)
	launchPad = { horizontal = 75, vertical = 48 }, -- the pad by each base that throws you toward the action
}

-- Rank-unlocked abilities, one button each, earned in the first session and never sold.
Pace.abilities = {
	shove = { rank = 1 }, -- NPC: Shove (cooldown is EconomyConfig.shove)
	dash = { rank = 2 }, -- Rookie: Glow-Up Dash, a sparkly burst forward (cooldown and speed in Pace.speed.dash)
	stare = { rank = 3, cooldownSeconds = 8, range = 50, freezeSeconds = 1 }, -- Sigma: Mog Stare freezes one enemy
	slam = { rank = 4, cooldownSeconds = 10, radius = 10, knockbackStuds = 24 }, -- Chadlite: Jawline Slam (jump + ground pound)
	flip = { rank = 5, cooldownSeconds = 12, range = 26, coneDot = 0.5, knockbackStuds = 32 }, -- Chad: Hair Flip, a cone gust
	shield = { rank = 6, cooldownSeconds = 18, seconds = 3 }, -- Gigachad: Mewing Shield, immune to shove, stare and knockback
	total = { rank = 7, cooldownSeconds = 30, radius = 20, seconds = 2, slow = 0.5 }, -- Mog God: Total Mog, enemies REDUCED TO NPC
	moglingCooldownFactor = 1.5, -- Moglings wait this much longer between abilities
}

-- Aura stealing: knock someone off an island (or freeze them and then shove them) and they drop glowing aura orbs worth
-- a share of the aura they earned THIS WAR (never their saved total, so ranks never go down). Orbs go to whoever touches them.
Pace.steal = {
	fraction = 0.10,
	bountyFraction = 0.20, -- stealing from the player with the most aura
	minWarAura = 40, -- nothing to steal below this
	bountyMinAura = 300, -- the crown only appears once the leader has this much war aura
	orbs = 6,
	orbSeconds = 15,
	magnetRange = 14,
	pickupRange = 3.5,
	attributionSeconds = 6, -- a fall counts as a knock-off if you were shoved this recently
	victimCooldownSeconds = 8,
}

-- Rifts: glowing portals that throw you high into the sky, then you glide down with a little glider.
Pace.rift = {
	launch = 175, -- upward speed
	glideFall = 20, -- the slowest you fall while gliding (studs per second)
	glideSpeed = 38, -- steering speed while gliding
	offlineSeconds = 20, -- a rift flickers out after use, then returns
}

-- DOPAMINE: small rewards every few seconds, bigger ones every ~30 s, huge ones every few minutes.
Pace.crit = {
	megaChance = 0.05, -- any aura gain: 5 percent becomes MEGA MOG! ...
	megaMultiplier = 5,
	ultraChance = 0.01, -- ... and 1 percent becomes ULTRA MOG!
	ultraMultiplier = 10,
	minAura = 3, -- gains smaller than this (the +1 ticks) never crit, so the numbers stay readable
}

Pace.combo = {
	windowSeconds = 4, -- captures, shoves, orb pickups and stashes this close together build the combo
	tiers = { { 2, 2 }, { 3, 3 }, { 5, 5 }, { 8, 10 } }, -- { events in a row, aura multiplier }: x2, x3, x5, x10
	maxTotalMultiplier = 20, -- combo and crit together never pass this
	callouts = { [3] = "ON FIRE!", [6] = "UNSTOPPABLE!" },
}

Pace.quests = {
	perWar = 3,
	pool = {
		{ id = "shove_moglings", text = "Shove %d Moglings", kind = "shove_mogling", goal = 5, reward = 60 },
		{ id = "shove_players", text = "Shove %d players", kind = "shove_player", goal = 3, reward = 80 },
		{ id = "capture_flags", text = "Capture %d flags", kind = "flag", goal = 2, reward = 100 },
		{ id = "stash", text = "Find a stash", kind = "stash", goal = 1, reward = 120 },
		{ id = "zipline", text = "Ride a zipline", kind = "zipline", goal = 1, reward = 60 },
		{ id = "launch", text = "Use %d launch pads", kind = "launch", goal = 2, reward = 50 },
		{ id = "territory", text = "Capture a territory", kind = "territory", goal = 1, reward = 150 },
		{ id = "orbs", text = "Grab %d aura orbs", kind = "orb", goal = 3, reward = 70 },
		{ id = "freeze", text = "Freeze an enemy", kind = "stare", goal = 1, reward = 70 },
		{ id = "yeet", text = "Knock someone off an island", kind = "yeet", goal = 1, reward = 120 },
		{ id = "rift", text = "Use a rift", kind = "rift", goal = 1, reward = 80 },
	},
}

Pace.chest = {
	aura = { min = 50, max = 300 },
	weights = { aura = 60, cosmetic = 20, title = 20 }, -- a free reward: aura, a free trail or aura colour, or a title
	titles = { "Lucky", "Chest Goblin", "Treasure Mog", "Shiny" },
	seconds = 4, -- the chest scene after the results (the gap between wars grows by this much)
}

-- BIG NUMBERS. Every rank has 10 levels (Rookie I-X ... Mog God I-X), then endless "Mog God *1, *2 ...". Every level multiplies ALL
-- aura income by `growth`. The owner's idea was about 2.5; that would give Mog God I about 1e20 aura a second, so the default is
-- 1.74, which gives trillions a second at Mog God I and reaches the letter suffixes (aa, ab ...) in the star levels. Set it to 2.5
-- if you want even bigger numbers. Aura and levels are SCORE AND STATUS ONLY: they never change an ability, speed or capture speed.
Pace.levels = {
	perRank = 10,
	growth = 1.74,
	-- Aura a second an ACTIVE player earns at level 0 (set from Pace.income below: tests/Pacing.test.luau checks they agree).
	nominalIncome = 11.3,
	-- How long each level takes for an active player, by the level you are leaving, in bands: { first level, how many levels,
	-- seconds for the first, seconds for the last }. Inside a band it ramps up in a straight line, and every band starts above
	-- where the last one ended, so EVERY level takes longer than the one before (thresholds grow faster than income).
	-- Reach: Rookie 50 s, Sigma 10 min, Chadlite 30 min, Chad 1 hr, Gigachad 3 hr, Mog God I about 72 hours (3 days of play).
	bands = {
		{ 0, 11, 50, 59.1 },
		{ 11, 10, 105, 135 },
		{ 21, 10, 150, 210 },
		{ 31, 10, 550, 890 },
		{ 41, 10, 18000, 31680 },
		{ 51, 10, 33000, 60000 },
	},
	starSeconds = 63000, -- each star level after Mog God X ...
	starGrowth = 1.05, -- ... takes this much longer than the last
	maxLevel = 400,
	passiveMaxLevel = 10, -- the "just for being here" aura stops at the end of Rookie: you cannot idle past Rookie
	maxAura = 1e300, -- saved aura is clamped here (a double holds up to about 1.8e308)
}

-- SERVER EVENTS: one per war, rotating through `rotation` (add more kinds in EventSystem). Free rewards only, never sold.
Pace.events = {
	rotation = { "meteor" },
	startFraction = 0.5, -- the warning starts this far through the war
}
Pace.meteor = {
	warningSeconds = 15,
	holdSeconds = 20, -- one team must hold the flag this long IN TOTAL (not in a row)
	activeSeconds = 70, -- the meteor crumbles if nobody has held it that long
	flagRadius = 15,
	flagValue = 5, -- worth 5x a normal flag to Moglings
	rewardSeconds = 150, -- every member of the winning team gets this many seconds of income
	orbCount = 14,
	orbSeconds = 20, -- each scattered orb is worth this many seconds of income
}
-- SUPPLY DROPS: free crates, never sold. Rewards are in seconds of income so they stay exciting at every level.
Pace.drops = {
	everySeconds = 45,
	goldOneIn = 8,
	holdSeconds = 1.5,
	fallSeconds = 14,
	lifetimeSeconds = 70,
	auraSeconds = 25, -- the big aura burst, in seconds of income
	goldAuraSeconds = 150,
	mainCharacterSeconds = 15,
	goldMainCharacterSeconds = 30,
	shakeSeconds = 10,
	-- weights: aura, main character mode, protein shake, rare cosmetic (a trail or title from the free "box" list)
	weights = { aura = 40, main = 25, shake = 25, cosmetic = 10 },
	goldWeights = { aura = 40, main = 20, shake = 10, cosmetic = 30 },
}
-- Sound ids (rbxassetid://...). Empty = silent. Add your own licensed or Roblox-made ids here.
Pace.sounds = { alarm = "", boom = "", pop = "", gold = "" }

-- CHUD CHAMBERS TRAP DUNGEON. Traps never hurt: they knock you back, fling you, or slime you back to the dungeon entrance.
-- Every trap telegraphs (glow and sound) about `warnSeconds` before it fires. Rewards are in seconds of income.
Pace.traps = {
	warnSeconds = 1,
	flagBonus = 1.5, -- aura from flags in Chud Chambers (harder to reach)
	shoveSeconds = 20, -- "TRAP SHOVE!" reward for knocking an enemy into a trap
	shoveWindowSeconds = 6, -- a trap hit counts as your shove if you shoved them this recently
	treasureSeconds = 60, -- the hidden treasure room, once per war per player
	trappedSeconds = 2, -- the slime hold before you are sent back to the entrance
	knock = 38, -- how hard a swing, a boulder or the cans throw you back
	sounds = { warn = "", boom = "", chomp = "", zap = "", fart = "", slime = "" }, -- rbxassetid:// ids; empty = silent
}

-- DEBUG: the "/mog" chat commands. They only work in Roblox Studio (never in a live server) and only for the user ids listed here
-- (the place owner's id is added automatically for a place saved under a user). Put YOUR Roblox user id in this list.
Pace.debug = {
	allowedUserIds = {} :: { number },
}

Pace.capture = {
	secondsPerFlag = { gold = 4, diamond = 6, ultra = 8 }, -- one player alone, per flag
	extraPlayerBonus = 0.25, -- each extra teammate on the flag adds this much speed
	maxMultiplier = 2, -- ... up to double speed
}

Pace.overtime = {
	seconds = 60, -- the last stretch of a war
	auraMultiplier = 2, -- all aura is doubled
	musicSpeed = 1.25,
}

-- PASSIVE aura (just for being here) is about 15 percent of an active player's income, and zero for an AFK player. ACTIONS are
-- the main income: standing on a flag, captures, stashes, quests, steals, the war chest and events.
Pace.presence = {
	base = 1.7, -- aura every second just for being in the war (about 15 percent of an active player's income)
	onFlag = 3, -- standing on a flag you are capturing or defending is an ACTION: this much a second instead of the base
	perTerritory = 0, -- (no longer paid just for your team holding land: that let idle players level up)
}

-- AFK: no movement, ability or input for `seconds` = AFK. An AFK player earns nothing passive, shows an AFK tag and cannot
-- hold flags; after `moveSeconds` AFK they are moved back to their team island.
Pace.afk = {
	seconds = 30,
	moveSeconds = 180,
	pingSeconds = 2, -- the client reports real input at most this often
}

-- The pacing model (tests/Pacing.test.luau reads this): what an ACTIVE player does in an average minute, in level-0 aura.
-- Rewards that are "seconds of income" are listed with how many seconds per minute they add on average.
Pace.income = {
	flagHoldSecondsPerMinute = 30, -- standing on a flag you are capturing or defending (paid at Pace.presence.onFlag)
	flagFlipsPerMinute = 1, -- paid Pace.rewards.flagCapturedAura each
	territoryCapturesPerMinute = 0.35, -- paid the tier's aura (Territories.tiers): about 300 on average
	averageTierAura = 300,
	stashesPerMinute = 0.67, -- paid Pace.stash.aura
	questsPerMinute = 0.5, -- paid about 70
	averageQuestAura = 70,
	stealAuraPerMinute = 20,
	chestPerMinute = 1 / 6, -- the war chest after each war, about 175
	averageChestAura = 175,
	comboCritFactor = 1.25, -- combos and crits multiply the above by about this
	eventSecondsPerMinute = 11.75, -- meteor wins, supply drops and the treasure room, as seconds of income per minute
	passiveFraction = 0.15, -- passive aura as a share of an active player's income
}

Pace.rewards = {
	flagTickAura = 0, -- (the old +1 tick on a capturing flag: replaced by Pace.presence)
	flagCapturedAura = 25, -- everyone helping when a flag flips
}

Pace.void = {
	killY = -60, -- below this height you have fallen into the clouds
	respawnSeconds = 2, -- WHOOSH, then back at your team island; no damage
}

Pace.pickups = {
	everySeconds = 30,
	maxActive = 5,
	lifetimeSeconds = 25,
	minRadius = 25, -- from the middle of the island
	maxRadius = 260,
	collectDistance = 7,
	mainCharacterSeconds = 15,
	mainCharacterAuraMultiplier = 2,
	kinds = {
		{ id = "shake", name = "Protein Shake", weight = 40, color = { 90, 220, 120 } },
		{ id = "refill", name = "Aura Refill", weight = 40, color = { 80, 180, 255 } },
		{ id = "main", name = "Main Character Mode", weight = 20, color = { 255, 205, 60 } },
	},
}

Pace.zipline = {
	speed = 62, -- studs per second along the cable
	cooldownSeconds = 1.5,
}

Pace.stash = {
	aura = 100, -- a hidden Aura Stash gives this big burst of aura ... (12 are hidden across the map)
	cooldownSeconds = 60, -- (unused: a stash now opens once per war per player)
}

Pace.results = {
	seconds = 5, -- the results screen (the wait between wars is the same length)
	mvpPerAura = 0.1, -- MVP score: this per aura earned this war ...
	mvpPerMog = 3, -- ... this per mog (combat only) ...
	mvpPerFlag = 5, -- ... this per flag captured ...
	mvpPerAssist = 1.5, -- ... and this per assist
}

Pace.sounds = { whoosh = "", pickup = "", dash = "", overtimeMusic = "", unlock = "", announcer = "" } -- empty until you have licensed ids

return Pace
