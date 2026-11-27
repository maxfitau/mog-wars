--!strict
-- Pure daily-streak rules. Days are UTC day numbers (days since 1970), so the server clock decides.
-- Claim on consecutive days to climb the streak; skipping a day starts again at day 1; after the last
-- day of the cycle it starts again at day 1.

local StreakRules = {}

local function isWholeNumber(value: any): boolean
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
		and value == math.floor(value)
end

-- Try a claim. Returns ok, a stable reason when not ok ("already_claimed", "clock_error", "bad_input"),
-- and the streak day this claim would be (or the current streak day if it fails).
function StreakRules.claim(streakDay: number, lastClaimDay: number, today: number, length: number): (boolean, string?, number)
	if not (isWholeNumber(streakDay) and isWholeNumber(lastClaimDay) and isWholeNumber(today) and isWholeNumber(length)) or length < 1 then
		return false, "bad_input", streakDay
	end
	if today == lastClaimDay then
		return false, "already_claimed", streakDay
	end
	if today < lastClaimDay then
		return false, "clock_error", streakDay -- the saved day is in the future: never pay for it
	end
	local nextDay = 1
	if lastClaimDay ~= 0 and today == lastClaimDay + 1 and streakDay >= 1 then
		nextDay = streakDay % length + 1
	end
	return true, nil, nextDay
end

-- For the screen: can the player claim now, and which streak day will the next claim be?
function StreakRules.preview(streakDay: number, lastClaimDay: number, today: number, length: number): (boolean, number)
	local ok, reason, day = StreakRules.claim(streakDay, lastClaimDay, today, length)
	if ok then
		return true, day
	end
	if reason == "already_claimed" and streakDay >= 1 and length >= 1 then
		return false, streakDay % length + 1 -- tomorrow's day
	end
	return false, 1
end

return StreakRules
