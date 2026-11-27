--!strict
-- Pure player save-data rules for Mog Wars. No Roblox calls.
-- To change the shape: add the field to template(), bump CURRENT_VERSION, add a migration, add a test.

export type Data = {
	version: number,
	points: number, -- Mog Points
	rank: number, -- 1 = Rookie
}

local PlayerData = {}

PlayerData.CURRENT_VERSION = 1
PlayerData.MAX_POINTS = 1_000_000_000 -- far above anything reachable; stops runaway or overflowing values

function PlayerData.template(): Data
	return { version = PlayerData.CURRENT_VERSION, points = 0, rank = 1 }
end

local function isWholeNumber(value: any): boolean
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
		and value == math.floor(value)
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
