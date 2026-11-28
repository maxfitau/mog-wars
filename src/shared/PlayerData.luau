--!strict
-- Pure player save-data rules for Mog Wars. No Roblox calls.
-- To change the shape: add the field to template(), bump CURRENT_VERSION, add a migration, add a test.

export type Data = {
	version: number,
	points: number, -- Mog Points
	rank: number, -- 1 = Rookie
	warsToday: number, -- wars finished on lastWarDay (for the daily full-reward limit)
	lastWarDay: number, -- UTC day number (days since 1970) of the last finished war, 0 = never
	boxes: { [string]: number }, -- unopened boxes by tier id, for example { gold = 2 }
	units: { [string]: number }, -- owned units by id, for example { tank = 1 }
	cosmetics: { [string]: boolean }, -- owned cosmetic ids
	boxDay: number, -- UTC day number the boxesToday count belongs to
	boxesToday: number, -- boxes earned from wars on boxDay (daily cap)
	streakDay: number, -- 0 = never claimed, else 1 to 7: the day of the last daily claim
	lastClaimDay: number, -- UTC day number of the last daily claim, 0 = never
	barracksSince: number, -- unix seconds when barracks income started building, 0 = not started
	trainingLevel: number, -- Training Arena level (raises aura power), 0 = untrained
	trainingProgress: number, -- strides into the current level
	trainingDay: number, -- UTC day number the trainingToday count belongs to
	trainingToday: number, -- strides counted on trainingDay (daily cap)
	equipped: { [string]: string }, -- cosmetic slot to the cosmetic id worn there
	receipts: { [string]: number }, -- Robux purchase ids already applied, with when (never grant twice)
	weapons: { [string]: boolean }, -- weapons unlocked from boxes (rank unlocks need no entry)
	aura: number, -- total aura earned, ever. Your rank comes from this and never goes down
	unlocksSeen: { [string]: boolean }, -- unlock cards already shown ("shove", "dash", "stare")
	stashes: { [string]: boolean }, -- hidden Aura Stashes found, ever (12 in all)
	achievements: { [string]: boolean }, -- unlocked achievements
	counters: { [string]: number }, -- lifetime counters the achievements watch (flags, shoves, ...)
	title: string, -- the title shown over your head ("" for none)
	lifetimeWars: number, -- wars the player took part in (used to reveal screens gradually)
	lifetimeCaptures: number, -- zone captures the player was paid for
	season: { week: number, points: { [string]: number }, prevWeek: number, prevPoints: { [string]: number }, claimed: number },
	-- v14: the weapon collection, daily and weekly quests, the team league, and the (switched off) season pass
	collection: { [string]: number }, -- weapon id to stars owned (1 to 5); every weapon you have found
	equippedWeapon: string, -- the weapon that replaces Shove ("" = plain Shove)
	questState: { dailyDay: number, daily: { [string]: number }, weeklyWeek: number, weekly: { [string]: number }, claimed: { [string]: boolean } },
	leagueClaimedWeek: number, -- the last league week whose Monday chest was claimed
	pass: { tier: number, xp: number, claimed: { [string]: boolean } },
}

local PlayerData = {}

PlayerData.CURRENT_VERSION = 14
PlayerData.MAX_STARS = 5
PlayerData.MAX_RECEIPT_ENTRIES = 400
PlayerData.MAX_UNITS = 1000
PlayerData.MAX_BOXES_PER_TIER = 1000
PlayerData.MAX_POINTS = 1_000_000_000 -- far above anything reachable; stops runaway or overflowing values

function PlayerData.template(): Data
	return { version = PlayerData.CURRENT_VERSION, points = 0, rank = 1, warsToday = 0, lastWarDay = 0, boxes = {}, units = {}, cosmetics = {}, boxDay = 0, boxesToday = 0, streakDay = 0, lastClaimDay = 0, barracksSince = 0, trainingLevel = 0, trainingProgress = 0, trainingDay = 0, trainingToday = 0, equipped = {}, receipts = {}, weapons = {}, aura = 0, unlocksSeen = {}, stashes = {}, achievements = {}, counters = {}, title = "", lifetimeWars = 0, lifetimeCaptures = 0, season = { week = 0, points = {}, prevWeek = 0, prevPoints = {}, claimed = 0 }, collection = {}, equippedWeapon = "", questState = { dailyDay = 0, daily = {}, weeklyWeek = 0, weekly = {}, claimed = {} }, leagueClaimedWeek = 0, pass = { tier = 0, xp = 0, claimed = {} } }
