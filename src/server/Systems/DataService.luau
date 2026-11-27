--!strict
-- Loads each player's save when they join and releases it when they leave. Server only.
-- Other systems use DataService.get(player) and the helpers below; the client never sees the table.
-- The player's points are mirrored to a "Points" attribute so the HUD can display them (read only).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ProfileStore = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("ProfileStore"))
local Levels = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Levels"))
local RankRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RankRules"))
local BoxRoll = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BoxRoll"))
local BarracksRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BarracksRules"))
local StreakRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StreakRules"))
local TrainingRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TrainingRules"))
local CosmeticCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CosmeticCatalog"))
local CosmeticRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CosmeticRules"))
local SeasonRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SeasonRules"))
local Features = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Features"))
local RevealRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RevealRules"))
local PlayerData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PlayerData"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("EconomyConfig"))
local Pace = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Pace"))

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

-- Mirror the daily-claim and barracks state to attributes for the client to display (read only):
-- DailyReady (bool), DailyDay (the streak day the next claim would be), BarracksPending (points waiting).
local function syncRewards(player: Player, data: PlayerData.Data)
	local now = os.time()
	local ready, day = StreakRules.preview(data.streakDay, data.lastClaimDay, PlayerData.dayNumber(now), #Config.dailyStreak.rewards)
	player:SetAttribute("DailyReady", ready)
	player:SetAttribute("DailyDay", day)
	player:SetAttribute("BarracksPending", if Features.barracks then BarracksRules.pending(now, data.barracksSince, data.rank, Config.barracks) else 0)
end

-- Mirror the Training Arena state to attributes for the client and for CaptureSystem (read only):
-- TrainingLevel, TrainingProgress (0 to 1 into the current level) and TrainingLeft (seconds left today).
local STASH_TOTAL = 12
local UNLOCK_IDS = { shove = true, dash = true, stare = true, slam = true, flip = true, shield = true, total = true }

local function syncUnlocks(player: Player, data: PlayerData.Data)
	local seen = {}
	for id in data.unlocksSeen do
		table.insert(seen, id)
	end
	table.sort(seen)
	player:SetAttribute("UnlocksSeen", table.concat(seen, ","))
	local found = 0
	for _ in data.stashes do
		found += 1
	end
	player:SetAttribute("StashesFound", found)
	player:SetAttribute("StashesTotal", STASH_TOTAL)
	player:SetAttribute("StashHunter", found >= STASH_TOTAL)
	player:SetAttribute("Title", data.title)
end

local function syncTraining(player: Player, data: PlayerData.Data)
	local settings = Config.training
	local day = PlayerData.dayNumber(os.time())
	local trainedToday = if data.trainingDay == day then data.trainingToday else 0
	player:SetAttribute("TrainingLevel", data.trainingLevel)
	local cost = TrainingRules.levelCost(data.trainingLevel, settings)
	player:SetAttribute("TrainingProgress", if data.trainingLevel >= settings.maxLevel then 1 else data.trainingProgress / cost)
	player:SetAttribute("TrainingLeft", math.max(0, settings.dailyStrideCap - trainedToday))
end

-- Mirror owned and equipped cosmetics to attributes (read only for the client): "Cosmetics" is the owned ids
-- joined with commas, and "Equip_<slot>" is the id worn in that slot ("" for none).
local function syncCosmetics(player: Player, data: PlayerData.Data)
	local owned = {}
	for id in data.cosmetics do
		table.insert(owned, id)
	end
	table.sort(owned)
	player:SetAttribute("Cosmetics", table.concat(owned, ","))
	for _, slot in CosmeticCatalog.slots do
		player:SetAttribute("Equip_" .. slot, data.equipped[slot] or "")
	end
end

-- Mirror this week's season points (all factions together) to the "SeasonPoints" attribute.
local function syncSeason(player: Player, data: PlayerData.Data)
	player:SetAttribute("SeasonPoints", SeasonRules.total(data.season.points))
end

-- Mirror how much of the game this player should see yet to the "RevealStage" attribute (read only for the client).
local function syncReveal(player: Player, data: PlayerData.Data)
	player:SetAttribute("RevealStage", RevealRules.stage(data.lifetimeCaptures, data.lifetimeWars))
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
	if type(profile.Data.trainingLevel) == "number" and profile.Data.trainingLevel > Config.training.maxLevel then
		profile.Data.trainingLevel = Config.training.maxLevel -- a save from before the level cap changed
		profile.Data.trainingProgress = 0
	end
	if type(profile.Data.rank) == "number" and profile.Data.rank > #Config.ranks then
		profile.Data.rank = #Config.ranks -- a save from before the rank list changed
	end
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
	-- a rank already earned is kept; total aura can only raise it
	profile.Data.rank = math.max(profile.Data.rank, Levels.rankOfLevel(Levels.levelForAura(profile.Data.aura)))
	player:SetAttribute("Rank", profile.Data.rank)
	player:SetAttribute("Level", Levels.levelForAura(profile.Data.aura))
	player:SetAttribute("Aura", profile.Data.aura)
	syncUnlocks(player, profile.Data :: any)
	syncInventory(player, profile.Data :: any)
	if profile.Data.barracksSince == 0 then
		profile.Data.barracksSince = os.time() -- the barracks starts building from the first visit
	end
	syncRewards(player, profile.Data :: any)
	SeasonRules.roll(profile.Data.season :: any, SeasonRules.weekIndex(os.time())) -- a new week starts fresh
	CosmeticRules.cleanEquipped(profile.Data :: any, CosmeticCatalog :: any) -- drop anything not owned or no longer valid
	syncTraining(player, profile.Data :: any)
	syncCosmetics(player, profile.Data :: any)
	syncSeason(player, profile.Data :: any)
	syncReveal(player, profile.Data :: any)
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
		data.lifetimeWars += 1
		syncReveal(player, data)
	end
end

-- Server-only rank-up. All or nothing: points and rank change together in one step with no yielding,
-- or nothing changes. Returns ok and a stable reason string when it fails.
function DataService.tryRankUp(player: Player): (boolean, string?)
	local data = DataService.get(player)
	if not data then
		return false, "not_loaded"
	end
	local result = RankRules.tryRankUp(Config, data.rank, data.points)
	if not result.ok then
		return false, result.reason
	end
	data.points = result.points
	data.rank = result.rank
	player:SetAttribute("Points", data.points)
	player:SetAttribute("Rank", data.rank)
	syncInventory(player, data)
	return true, nil
end

-- Earn a box from a capture (counts toward the daily cap). Returns true if the box was added.
function DataService.earnBox(player: Player, tier: string): boolean
	local data = DataService.get(player)
	if not data or Config.boxes.tiers[tier] == nil then
		return false
	end
	local day = PlayerData.dayNumber(os.time())
	if not PlayerData.tryEarnBox(data, day, Config.boxes.dailyCap, tier) then
		return false
	end
	syncInventory(player, data)
	return true
end

-- Use up one unit when it is deployed. Returns true if the player had one.
function DataService.takeUnit(player: Player, unit: string): boolean
	local data = DataService.get(player)
	if not data or not PlayerData.takeUnit(data, unit) then
		return false
	end
	syncInventory(player, data)
	return true
end

-- How many of a unit the player owns (0 if not loaded).
function DataService.unitCount(player: Player, unit: string): number
	local data = DataService.get(player)
	return if data then (data.units[unit] or 0) else 0
end

-- Sell one unit for its Mog Points value. All or nothing, no yielding. Returns ok, reason, points paid.
function DataService.sellUnit(player: Player, unitId: any): (boolean, string, number)
	local data = DataService.get(player)
	if not data then
		return false, "not_loaded", 0
	end
	if type(unitId) ~= "string" then
		return false, "bad_input", 0
	end
	local unitConfig = (Config.units :: any)[unitId]
	if not unitConfig then
		return false, "unknown_unit", 0
	end
	if (data.units[unitId] or 0) < 1 then
		return false, "no_unit", 0
	end
	PlayerData.takeUnit(data, unitId)
	PlayerData.addPoints(data, unitConfig.sellValue)
	player:SetAttribute("Points", data.points)
	syncInventory(player, data)
	return true, "", unitConfig.sellValue
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
	elseif drop.kind == "weapon" and drop.weapon then
		if PlayerData.unlockWeapon(data, drop.weapon) then
			result.id = drop.weapon
		else -- already unlocked: pay a consolation instead
			result.kind, result.amount = "points", Config.boxes.duplicateCosmeticPoints
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
	syncCosmetics(player, data)
	return result
end

-- Count one stride of treadmill running. All or nothing, no yielding. Returns ok, a stable reason
-- ("daily_cap", "max_level", "not_loaded") and whether a level was gained.
function DataService.addTrainingStride(player: Player): (boolean, string, boolean)
	local data = DataService.get(player)
	if not data then
		return false, "not_loaded", false
	end
	local settings = Config.training
	if data.trainingLevel >= settings.maxLevel then
		return false, "max_level", false
	end
	local day = PlayerData.dayNumber(os.time())
	if data.trainingDay ~= day then
		data.trainingDay = day
		data.trainingToday = 0
	end
	local allowed = TrainingRules.allowedStrides(data.trainingToday, 1, settings)
	if allowed < 1 then
		syncTraining(player, data)
		return false, "daily_cap", false
	end
	local level, progress, gained = TrainingRules.addStrides(data.trainingLevel, data.trainingProgress, allowed, settings)
	data.trainingLevel = level
	data.trainingProgress = progress
	data.trainingToday += allowed
	syncTraining(player, data)
	return true, "", gained > 0
end

-- Add aura points (10 aura = one second on a treadmill). Used for territory rewards and the aura trickle: it
-- goes straight into the player's aura level and is NOT limited by the daily treadmill time. Returns the aura
-- actually added (0 if the player is already at the top aura level or data is not loaded).
-- The multiplier on every aura gain right now: overtime (all aura x2) and Main Character Mode (x2 for a while).
function DataService.auraMultiplier(player: Player): number
	local multiplier = 1
	if Workspace:GetAttribute("Overtime") == true then
		multiplier *= Pace.overtime.auraMultiplier
	end
	local until_ = player:GetAttribute("MainCharacterUntil")
	if type(until_) == "number" and until_ > Workspace:GetServerTimeNow() then
		multiplier *= Pace.pickups.mainCharacterAuraMultiplier
	end
	return multiplier
end

-- Small treadmill-only remainder (only used when Training Island is switched on).
local auraRemainder: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any

-- Add aura. Aura is your score: it only goes up, and your rank (NPC to Mog God) comes from the total. Used for captures,
-- the +1 ticks, the territory bonus and trickle, and the daily reward. Overtime and Main Character Mode (both off in
-- the simple game) can multiply it. Returns the aura shown to the player (after any multiplier), or 0 if data is not
-- loaded. A new rank is announced with a "rankup" pop-up.
function DataService.addAura(player: Player, aura: number, alreadyScaled: boolean?): number
	local data = DataService.get(player)
	if not data or aura ~= aura or aura <= 0 or aura == math.huge then
		return 0
	end
	-- BIG NUMBERS: every level multiplies all income (Levels.multiplier), so every reward is "N seconds of current income".
	-- Values that already come from the war tally (stolen orbs, bounty) pass alreadyScaled=true so they are not scaled twice.
	local levelMultiplier = if alreadyScaled then 1 else Levels.multiplier(player:GetAttribute("Level") :: any or 0)
	local base = math.floor(aura * DataService.auraMultiplier(player) * levelMultiplier + 0.5)
	local shown = base
	-- combo (captures, shoves, orbs and stashes close together) and crits (MEGA MOG! x5, ULTRA MOG! x10) multiply the gain
	local comboValue = player:GetAttribute("ComboMult")
	local multiplier = if type(comboValue) == "number" and comboValue > 1 then comboValue else 1
	local critTier: string? = nil
	if base >= Pace.crit.minAura then
		local roll = math.random()
		if roll < Pace.crit.ultraChance then
			critTier = "ultra"
			multiplier *= Pace.crit.ultraMultiplier
		elseif roll < Pace.crit.ultraChance + Pace.crit.megaChance then
			critTier = "mega"
			multiplier *= Pace.crit.megaMultiplier
		end
	end
	multiplier = math.min(multiplier, Pace.combo.maxTotalMultiplier)
	shown = math.floor(base * multiplier + 0.5)
	if shown > base then
		local bonus = player:GetAttribute("ComboBonus")
		player:SetAttribute("ComboBonus", (if type(bonus) == "number" then bonus else 0) + (shown - base))
	end
	if critTier and DataService.onCrit then
		DataService.onCrit(player, critTier, shown)
	end
	data.aura = math.min(data.aura + shown, Levels.MAX_AURA)
	player:SetAttribute("Aura", data.aura)
	local newLevel = Levels.levelForAura(data.aura)
	local oldLevel = player:GetAttribute("Level")
	player:SetAttribute("Level", newLevel)
	if type(oldLevel) == "number" and newLevel > oldLevel and DataService.onLevelUp then
		DataService.onLevelUp(player, newLevel)
	end
	local newRank = Levels.rankOfLevel(newLevel)
	if newRank > data.rank then
		data.rank = newRank
		player:SetAttribute("Rank", newRank)
		if DataService.onRankUp then
			DataService.onRankUp(player, newRank)
		end
	end
	if Features.treadmill then
		-- (Training Island is off in the simple game; with it on, aura also fills training levels)
		local settings = Config.training
		if data.trainingLevel < settings.maxLevel then
			local total = (auraRemainder[player] or 0) + shown
			local strides = math.floor(total / settings.auraPerStride)
			auraRemainder[player] = total - strides * settings.auraPerStride
			if strides >= 1 then
				local level, progress = TrainingRules.addStrides(data.trainingLevel, data.trainingProgress, strides, settings)
				data.trainingLevel = level
				data.trainingProgress = progress
				syncTraining(player, data)
			end
		end
	end
	return shown
end

-- Something to call when a gain is a crit ("mega" or "ultra"); set by ComboSystem.
DataService.onCrit = nil :: ((Player, string, number) -> ())?

-- Lifetime counters the achievements watch. Add to one (returns the new value) or raise it to at least a value.
function DataService.bumpCounter(player: Player, key: string, amount: number): number
	local data = DataService.get(player)
	if not data or #key > 32 or amount ~= amount or amount < 0 then
		return 0
	end
	local value = math.min((data.counters[key] or 0) + math.floor(amount), 1e9)
	data.counters[key] = value
	return value
end

function DataService.raiseCounter(player: Player, key: string, value: number): number
	local data = DataService.get(player)
	if not data or #key > 32 or value ~= value or value < 0 then
		return 0
	end
	local whole = math.min(math.floor(value), 1e9)
	if whole > (data.counters[key] or 0) then
		data.counters[key] = whole
	end
	return data.counters[key] or 0
end

-- Unlock an achievement once. Returns true the first time.
function DataService.unlockAchievement(player: Player, id: string): boolean
	local data = DataService.get(player)
	if not data then
		return false
	end
	return PlayerData.markSeen(data.achievements, id)
end

function DataService.setTitle(player: Player, title: string)
	local data = DataService.get(player)
	if data and #title <= 24 then
		data.title = title
		player:SetAttribute("Title", title)
	end
end

-- Something to call when a player earns a new rank (set by PopupSystem wiring in RankVisuals).
DataService.onLevelUp = nil :: ((Player, number) -> ())?
DataService.onRankUp = nil :: ((Player, number) -> ())?

-- The player has seen the unlock card for an ability ("shove", "dash" or "stare"). Saved, so it shows only once.
function DataService.markUnlockSeen(player: Player, id: string): boolean
	local data = DataService.get(player)
	if not data or not UNLOCK_IDS[id] then
		return false
	end
	local isNew = PlayerData.markSeen(data.unlocksSeen, id)
	if isNew then
		syncUnlocks(player, data)
	end
	return isNew
end

-- A hidden Aura Stash was opened for the first time ever? Returns whether it is new and how many are found now.
function DataService.recordStash(player: Player, stashId: string): (boolean, number)
	local data = DataService.get(player)
	if not data then
		return false, 0
	end
	local isNew = PlayerData.markSeen(data.stashes, stashId)
	syncUnlocks(player, data)
	local found = player:GetAttribute("StashesFound")
	return isNew, if type(found) == "number" then found else 0
end

-- Wait (up to `seconds`) for a player's data to finish loading. Returns the data or nil.
function DataService.waitFor(player: Player, seconds: number): PlayerData.Data?
	local deadline = os.clock() + seconds
	while os.clock() < deadline do
		local data = DataService.get(player)
		if data then
			return data
		end
		if player.Parent ~= Players then
			return nil
		end
		task.wait(0.25)
	end
	return DataService.get(player)
end

-- Apply one Robux cosmetic purchase to the live save, once. Returns the CosmeticRules result string.
function DataService.applyCosmeticPurchase(player: Player, itemId: string, purchaseId: string): string
	local data = DataService.get(player)
	if not data then
		return "not_loaded"
	end
	local result = CosmeticRules.applyPurchase(data :: any, CosmeticCatalog :: any, itemId, purchaseId, os.time())
	if result == "granted" or result == "already_owned" then
		syncCosmetics(player, data)
	end
	return result
end

-- Equip (or, with an empty id, remove) a cosmetic in a slot. Returns ok and a stable reason.
function DataService.equipCosmetic(player: Player, slot: any, id: any): (boolean, string)
	local data = DataService.get(player)
	if not data then
		return false, "not_loaded"
	end
	local ok, reason = CosmeticRules.canEquip(data :: any, CosmeticCatalog :: any, slot, id)
	if not ok then
		return false, reason or "bad_input"
	end
	if id == "" then
		data.equipped[slot] = nil
	else
		data.equipped[slot] = id
	end
	syncCosmetics(player, data)
	return true, ""
end

-- Add season points earned for a faction. Rolls the season forward if the week changed. Returns true if added.
function DataService.addSeasonPoints(player: Player, faction: number, amount: number, week: number): boolean
	local data = DataService.get(player)
	if not data or not SeasonRules.addPoints(data.season :: any, faction, amount, week) then
		return false
	end
	syncSeason(player, data)
	return true
end

-- Bring a player's season up to `week` (so last week becomes "previous"). Returns the season record or nil.
function DataService.rollSeason(player: Player, week: number): SeasonRules.Season?
	local data = DataService.get(player)
	if not data then
		return nil
	end
	SeasonRules.roll(data.season :: any, week)
	syncSeason(player, data)
	return data.season :: any
end

-- Mark the previous week's reward as resolved (whether or not it was earned).
function DataService.markSeasonClaimed(player: Player)
	local data = DataService.get(player)
	if data and data.season.prevWeek > data.season.claimed then
		data.season.claimed = data.season.prevWeek
	end
end

-- Give a cosmetic the player does not own yet (season reward). Returns true if it was added.
function DataService.grantCosmetic(player: Player, id: string): boolean
	local data = DataService.get(player)
	if not data or CosmeticCatalog.byId[id] == nil or not PlayerData.addCosmetic(data, id) then
		return false
	end
	syncCosmetics(player, data)
	return true
end

-- Refresh the rewards attributes (called on a timer so the numbers stay current).
function DataService.syncRewards(player: Player)
	local data = DataService.get(player)
	if data then
		syncRewards(player, data)
	end
end

-- Claim today's daily box. All or nothing: the box is added and the streak advances together.
-- Returns ok, a stable reason, the box tier and the streak day claimed.
function DataService.claimDaily(player: Player): (boolean, string, string, number)
	local data = DataService.get(player)
	if not data then
		return false, "not_loaded", "", 0
	end
	local today = PlayerData.dayNumber(os.time())
	local ok, reason, day = StreakRules.claim(data.streakDay, data.lastClaimDay, today, #Config.dailyStreak.auraRewards)
	if not ok then
		return false, reason or "bad_input", "", 0
	end
	local reward = Config.dailyStreak.auraRewards[day]
	if reward == nil then
		return false, "bad_input", "", 0
	end
	data.streakDay = day
	data.lastClaimDay = today
	syncRewards(player, data)
	DataService.addAura(player, reward)
	return true, "", tostring(reward), day
end

-- Collect the barracks income. All or nothing. Returns ok, a stable reason and the points paid.
function DataService.collectBarracks(player: Player): (boolean, string, number)
	if not Features.barracks then
		return false, "disabled", 0 -- switched off at launch
	end
	local data = DataService.get(player)
	if not data then
		return false, "not_loaded", 0
	end
	local now = os.time()
	local amount = BarracksRules.pending(now, data.barracksSince, data.rank, Config.barracks)
	if amount <= 0 then
		data.barracksSince = BarracksRules.normalize(now, data.barracksSince) -- repair a start time in the future
		return false, "nothing_to_collect", 0
	end
	PlayerData.addPoints(data, amount)
	data.barracksSince = now
	player:SetAttribute("Points", data.points)
	syncRewards(player, data)
	return true, "", amount
end

-- Count a zone capture the player was paid for (reveals more of the game as they play).
function DataService.recordCapture(player: Player)
	local data = DataService.get(player)
	if data then
		data.lifetimeCaptures += 1
		syncReveal(player, data)
	end
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
