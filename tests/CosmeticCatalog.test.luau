--!strict
-- Plain-Luau tests, no Roblox needed. Run from the repo root with the standalone Luau runtime:
--   luau tests/CosmeticCatalog.test.luau
-- STATUS: written but NOT yet run (no Luau runtime in the cloud session). Run it on a PC first.

local CosmeticCatalog = require("../src/shared/CosmeticCatalog")
local CosmeticRules = require("../src/shared/CosmeticRules")
local Config = require("../src/shared/EconomyConfig")

local failures = 0

local function check(name: string, condition: boolean)
	if condition then
		print("PASS " .. name)
	else
		failures += 1
		print("FAIL " .. name)
	end
end

-- design rule 1: items only ever have cosmetic fields
local allowed = { id = true, name = true, slot = true, source = true, productId = true, rgb = true, text = true }
local cosmeticOnly = true
for _, item in CosmeticCatalog.items do
	for key in item :: any do
		if not allowed[key] then
			cosmeticOnly = false
			print("unexpected field on " .. item.id .. ": " .. tostring(key))
		end
	end
end
check("no item has a gameplay field", cosmeticOnly)

-- every cosmetic a box can drop exists and is box-only
local boxIds: { [string]: boolean } = {}
for _, tier in Config.boxes.tiers do
	for _, drop in tier.drops do
		if drop.kind == "cosmetic" and drop.cosmetic then
			boxIds[drop.cosmetic] = true
		end
	end
end
local boxesCovered = true
for id in boxIds do
	local item = CosmeticCatalog.byId[id]
	if not item or item.source ~= "box" then
		boxesCovered = false
		print("box drop not in the catalog as box-only: " .. id)
	end
end
check("every box cosmetic is in the catalog as box-only", boxesCovered)
local noOrphans = true
for _, item in CosmeticCatalog.items do
	if item.source == "box" and not boxIds[item.id] then
		noOrphans = false
	end
end
check("every box-only cosmetic can actually drop", noOrphans)

-- items are well formed
local formed = true
for _, item in CosmeticCatalog.items do
	if item.slot == "title" then
		if not item.text or item.text == "" or #(item.text :: string) > 24 then
			formed = false
		end
	else
		local rgb = item.rgb
		if not rgb or #rgb ~= 3 then
			formed = false
		else
			for _, channel in rgb do
				if channel < 0 or channel > 255 then
					formed = false
				end
			end
		end
	end
end
check("trails and auras have colours, titles have short fixed text", formed)

local shopItems = 0
for _, item in CosmeticCatalog.items do
	if item.source == "shop" then
		shopItems += 1
	end
end
check("the shop has items", shopItems >= 5)
check("the season champion title exists and is not sold", CosmeticCatalog.byId.title_season_champion ~= nil and (CosmeticCatalog.byId.title_season_champion :: any).source == "season" and (CosmeticCatalog.byId.title_season_champion :: any).productId == 0)

-- equipping
local function newData(): CosmeticRules.Data
	return { cosmetics = { trail_spark = true }, equipped = {}, receipts = {} }
end
local catalog = CosmeticCatalog :: any
do
	local data = newData()
	check("an owned trail can be equipped", CosmeticRules.canEquip(data, catalog, "trail", "trail_spark"))
	local ok, reason = CosmeticRules.canEquip(data, catalog, "aura", "trail_spark")
	check("an item cannot go in the wrong slot", not ok and reason == "wrong_slot")
	ok, reason = CosmeticRules.canEquip(data, catalog, "aura", "aura_gold")
	check("an unowned item cannot be equipped", not ok and reason == "not_owned")
	ok, reason = CosmeticRules.canEquip(data, catalog, "aura", "aura_nothing")
	check("an unknown item is refused", not ok and reason == "unknown_item")
	ok, reason = CosmeticRules.canEquip(data, catalog, "cape", "trail_spark")
	check("an unknown slot is refused", not ok and reason == "unknown_slot")
	ok, reason = CosmeticRules.canEquip(data, catalog, 5, "trail_spark")
	check("a non-string slot is refused", not ok and reason == "bad_input")
	check("taking something off is always allowed", CosmeticRules.canEquip(data, catalog, "trail", ""))
end
do
	local data = newData()
	data.equipped = { trail = "trail_spark", aura = "aura_gold", cape = "x" }
	local removed = CosmeticRules.cleanEquipped(data, catalog)
	check("cleaning removes what is not owned or valid", removed == 2 and data.equipped.trail == "trail_spark" and data.equipped.aura == nil and data.equipped.cape == nil)
end

-- purchases
local shopId = "trail_neon_blue"
do
	local data = newData()
	check("a purchase grants the item", CosmeticRules.applyPurchase(data, catalog, shopId, "p1", 100) == "granted" and data.cosmetics[shopId] == true)
	check("the same purchase id never grants twice", CosmeticRules.applyPurchase(data, catalog, shopId, "p1", 101) == "duplicate")
	check("a second purchase of an owned item records a receipt and gives nothing more", CosmeticRules.applyPurchase(data, catalog, shopId, "p2", 102) == "already_owned" and data.receipts.p2 == 102)
end
do
	local data = newData()
	check("a box cosmetic cannot be bought", CosmeticRules.applyPurchase(data, catalog, "trail_spark", "p1", 1) == "invalid_item" and next(data.receipts) == nil)
	check("an unknown item is refused and nothing changes", CosmeticRules.applyPurchase(data, catalog, "nope", "p1", 1) == "invalid_item" and next(data.receipts) == nil)
	check("a bad purchase id is refused", CosmeticRules.applyPurchase(data, catalog, shopId, "", 1) == "invalid_receipt")
	check("a non-string purchase id is refused", CosmeticRules.applyPurchase(data, catalog, shopId, 5, 1) == "invalid_receipt")
	check("a too-long purchase id is refused", CosmeticRules.applyPurchase(data, catalog, shopId, string.rep("x", 101), 1) == "invalid_receipt")
end
do
	local data = newData()
	for index = 1, CosmeticRules.MAX_RECEIPTS + 20 do
		CosmeticRules.applyPurchase(data, catalog, shopId, "r" .. index, index)
	end
	local count = 0
	for _ in data.receipts do
		count += 1
	end
	check("old receipts are pruned to the limit", count == CosmeticRules.MAX_RECEIPTS)
end

if failures > 0 then
	error(failures .. " test(s) failed")
end
print("All tests passed")