end

-- True when `collection` maps weapon ids to whole star counts from 1 to MAX_STARS.
function PlayerData.collectionValid(collection: any): boolean
	if type(collection) ~= "table" then
		return false
	end
	for id, stars in collection do
		if type(id) ~= "string" or id == "" or #id > 40 or not (type(stars) == "number" and stars == math.floor(stars) and stars >= 1 and stars <= PlayerData.MAX_STARS) then
			return false
		end
	end
	return true
end

-- Add one copy of a weapon: new = 1 star, a duplicate adds a star up to MAX_STARS. Returns (isNew, stars after).
function PlayerData.addWeapon(data: Data, id: string): (boolean, number)
	if type(id) ~= "string" or id == "" or #id > 40 then
		return false, 0
	end
	local current = data.collection[id]
	if not current then
		data.collection[id] = 1
		return true, 1
	end
	data.collection[id] = math.min(PlayerData.MAX_STARS, current + 1)
	return false, data.collection[id]
end

local function isWholeNumber(value: any): boolean
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
		and value == math.floor(value)
end

-- True when the boxes table maps tier names to whole counts from 0 up to the cap.
function PlayerData.boxesValid(boxes: any): boolean
	if type(boxes) ~= "table" then
		return false
	end
	for tier, count in boxes do
		if type(tier) ~= "string" or tier == "" or not isWholeNumber(count) or count < 0 or count > PlayerData.MAX_BOXES_PER_TIER then
			return false
		end
	end
	return true
end

-- True when `counts` maps non-empty string ids to whole numbers from 0 up to `max`.
function PlayerData.countsValid(counts: any, max: number): boolean
	if type(counts) ~= "table" then
		return false
	end
	for id, count in counts do
		if type(id) ~= "string" or id == "" or not isWholeNumber(count) or count < 0 or count > max then
			return false
		end
	end
	return true
end

function PlayerData.cosmeticsValid(cosmetics: any): boolean
	if type(cosmetics) ~= "table" then
		return false
	end
	for id, owned in cosmetics do
		if type(id) ~= "string" or id == "" or owned ~= true then
			return false
		end
	end
	return true
end

-- True when `equipped` maps non-empty string slots to non-empty string ids of a sane length.
function PlayerData.equippedValid(equipped: any): boolean
	if type(equipped) ~= "table" then
		return false
	end
	for slot, id in equipped do
		if type(slot) ~= "string" or slot == "" or #slot > 30 or type(id) ~= "string" or id == "" or #id > 60 then
			return false
		end
	end
	return true
end

-- True when `receipts` maps purchase id strings to whole-number times, with a sane number of entries.
function PlayerData.receiptsValid(receipts: any): boolean
	if type(receipts) ~= "table" then
		return false
	end
	local count = 0
	for id, stamp in receipts do
		count += 1
		if type(id) ~= "string" or id == "" or #id > 100 or not isWholeNumber(stamp) or stamp < 0 or count > PlayerData.MAX_RECEIPT_ENTRIES then
			return false
		end
	end
	return true
end

local function pointMapValid(points: any): boolean
	if type(points) ~= "table" then
		return false
	end
	local count = 0
	for key, value in points do
		count += 1
		if type(key) ~= "string" or key == "" or #key > 4 or not isWholeNumber(value) or value < 0 or value > 1e9 or count > 8 then
			return false
		end
	end
	return true
end

-- True when the season record has the right shape and sane whole numbers.
function PlayerData.seasonValid(season: any): boolean
	return type(season) == "table"
		and isWholeNumber(season.week)
		and season.week >= 0
		and isWholeNumber(season.prevWeek)
		and season.prevWeek >= 0
		and isWholeNumber(season.claimed)
		and season.claimed >= 0
		and pointMapValid(season.points)
		and pointMapValid(season.prevPoints)
end

-- Give the player one unopened box of a tier. Returns false for an empty tier name or a full stack.
function PlayerData.addBox(data: Data, tier: string): boolean
	if type(tier) ~= "string" or tier == "" then
		return false
	end
	local current = data.boxes[tier] or 0
	if current >= PlayerData.MAX_BOXES_PER_TIER then
		return false
	end
	data.boxes[tier] = current + 1
	return true
end

-- Take one unopened box of a tier. Returns false (changing nothing) if the player has none.
function PlayerData.takeBox(data: Data, tier: string): boolean
	local current = data.boxes[tier]
	if type(tier) ~= "string" or not current or current < 1 then
		return false
	end
	if current == 1 then
		data.boxes[tier] = nil
	else
		data.boxes[tier] = current - 1
	end
	return true
