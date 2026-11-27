--!strict
-- Pure player save-data rules for Mog Wars. No Roblox calls.
-- To change the shape: add the field to template(), bump CURRENT_VERSION, add a migration, add a test.

export type Data = {
	version: number,
	points: number, -- Mog Points
	rank: number, -- 1 = Rookie
	warsToday: number, -- wars finished on lastWarDay (for the daily full-reward limit)
	lastWarDay: number, -- UTC day number (days since 1970) of the last finished war, 0 = never
	boxes: { [string]: number }, -- unopened boxes by tier id, for example { recruit = 2 }
}

local PlayerData = {}

PlayerData.CURRENT_VERSION = 3
PlayerData.MAX_BOXES_PER_TIER = 1000
PlayerData.MAX_POINTS = 1_000_000_000 -- far above anything reachable; stops runaway or overflowing values

function PlayerData.template(): Data
	return { version = PlayerData.CURRENT_VERSION, points = 0, rank = 1, warsToday = 0, lastWarDay = 0, boxes = {} }
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
