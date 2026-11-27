--!strict
-- THE combat settings file: the three blasters and every paintball combat number. All earned by playing,
-- never sold for Robux. Balance idea: each blaster is the best in one range band and worse elsewhere.
--   Splatter      starter all-rounder, medium range, one ball a shot
--   Splash Cannon close range, a 3-ball spread, slow fire (wins up close)
--   Long Shot     long range, one strong shot, slow reload, small zoom (the only one that reaches far)
-- Unlock: by rank (Splash Cannon at Rookie, Long Shot at Sigma) or from Gold and Diamond boxes.

export type Weapon = {
	id: string,
	name: string,
	damage: number, -- per ball (a hit takes this much of the target's 100 health)
	pellets: number, -- balls per shot
	spreadDeg: number, -- how far balls can stray from the aim, in degrees
	range: number, -- studs
	fireInterval: number, -- seconds between shots
	magazine: number,
	reloadSeconds: number,
	unlockRank: number, -- rank number that unlocks it (1 = NPC, 2 = Rookie, 3 = Sigma)
	zoom: number, -- how many degrees the camera zooms in (0 = none)
}

local Weapons = {}

Weapons.order = { "splatter", "splashcannon", "longshot" }

Weapons.list = {
	splatter = { id = "splatter", name = "Splatter", damage = 25, pellets = 1, spreadDeg = 0.6, range = 120, fireInterval = 0.45, magazine = 12, reloadSeconds = 1.5, unlockRank = 1, zoom = 0 },
	splashcannon = { id = "splashcannon", name = "Splash Cannon", damage = 18, pellets = 3, spreadDeg = 7, range = 45, fireInterval = 1.1, magazine = 6, reloadSeconds = 2.2, unlockRank = 2, zoom = 0 },
	longshot = { id = "longshot", name = "Long Shot", damage = 50, pellets = 1, spreadDeg = 0.2, range = 220, fireInterval = 1.4, magazine = 4, reloadSeconds = 2.5, unlockRank = 3, zoom = 30 },
} :: { [string]: Weapon }

Weapons.combat = {
	health = 100,
	respawnSeconds = 3, -- after a splat
	shieldSeconds = 2, -- no damage and no shooting right after spawning
	splatAura = 10, -- aura for a splat (aura means aura points)
	splatPoints = 5, -- Mog Points for a splat
	assistFraction = 0.5, -- an assist pays this fraction of a splat
	botRewardFactor = 0.5, -- splatting a bot pays half
	assistWindowSeconds = 8, -- damage within this long before a splat counts as an assist
	assistMinDamage = 10,
	defendBonusAura = 5, -- extra aura for a splat made while standing in a zone your faction holds
	damageBonusCap = 0.10, -- rank damage bonus never goes past +10 percent
	damageBonusPerRank = 0.015,
	aimAssistDegrees = 6, -- mobile: how close to the crosshair an enemy must be to be nudged onto
	botSpreadDeg = 4, -- bots aim this much worse
	botFireIntervalMin = 0.7,
	botFireIntervalMax = 1.2,
	botRange = 60,
	botCoverHealth = 45, -- a bot below this health looks for cover
	maxRequestsPerSecond = 12, -- fire requests above this are ignored
	streaks = { [3] = "MOGGING", [5] = "UNSTOPPABLE" },
	-- Sound asset ids. Left empty on purpose: paste real ids once you have licensed sounds.
	sounds = { fire = "", hit = "", splat = "" },
}

return Weapons