end

-- Earn a box from a war: counts toward the daily cap, which starts fresh on a new UTC day.
-- Returns false (changing nothing) if the cap is reached or the stack is full.
function PlayerData.tryEarnBox(data: Data, day: number, cap: number, tier: string): boolean
	local used = if data.boxDay == day then data.boxesToday else 0
	if used >= cap then
		return false
	end
	if not PlayerData.addBox(data, tier) then
		return false
	end
	data.boxDay = day
	data.boxesToday = used + 1
	return true
end

-- Add a unit. Returns false for a bad id or a full stack.
function PlayerData.addUnit(data: Data, unit: string): boolean
	if type(unit) ~= "string" or unit == "" then
		return false
	end
	local current = data.units[unit] or 0
	if current >= PlayerData.MAX_UNITS then
		return false
	end
	data.units[unit] = current + 1
	return true
end

-- Use up one owned unit. Returns false (changing nothing) if the player has none.
function PlayerData.takeUnit(data: Data, unit: string): boolean
	local current = data.units[unit]
	if type(unit) ~= "string" or not current or current < 1 then
		return false
	end
	if current == 1 then
		data.units[unit] = nil
	else
		data.units[unit] = current - 1
	end
	return true
end

-- True when `counters` is a table of short names to whole numbers.
function PlayerData.countersValid(counters: any): boolean
	if type(counters) ~= "table" then
		return false
	end
	for key, value in counters do
		if type(key) ~= "string" or #key > 32 or not isWholeNumber(value) or value < 0 then
			return false
		end
	end
	return true
end

-- Remember that an unlock card was shown / a stash was found. Return false if the id is bad or already recorded.
function PlayerData.markSeen(map: { [string]: boolean }, id: string): boolean
	if type(id) ~= "string" or id == "" or #id > 40 or map[id] then
		return false
	end
	map[id] = true
	return true
end

-- Unlock a weapon. Returns false if the id is bad or it is already unlocked.
function PlayerData.unlockWeapon(data: Data, id: string): boolean
	if type(id) ~= "string" or id == "" or data.weapons[id] then
		return false
	end
	data.weapons[id] = true
	return true
end

-- Add a cosmetic. Returns false if the id is bad or already owned.
function PlayerData.addCosmetic(data: Data, id: string): boolean
	if type(id) ~= "string" or id == "" or data.cosmetics[id] then
		return false
	end
	data.cosmetics[id] = true
	return true
end

-- Upgrade older saves in place. Returns false if the value is not a table at all.
-- Never edit a migration that has shipped; add a new step instead.
function PlayerData.migrate(data: any): boolean
	if type(data) ~= "table" then
		return false
	end
	if data.version == 1 then
		data.warsToday = 0
		data.lastWarDay = 0
		data.version = 2
	end
	if data.version == 2 then
		data.boxes = {}
		data.version = 3
	end
	if data.version == 3 then
		data.units = {}
		data.cosmetics = {}
		data.boxDay = 0
		data.boxesToday = 0
		data.version = 4
	end
	if data.version == 4 then
		data.streakDay = 0
		data.lastClaimDay = 0
		data.barracksSince = 0
		data.version = 5
	end
	if data.version == 5 then
		data.trainingLevel = 0
		data.trainingProgress = 0
		data.trainingDay = 0
		data.trainingToday = 0
		data.version = 6
	end
	if data.version == 6 then
		data.equipped = {}
		data.receipts = {}
		data.version = 7
	end
	if data.version == 7 then
		data.season = { week = 0, points = {}, prevWeek = 0, prevPoints = {}, claimed = 0 }
		data.version = 8
	end
	if data.version == 8 then
		-- Players who already reached rank 2 or higher have played enough to see everything.
		local experienced = type(data.rank) == "number" and data.rank >= 2
		data.lifetimeWars = if experienced then 3 else 0
		data.lifetimeCaptures = if experienced then 1 else 0
		data.version = 9
	end
	if data.version == 9 then
		data.weapons = {}
		data.version = 10
	end
	if data.version == 10 then
		data.aura = 0 -- ranks are now earned by total aura; a rank already earned is kept
		data.version = 11
	end
	if data.version == 11 then
		data.unlocksSeen = {}
		data.stashes = {}
		data.version = 12
	end
	if data.version == 12 then
		data.achievements = {}
		data.counters = {}
		data.title = ""
		data.version = 13
	end
	if data.version == 13 then
		data.collection = {}
		data.equippedWeapon = ""
		data.questState = { dailyDay = 0, daily = {}, weeklyWeek = 0, weekly = {}, claimed = {} }
		data.leagueClaimedWeek = 0
		data.pass = { tier = 0, xp = 0, claimed = {} }
		data.version = 14
	end
	return true
