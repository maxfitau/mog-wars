--!strict
-- Every cosmetic in the game. Cosmetics change how a player LOOKS and nothing else: no points, no boxes, no
-- units, no capture speed, no aura power, no training speed. That is design rule 1 (not pay-to-win), and
-- tests/CosmeticCatalog.test.luau fails if an item ever gains a gameplay field.
--
-- source "box"  = found in boxes only (the ids box drops use, see EconomyConfig); never sold.
-- source "season" = awarded for winning a weekly faction season; never sold.
-- source "shop" = sold for Robux as a developer product. productId 0 means "not set up yet": create the
--                 product on the Creator Dashboard, then paste its id here. Unset items show "Not on sale yet".
-- slot: "trail" (behind you), "aura" (around you) or "title" (small text above your head).
-- Titles are fixed words chosen here, never free text from players.
--
-- Ideas from DESIGN.md that need art before they can be added: faction banners, victory emotes, unit skins,
-- box-opening animations.

export type Item = {
	id: string, -- stable name used in saves. Never rename once shipped.
	name: string,
	slot: string,
	source: string,
	productId: number,
	rgb: { number }?, -- trails and auras: red, green, blue 0 to 255
	text: string?, -- titles: the words shown
}

local CosmeticCatalog = {}

CosmeticCatalog.slots = { "trail", "aura", "title" }

CosmeticCatalog.items = {
	-- found in boxes
	{ id = "trail_spark", name = "Spark Trail", slot = "trail", source = "box", productId = 0, rgb = { 255, 235, 150 } },
	{ id = "aura_frost", name = "Frost Aura", slot = "aura", source = "box", productId = 0, rgb = { 150, 220, 255 } },
	{ id = "aura_gold", name = "Gold Aura", slot = "aura", source = "box", productId = 0, rgb = { 255, 205, 60 } },
	-- awarded by weekly seasons
	{ id = "title_season_champion", name = "Title: Season Champion", slot = "title", source = "season", productId = 0, text = "Season Champion" },
	-- sold in the shop
	{ id = "trail_neon_blue", name = "Neon Blue Trail", slot = "trail", source = "shop", productId = 0, rgb = { 60, 140, 255 } },
	{ id = "trail_neon_pink", name = "Neon Pink Trail", slot = "trail", source = "shop", productId = 0, rgb = { 255, 90, 190 } },
	{ id = "aura_ember", name = "Ember Aura", slot = "aura", source = "shop", productId = 0, rgb = { 255, 120, 40 } },
	{ id = "aura_violet", name = "Violet Aura", slot = "aura", source = "shop", productId = 0, rgb = { 170, 110, 255 } },
	{ id = "title_zone_hopper", name = "Title: Zone Hopper", slot = "title", source = "shop", productId = 0, text = "Zone Hopper" },
	{ id = "title_aura_farmer", name = "Title: Aura Farmer", slot = "title", source = "shop", productId = 0, text = "Aura Farmer" },
	{ id = "title_tap_master", name = "Title: Tap Master", slot = "title", source = "shop", productId = 0, text = "Tap Master" },
} :: { Item }

local byId: { [string]: Item } = {}
local byProductId: { [number]: Item } = {}
local slotSet: { [string]: boolean } = {}
for _, slot in CosmeticCatalog.slots do
	slotSet[slot] = true
end
for _, item in CosmeticCatalog.items do
	assert(byId[item.id] == nil, "duplicate cosmetic id: " .. item.id)
	assert(slotSet[item.slot], "bad slot for " .. item.id)
	assert(item.source == "box" or item.source == "shop" or item.source == "season", "bad source for " .. item.id)
	assert(item.productId >= 0 and item.productId == math.floor(item.productId), "bad product id for " .. item.id)
	byId[item.id] = item
	if item.productId ~= 0 then
		assert(byProductId[item.productId] == nil, "duplicate product id for " .. item.id)
		byProductId[item.productId] = item
	end
end

CosmeticCatalog.byId = byId
CosmeticCatalog.byProductId = byProductId
CosmeticCatalog.isSlot = slotSet

return CosmeticCatalog
