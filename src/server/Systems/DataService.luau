--!strict
-- Loads each player's save when they join and releases it when they leave. Server only.
-- Other systems use DataService.get(player) and the helpers below; the client never sees the table.
-- The player's points are mirrored to a "Points" attribute so the HUD can display them (read only).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileStore = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("ProfileStore"))
local RankRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RankRules"))
local BoxRoll = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BoxRoll"))
local PlayerData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PlayerData"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("EconomyConfig"))

local store = nil :: ProfileStore.Store?
local profiles: { [Player]: ProfileStore.Profile } = {}

local DataService = {}

-- Mirror the player's box and unit counts to attributes so the client can display them (read only).
local function syncInventory(player: Player, data: PlayerData.Data)
	for tierId in Config.boxes.tiers do
		player:SetAttribute("Boxes_" .. tierId, data.boxes[tierId] or 0)
	end
	for unitId in Config.units do
		player:SetAttribute("Units_" .. unitId, data.units[unitId] or 0)
	end
end

local function load(player: Player)
	if profiles[player] or not store then
		return
	end
	local profile = store:StartSessionAsync(tostring(player.UserId), {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if not profile then
		player:Kick("Could not load your data. Please rejoin.")
		return
	end
	profile:AddUserId(player.UserId)
	profile:Reconcile()
	PlayerData.migrate(profile.Data)
	if not PlayerData.isValid(profile.Data) then
		-- Never run with data we cannot trust.
		profile:EndSession()
		player:Kick("Your data could not be read. Please rejoin or contact support.")
		return
	end
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		player:Kick("Your data was loaded somewhere else. Please rejoin.")
	end)
	if player.Parent ~= Players then
		profile:EndSession() -- the player left while loading
		return
	end
	profiles[player] = profile
	player:SetAttribute("Points", profile.Data.points)
	player:SetAttribute("Rank", profile.Data.rank)
	syncInventory(player, profile.Data :: any)
end

-- The live save table for a player, or nil while loading or after they leave.
function DataService.get(player: Player): PlayerData.Data?
	local profile = profiles[player]
	return if profile then (profile.Data :: any) else nil
end

-- Server-only: add points, keep the attribute in sync. Returns true if points were added.
function DataService.addPoints(player: Player, amount: number): boolean
	local data = DataService.get(player)
	if not data or not PlayerData.addPoints(data, amount) then
		return false
	end
	player:SetAttribute("Points", data.points)
	return true
end

-- Server-only: spend points all or nothing. Returns true if the player could afford it.
function DataService.spendPoints(player: Player, amount: number): boolean
	local data = DataService.get(player)
	if not data or not PlayerData.spendPoints(data, amount) then
		return false
	end
	player:SetAttribute("Points", data.points)
	return true
end

-- 1 for full rewards, or the reduced multiplier after the daily full-reward wars. 1 if data is not loaded.
function DataService.rewardMultiplier(player: Player): number
	local data = DataService.get(player)
	if not data then
		return 1
	end
	return PlayerData.rewardMultiplier(
		data,
		PlayerData.dayNumber(os.time()),
		Config.war.fullRewardWarsPerDay,
		Config.war.reducedRewardMultiplier
	)
end

-- Count a finished war for this player today.
function DataService.recordWar(player: Player)
	local data = DataService.get(player)
	if data then
		PlayerData.recordWar(data, PlayerData.dayNumber(os.time()))
	end
end

-- Server-only rank-up. All or nothing: points, rank and the reward box change together in one step
-- with no yielding, or nothing changes. Returns ok and a stable reason string when it fails.
function DataService.tryRankUp(player: Player): (boolean, string?)
	local data = DataService.get(player)
	if not data then
		return false, "not_loaded"
	end
	local result = RankRules.tryRankUp(Config, data.rank, data.points)
	if not result.ok then
		return false, result.reason
	end
	if result.rewardBox ~= "" and not PlayerData.addBox(data, result.rewardBox) then
		return false, "boxes_full" -- nothing was changed yet, so the player keeps their points
	end
	data.points = result.points
	data.rank = result.rank
	player:SetAttribute("Points", data.points)
	player:SetAttribute("Rank", data.rank)
	syncInventory(player, data)
	return true, nil
end

-- Earn a box from a war (counts toward the daily cap). Returns true if the box was added.
function DataService.earnBox(player: Player, tier: string): boolean
	local data = DataService.get(player)
	if not data or Config.boxes.tiers[tier] == nil then
		return false
	end
	local day = PlayerData.dayNumber(os.time())
	if not PlayerData.tryEarnBox(data, day, Config.war.dailyBoxCap, tier) then
		return false
	end
	syncInventory(player, data)
	return true
end

export type BoxResult = {
	ok: boolean,
	reason: string, -- stable reason when not ok, "" otherwise
	tier: string,
	kind: string, -- "points", "unit" or "cosmetic" (what was actually granted)
	id: string, -- unit id or cosmetic id, "" for points
	amount: number, -- points granted (also for duplicate and full-stack compensation), else 0
}

local function failed(reason: string): BoxResult
	return { ok = false, reason = reason, tier = "", kind = "", id = "", amount = 0 }
end

-- Open one box. Everything is checked first; then the box is taken and the reward granted in one step with
-- no yielding. `random` returns a number in [0, 1) and is injected so the roll can be tested.
function DataService.openBox(player: Player, tierId: any, random: () -> number): BoxResult
	local data = DataService.get(player)
	if not data then
		return failed("not_loaded")
	end
	if type(tierId) ~= "string" then
		return failed("bad_input")
	end
	local tier = Config.boxes.tiers[tierId]
	if not tier then
		return failed("unknown_tier")
	end
	if (data.boxes[tierId] or 0) < 1 then
		return failed("no_box")
	end

	local drop = BoxRoll.roll(tier, random)
	PlayerData.takeBox(data, tierId)

	local result: BoxResult = { ok = true, reason = "", tier = tierId, kind = drop.kind, id = "", amount = 0 }
	if drop.kind == "points" then
		result.amount = drop.amount or 0
	elseif drop.kind == "unit" and drop.unit then
		if PlayerData.addUnit(data, drop.unit) then
			result.id = drop.unit
		else -- stack full: pay the sell value instead
			local unitConfig = (Config.units :: any)[drop.unit]
			result.kind, result.amount = "points", if unitConfig then unitConfig.sellValue else 0
		end
	elseif drop.kind == "cosmetic" and drop.cosmetic then
		if PlayerData.addCosmetic(data, drop.cosmetic) then
			result.id = drop.cosmetic
		else -- already owned: pay a consolation instead
			result.kind, result.amount = "points", Config.boxes.duplicateCosmeticPoints
		end
	end
	if result.amount > 0 then
		PlayerData.addPoints(data, result.amount)
		player:SetAttribute("Points", data.points)
	end
	syncInventory(player, data)
	return result
end

function DataService.init()
	store = ProfileStore.New("MogWarsPlayerData", PlayerData.template() :: any)
	Players.PlayerAdded:Connect(function(player)
		task.spawn(load, player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		local profile = profiles[player]
		if profile then
			profiles[player] = nil
			profile:EndSession()
		end
	end)
end

function DataService.start()
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
end

return DataService
