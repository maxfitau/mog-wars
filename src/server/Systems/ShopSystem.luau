--!strict
-- The cosmetic shop. Server only.
--  * Purchases: players buy cosmetics as developer products with Robux. The client only OPENS the Roblox
--    purchase prompt; it can never grant anything. Roblox calls ProcessReceipt, and this file is the ONLY place
--    that sets it (a second assignment would silently replace it). Every purchase is applied to the save
--    exactly once (CosmeticRules.applyPurchase) and the answer is PurchaseGranted only after it is recorded.
--  * Equipping: "EquipCosmeticRequest" carries a slot and an id; both are validated against the fixed catalog
--    and the player's own save, then the look is drawn on their character for everyone.
--  * Nothing sold here changes power, points, ranks, units, boxes, capture speed, aura or training (rule 1).
-- Replies go to the client as "ShopResult" (ok, reason, action, id).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CosmeticCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CosmeticCatalog"))
local CosmeticVisuals = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("CosmeticVisuals"))
local DataService = require(script.Parent:WaitForChild("DataService"))

local WAIT_FOR_DATA_SECONDS = 10
local MIN_INTERVAL = 0.3 -- seconds between equip requests from one player

local ShopSystem = {}

local lastRequest: { [Player]: number } = {}
local resultRemote: RemoteEvent? = nil

local function send(player: Player, ok: boolean, reason: string, action: string, id: string)
	if resultRemote then
		resultRemote:FireClient(player, ok, reason, action, id)
	end
end

-- Draw a player's cosmetics whenever their character loads or an equipped slot changes (this also covers the
-- moment their save finishes loading, which can be after the character appears).
local function watch(player: Player)
	player.CharacterAdded:Connect(function()
		task.defer(CosmeticVisuals.refreshAll, player)
	end)
	for _, slot in CosmeticCatalog.slots do
		player:GetAttributeChangedSignal("Equip_" .. slot):Connect(function()
			CosmeticVisuals.refreshAll(player)
		end)
	end
end

local function process(receiptInfo: any): Enum.ProductPurchaseDecision
	local notYet = Enum.ProductPurchaseDecision.NotProcessedYet

	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if player == nil then
		return notYet -- they left; Roblox asks again when they rejoin
	end
	local item = CosmeticCatalog.byProductId[receiptInfo.ProductId]
	if item == nil then
		warn(`[ShopSystem] unknown product id {receiptInfo.ProductId}: not granting`)
		return notYet
	end
	if DataService.waitFor(player, WAIT_FOR_DATA_SECONDS) == nil then
		return notYet
	end

	-- No yielding from here to the return, so the save cannot change in between.
	local result = DataService.applyCosmeticPurchase(player, item.id, tostring(receiptInfo.PurchaseId))
	if result == "granted" or result == "already_owned" or result == "duplicate" then
		if result ~= "duplicate" then
			send(player, true, if result == "already_owned" then "already_owned" else "", "purchase", item.id)
		end
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	warn(`[ShopSystem] could not apply purchase for {item.id}: {result}`)
	return notYet
end

local function processReceipt(receiptInfo: any): Enum.ProductPurchaseDecision
	local ok, decision = pcall(process, receiptInfo)
	if ok then
		return decision
	end
	warn("[ShopSystem] error while processing a receipt: " .. tostring(decision))
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

function ShopSystem.init()
	MarketplaceService.ProcessReceipt = processReceipt

	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	local equip = Instance.new("RemoteEvent")
	equip.Name = "EquipCosmeticRequest"
	equip.Parent = folder
	local result = Instance.new("RemoteEvent")
	result.Name = "ShopResult"
	result.Parent = folder
	resultRemote = result

	equip.OnServerEvent:Connect(function(player: Player, slot: any, id: any)
		local now = Workspace:GetServerTimeNow()
		if now - (lastRequest[player] or -1000) < MIN_INTERVAL then
			return
		end
		lastRequest[player] = now
		local ok, reason = DataService.equipCosmetic(player, slot, id) -- the look redraws when Equip_<slot> changes
		send(player, ok, reason, "equip", if type(id) == "string" then id else "")
	end)

	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

function ShopSystem.start()
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return ShopSystem
