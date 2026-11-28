--!strict
-- THE WEAPON COLLECTION (pure data and rules, no Roblox calls). Nine launch weapons. An equipped weapon REPLACES Shove (the rank
-- abilities are unchanged). SAME POWER BUDGET for all: rarity changes only the look and sound (flashier visuals), never the power;
-- each weapon's cooldown is what balances it. Duplicates add stars 1 to 5: a slightly bigger effect (at most +20%) and a glowing
-- skin at 5 stars. Weapons are FREE ONLY: they come from the War Chest, gold supply drops, quest rewards, the weekly event and
-- achievements, and are never sold. Other systems read this file; nobody else defines a weapon.

export type Weapon = {
	id: string,
	name: string,
	rarity: string, -- "common" | "rare" | "epic" | "legendary" | "mythic"
	kind: string, -- how WeaponSystem uses it: hammer, gust, boomerang, rose, mist, mirror, shaker, mic, gauntlet
	cooldown: number, -- seconds between uses (the balance lever)
	blurb: string, -- one line for the index
	params: { [string]: number }, -- numbers the effect uses (see WeaponRules); stars scale the effect by `starScale`
	rgb: { number },
}

export type Rarity = { id: string, label: string, rgb: { number }, rank: number }

local WeaponCatalog = {}

WeaponCatalog.rarities = {
	{ id = "common", label = "Common", rgb = { 190, 190, 200 }, rank = 1 },
	{ id = "rare", label = "Rare", rgb = { 80, 170, 255 }, rank = 2 },
	{ id = "epic", label = "Epic", rgb = { 190, 100, 255 }, rank = 3 },
	{ id = "legendary", label = "Legendary", rgb = { 255, 190, 50 }, rank = 4 },
	{ id = "mythic", label = "Mythic", rgb = { 255, 80, 120 }, rank = 5 },
} :: { Rarity }

WeaponCatalog.weapons = {
	{ id = "jawline_hammer", name = "Jawline Hammer", rarity = "common", kind = "hammer", cooldown = 2.2, blurb = "Slow swing that shoves 2x as far", params = { range = 9, knock = 2 }, rgb = { 200, 150, 90 } },
	{ id = "mewing_fan", name = "Mewing Fan", rarity = "common", kind = "gust", cooldown = 3.0, blurb = "A wide gust cone that pushes everyone", params = { range = 16, angle = 100, knock = 1 }, rgb = { 150, 210, 255 } },
	{ id = "sigma_shades", name = "Sigma Shades", rarity = "rare", kind = "boomerang", cooldown = 5.0, blurb = "Boomerang sunglasses: hits on the way back", params = { range = 28, knock = 1 }, rgb = { 40, 40, 60 } },
	{ id = "rizz_rose", name = "Rizz Rose", rarity = "rare", kind = "rose", cooldown = 6.0, blurb = "Thrown: the target walks toward you for 1 second", params = { range = 30, seconds = 1 }, rgb = { 255, 80, 130 } },
	{ id = "glowup_mist", name = "Glow-Up Mist", rarity = "epic", kind = "mist", cooldown = 8.0, blurb = "A slippery sparkle puddle", params = { range = 14, radius = 9, seconds = 4 }, rgb = { 255, 170, 240 } },
	{ id = "mirror_shield", name = "Mirror Shield", rarity = "epic", kind = "mirror", cooldown = 6.0, blurb = "Hold to reflect shoves back", params = { seconds = 2.5 }, rgb = { 200, 235, 255 } },
	{ id = "protein_shaker", name = "Protein Shaker", rarity = "legendary", kind = "shaker", cooldown = 9.0, blurb = "Shockwave, and a speed boost for you", params = { radius = 14, knock = 1, boost = 0.4, seconds = 3 }, rgb = { 120, 230, 120 } },
	{ id = "main_character_mic", name = "Main Character Mic", rarity = "legendary", kind = "mic", cooldown = 12.0, blurb = "Nearby enemies freeze and stare for 1.5 s", params = { radius = 16, seconds = 1.5 }, rgb = { 255, 215, 80 } },
	{ id = "gigachad_gauntlet", name = "Gigachad Gauntlet", rarity = "mythic", kind = "gauntlet", cooldown = 10.0, blurb = "Charged giant punch with a huge knockback", params = { range = 14, knock = 3.2, charge = 0.9 }, rgb = { 255, 90, 90 } },
} :: { Weapon }

