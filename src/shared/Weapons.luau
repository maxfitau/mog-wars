--!strict
-- THE combat settings file: the three Mog weapons and every combat number. All earned by playing, never sold for
-- Robux. Balance idea: each weapon is the best in one range band and worse elsewhere.
--   Aura Blaster    starter all-rounder, medium range, one glowing aura blast a shot (3 hits to mog someone)
--   Flex Blast      close range: the character flexes and a 3-blast cone shockwave goes out; slow fire
--   Side-Eye Sniper long range: a narrow stare beam, one strong shot, slow reload, small zoom
-- Unlock: by rank (Flex Blast at Rookie, Side-Eye Sniper at Sigma) or from Gold and Diamond boxes.

export type Weapon = {
	id: string,
	name: string,
	style: string, -- how the client draws it: "blast" (glowing ball), "cone" (flex shockwave) or "beam" (stare)
	damage: number, -- per aura blast (a hit takes this much of the target's 100 ego)
	pellets: number, -- blasts per shot
	spreadDeg: number, -- how far blasts can stray from the aim, in degrees
	range: number, -- studs
	fireInterval: number, -- seconds between shots
	magazine: number, -- aura charge: shots before a reload
	reloadSeconds: number,
	unlockRank: number, -- rank number that unlocks it (1 = NPC, 2 = Rookie, 3 = Sigma)
	zoom: number, -- how many degrees the camera zooms in (0 = none)
	icon: string, -- one letter on the hotbar badge
}

local Weapons = {}

Weapons.order = { "aurablaster", "flexblast", "sideeye" }

Weapons.list = {
	aurablaster = { id = "aurablaster", name = "Aura Blaster", style = "blast", damage = 34, pellets = 1, spreadDeg = 0.6, range = 120, fireInterval = 0.45, magazine = 12, reloadSeconds = 1.5, unlockRank = 1, zoom = 0, icon = "A" },
	flexblast = { id = "flexblast", name = "Flex Blast", style = "cone", damage = 34, pellets = 3, spreadDeg = 7, range = 45, fireInterval = 1.1, magazine = 6, reloadSeconds = 2.2, unlockRank = 2, zoom = 0, icon = "F" },
	sideeye = { id = "sideeye", name = "Side-Eye Sniper", style = "beam", damage = 68, pellets = 1, spreadDeg = 0.2, range = 220, fireInterval = 1.4, magazine = 4, reloadSeconds = 2.5, unlockRank = 3, zoom = 30, icon = "S" },
} :: { [string]: Weapon }

Weapons.combat = {
	health = 100, -- the Ego bar
	respawnSeconds = 2, -- after being reduced to NPC
	shieldSeconds = 2, -- no damage and no shooting right after spawning
	hitAura = 2, -- aura for every hit
	mogAura = 10, -- aura for mogging someone (aura means aura points)
	mogPoints = 5, -- Mog Points for mogging someone
	farmCooldownSeconds = 20, -- the same victim pays the same player only once in this time (no farming a friend or a bot)
	assistFraction = 0.5, -- an assist pays this fraction of a mog (so +5 aura)
	botRewardFactor = 0.5, -- mogging a bot pays half
	assistWindowSeconds = 8, -- damage within this long before a mog counts as an assist
	assistMinDamage = 10,
	defendBonusAura = 5, -- extra aura for a mog made while standing in a zone your faction holds
	comboWindowSeconds = 3, -- hits closer together than this build the combo (x2, x3, x4...)
	comboMax = 5, -- the combo multiplier on aura never passes this
	damageBonusCap = 0.10, -- rank damage bonus never goes past +10 percent
	damageBonusPerRank = 0.015,
	aimAssistDegrees = 6, -- mobile: how close to the crosshair an enemy must be to be nudged onto
	botSpreadDeg = 4, -- bots aim this much worse
	botFireIntervalMin = 0.7,
	botFireIntervalMax = 1.2,
	botRange = 60,
	botCoverHealth = 45, -- a bot below this ego looks for cover
	maxRequestsPerSecond = 12, -- fire requests above this are ignored
	streaks = { [2] = "DOUBLE MOG", [3] = "TRIPLE MOG", [5] = "MOG GOD STREAK" },
	-- Sound asset ids. Left empty on purpose: paste real ids once you have licensed sounds.
	sounds = { fire = "", hit = "", mog = "", combo = "" },
}

return Weapons