end

-- UTC day number for a unix time in seconds.
function PlayerData.dayNumber(unixSeconds: number): number
	return math.floor(unixSeconds / 86400)
end

-- 1 for full rewards, or `reduced` once the player has finished `fullWars` wars today.
function PlayerData.rewardMultiplier(data: Data, day: number, fullWars: number, reduced: number): number
	if data.lastWarDay ~= day then
		return 1
	end
	return if data.warsToday >= fullWars then reduced else 1
end

-- Count one finished war for today, starting the count fresh on a new day.
function PlayerData.recordWar(data: Data, day: number)
	if data.lastWarDay ~= day then
		data.lastWarDay = day
		data.warsToday = 0
	end
	data.warsToday += 1
end

-- True when the table has the right shape and sane values.
function PlayerData.isValid(data: any): boolean
	if type(data) ~= "table" then
		return false
	end
	return data.version == PlayerData.CURRENT_VERSION
		and isWholeNumber(data.points)
		and data.points >= 0
		and data.points <= PlayerData.MAX_POINTS
		and isWholeNumber(data.rank)
		and data.rank >= 1
		and isWholeNumber(data.warsToday)
		and data.warsToday >= 0
		and isWholeNumber(data.lastWarDay)
		and data.lastWarDay >= 0
		and PlayerData.boxesValid(data.boxes)
		and PlayerData.countsValid(data.units, PlayerData.MAX_UNITS)
		and PlayerData.cosmeticsValid(data.cosmetics)
		and isWholeNumber(data.boxDay)
		and data.boxDay >= 0
		and isWholeNumber(data.boxesToday)
		and data.boxesToday >= 0
		and isWholeNumber(data.streakDay)
		and data.streakDay >= 0
		and data.streakDay <= 7
		and isWholeNumber(data.lastClaimDay)
		and data.lastClaimDay >= 0
		and isWholeNumber(data.barracksSince)
		and data.barracksSince >= 0
		and isWholeNumber(data.trainingLevel)
		and data.trainingLevel >= 0
		and data.trainingLevel <= 100
		and isWholeNumber(data.trainingProgress)
		and data.trainingProgress >= 0
		and isWholeNumber(data.trainingDay)
		and data.trainingDay >= 0
		and isWholeNumber(data.trainingToday)
		and data.trainingToday >= 0
		and data.trainingToday <= 86400
		and PlayerData.equippedValid(data.equipped)
		and PlayerData.receiptsValid(data.receipts)
		and PlayerData.seasonValid(data.season)
		and PlayerData.cosmeticsValid(data.weapons)
		and PlayerData.cosmeticsValid(data.unlocksSeen)
		and PlayerData.cosmeticsValid(data.stashes)
		and PlayerData.cosmeticsValid(data.achievements)
		and PlayerData.countersValid(data.counters)
		and type(data.title) == "string"
		and isWholeNumber(data.aura)
		and data.aura >= 0
		and isWholeNumber(data.lifetimeWars)
		and data.lifetimeWars >= 0
		and isWholeNumber(data.lifetimeCaptures)
		and data.lifetimeCaptures >= 0
		and PlayerData.collectionValid(data.collection)
		and type(data.equippedWeapon) == "string"
		and #data.equippedWeapon <= 40
		and type(data.questState) == "table"
		and type(data.leagueClaimedWeek) == "number"
		and type(data.pass) == "table"
end

-- Add points to a save table. Returns true if it changed. Rejects bad amounts and never exceeds the cap.
function PlayerData.addPoints(data: Data, amount: number): boolean
	if not isWholeNumber(amount) or amount <= 0 then
		return false
	end
	data.points = math.min(PlayerData.MAX_POINTS, data.points + amount)
	return true
end

-- Spend points. All or nothing: returns false and changes nothing if the player cannot afford it.
function PlayerData.spendPoints(data: Data, amount: number): boolean
	if not isWholeNumber(amount) or amount <= 0 or data.points < amount then
		return false
	end
	data.points -= amount
	return true
end

return PlayerData