local byId: { [string]: Weapon } = {}
for _, weapon in WeaponCatalog.weapons do
	byId[weapon.id] = weapon
end
WeaponCatalog.byId = byId

local rarityById: { [string]: Rarity } = {}
for _, rarity in WeaponCatalog.rarities do
	rarityById[rarity.id] = rarity
end
WeaponCatalog.rarityById = rarityById

-- How much bigger the effect is at `stars` (1 to 5): +5 percent per extra star, so +20 percent at five stars at most.
function WeaponCatalog.starScale(stars: number): number
	return 1 + 0.05 * (math.clamp(math.floor(stars), 1, 5) - 1)
end

-- Five stars wear the glowing skin.
function WeaponCatalog.hasGlowSkin(stars: number): boolean
	return stars >= 5
end

-- DROP ODDS by source, as percentages that add up to 100. Shown in the chest UI. Gold drops and quests lean toward rarer weapons.
WeaponCatalog.odds = {
	chest = { common = 62, rare = 27, epic = 8, legendary = 2.5, mythic = 0.5 },
	gold_drop = { common = 30, rare = 38, epic = 22, legendary = 8, mythic = 2 },
	quest = { common = 55, rare = 33, epic = 9, legendary = 2.5, mythic = 0.5 },
	weekly = { common = 10, rare = 45, epic = 30, legendary = 12, mythic = 3 },
	achievement = { common = 40, rare = 40, epic = 15, legendary = 4, mythic = 1 },
	streak = { common = 0, rare = 100, epic = 0, legendary = 0, mythic = 0 }, -- day 7 of the login streak: a guaranteed Rare
	mogling = { common = 75, rare = 25, epic = 0, legendary = 0, mythic = 0 }, -- what Moglings carry
} :: { [string]: { [string]: number } }

-- Pick a rarity id from a source's odds with a random number from 0 up to 100 (pass math.random() * 100).
function WeaponCatalog.rarityFor(source: string, roll: number): string
	local table_ = WeaponCatalog.odds[source] or WeaponCatalog.odds.chest
	local running = 0
	local last = "common"
	for _, rarity in WeaponCatalog.rarities do
		local chance = table_[rarity.id] or 0
		if chance > 0 then
			last = rarity.id
			running += chance
			if roll < running then
				return rarity.id
			end
		end
	end
	return last
end

-- Roll a weapon for a source. `random` is any function returning a number from 0 up to 1 (math.random for the server).
function WeaponCatalog.roll(source: string, random: () -> number): Weapon
	local rarity = WeaponCatalog.rarityFor(source, random() * 100)
	local pool: { Weapon } = {}
	for _, weapon in WeaponCatalog.weapons do
		if weapon.rarity == rarity then
			table.insert(pool, weapon)
		end
	end
	if #pool == 0 then
		pool = WeaponCatalog.weapons
	end
	return pool[math.min(#pool, math.floor(random() * #pool) + 1)]
end

-- A "id:stars,id:stars" string of a collection (mirrored to the client as the "Collection" attribute).
function WeaponCatalog.encode(collection: { [string]: number }): string
	local parts: { string } = {}
	for _, weapon in WeaponCatalog.weapons do
		local stars = collection[weapon.id]
		if stars then
			table.insert(parts, ("%s:%d"):format(weapon.id, stars))
		end
	end
	return table.concat(parts, ",")
end

function WeaponCatalog.decode(text: string): { [string]: number }
	local result: { [string]: number } = {}
	for id, stars in string.gmatch(text, "([%w_]+):(%d)") do
		result[id] = tonumber(stars) :: number
	end
	return result
end

return WeaponCatalog
