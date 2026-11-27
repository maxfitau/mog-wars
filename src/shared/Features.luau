--!strict
-- Feature switches. Mog Wars is ONE sentence: "Run to a flag, stand on it to win it for your team, and your aura goes
-- up. Get the most aura to go from NPC to Mog God." So only the simple game is switched ON. Everything else is still
-- built, but switched OFF here, and every system, button and screen that belongs to it stays out of the game
-- while its flag is false. Flip a flag to true to bring a feature back. The server and the client both read this file.

local Features = {
	-- ON: the simple game
	war = true, -- the six territories, flags, capture, 6-minute wars, results screen
	shove = true, -- the only way to fight: a big button, BONK!
	ranks = true, -- NPC to Mog God, earned by total aura; only changes your glow, title and name colour
	dailyStreak = true, -- a daily aura reward with a 7-day streak
	cosmeticShop = true, -- aura colours, trails and titles for Robux
	bots = true, -- fills a war with bots when fewer than 8 real players are fighting
	speedPads = true, -- pads on the bridges between islands
	launchPads = true, -- pads that throw you from one island to the next
	ziplines = true, -- cables from the high islands down to the lower ones
	abilities = true, -- rank-unlocked buttons: Shove (NPC), Dash (Rookie), Mog Stare (Sigma)
	moglings = true, -- the fillers are called Moglings
	blockyMoglings = true, -- Moglings get a simple blocky body built from parts (no avatar download)
	stashes = true, -- the 12 hidden Aura Stashes

	-- OFF: built, but hidden to keep the game simple for little kids
	combat = false, -- aura blasters, ego, mogging, the kill feed, pickups' ammo
	mogOffs = false, -- tapping duels (the code stays; also see mogOffsInWar)
	mogOffsInWar = false,
	trainingIsland = false, -- Training Island, the TRAIN button and every training station (treadmill included)
	treadmill = false,
	trainingStations = false, -- Update 1
	boxes = false, -- loot boxes
	units = false, -- tanks and horses
	prestige = false, -- Update 2
	arena = false, -- Update 3
	dash = true, -- (a rank-unlocked ability now: Rookie)
	pickups = false,
	discoveryCards = false, -- screens appearing gradually as you play
	overtime = true, -- the last minute: all aura x2, the timer pulses
	territoryTrickle = false, -- the old once-a-minute trickle: replaced by +1 a second per territory held
	seasons = false,
	mogPoints = false, -- the old second currency: not shown, not awarded in pop-ups
	squadBonus = false,
	friendPlacement = false,
	barracks = false,
}

return table.freeze(Features)
