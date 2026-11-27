--!strict
-- Pure cosmetic rules: who can equip what, and turning one Robux purchase into one owned cosmetic, exactly
-- once. No Roblox calls, so it can be tested anywhere. A purchase id that was already applied returns
-- "duplicate" and changes nothing, so a retried receipt can never grant twice.

export type Data = {
	cosmetics: { [string]: boolean },
	equipped: { [string]: string },
	receipts: { [string]: number },
}

export type Catalog = {
	byId: { [string]: { id: string, slot: string, source: string } },
	isSlot: { [string]: boolean },
}

local CosmeticRules = {}

CosmeticRules.MAX_RECEIPTS = 200 -- newest purchase ids kept in the save
local MAX_ID_LENGTH = 100

-- Can this player equip `id` in `slot`? An empty id means "take it off", which is always allowed for a real
-- slot. Returns ok and a stable reason ("bad_input", "unknown_slot", "unknown_item", "wrong_slot", "not_owned").
function CosmeticRules.canEquip(data: Data, catalog: Catalog, slot: any, id: any): (boolean, string?)
	if type(slot) ~= "string" or type(id) ~= "string" then
		return false, "bad_input"
	end
	if not catalog.isSlot[slot] then
		return false, "unknown_slot"
	end
	if id == "" then
		return true, nil
	end
	local item = catalog.byId[id]
	if not item then
		return false, "unknown_item"
	end
	if item.slot ~= slot then
		return false, "wrong_slot"
	end
	if not data.cosmetics[id] then
		return false, "not_owned"
	end
	return true, nil
end

-- Remove anything equipped that the player does not own or that is no longer valid (after a catalog change).
-- Returns how many entries were removed.
function CosmeticRules.cleanEquipped(data: Data, catalog: Catalog): number
	local removed = 0
	for slot, id in data.equipped do
		local ok = CosmeticRules.canEquip(data, catalog, slot, id)
		if not ok or id == "" then
			data.equipped[slot] = nil
			removed += 1
		end
	end
	return removed
end

local function pruneReceipts(receipts: { [string]: number }, keep: number)
	local entries = {}
	for id, stamp in receipts do
		table.insert(entries, { id = id, stamp = stamp })
	end
	local excess = #entries - keep
	if excess <= 0 then
		return
	end
	table.sort(entries, function(a, b)
		if a.stamp ~= b.stamp then
			return a.stamp < b.stamp
		end
		return a.id < b.id
	end)
	for index = 1, excess do
		receipts[entries[index].id] = nil
	end
end

-- Apply one shop purchase. Everything is checked first; only then is anything changed.
-- Returns "granted", "already_owned" (paid but the player already had it: the receipt is still recorded and
-- nothing else is given), "duplicate" (this purchase id was applied before), "invalid_receipt" or "invalid_item".
function CosmeticRules.applyPurchase(data: Data, catalog: Catalog, itemId: any, purchaseId: any, now: number): string
	if type(purchaseId) ~= "string" or purchaseId == "" or #purchaseId > MAX_ID_LENGTH then
		return "invalid_receipt"
	end
	if type(itemId) ~= "string" then
		return "invalid_item"
	end
	local item = catalog.byId[itemId]
	if not item or item.source ~= "shop" then
		return "invalid_item" -- box and season cosmetics are never sold
	end
	if data.receipts[purchaseId] ~= nil then
		return "duplicate"
	end
	data.receipts[purchaseId] = now
	pruneReceipts(data.receipts, CosmeticRules.MAX_RECEIPTS)
	if data.cosmetics[itemId] then
		return "already_owned"
	end
	data.cosmetics[itemId] = true
	return "granted"
end

return CosmeticRules
