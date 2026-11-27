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

Pace.rewards = {
	flagTickAura = 1, -- aura every second you stand on a flag you are capturing
	flagCapturedAura = 25, -- everyone helping when a flag flips
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

Pace.stash = {
	aura = 25, -- a free Aura Stash in a territory's secret spot gives this much aura ...
	cooldownSeconds = 60, -- ... once a minute per player
}

Pace.results = {
	seconds = 5, -- the results screen (the wait between wars is the same length)
	mvpPerAura = 0.1, -- MVP score: this per aura earned this war ...
	mvpPerMog = 3, -- ... this per mog (combat only) ...
	mvpPerFlag = 5, -- ... this per flag captured ...
	mvpPerAssist = 1.5, -- ... and this per assist
}

Pace.sounds = { whoosh = "", pickup = "", dash = "", overtimeMusic = "" } -- empty until you have licensed ids

return Pace
