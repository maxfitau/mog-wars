--!strict
-- Pure number formatting for big idle-game numbers, used EVERYWHERE aura is shown: 999, 1.23K, 12.3K, 123K, 1.23M ... B, T, then
-- letter pairs aa, ab, ac ... az, ba, bb ... ("35.8ab"). Always three significant digits. Rounding happens first, so 999,950
-- shows "1.00M", never "1000K". The client formats for display only and never reads the text back as a number.

local NumberFormat = {}

local NAMED = { "", "K", "M", "B", "T" } -- tiers 0 to 4 (1, thousand, million, billion, trillion)

local function finite(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge
end

-- The suffix for a tier number: K, M, B, T, then aa (tier 5), ab, ac ... az, ba ... zz (tier 680). Beyond that "e" notation.
local function suffixFor(tier: number): string
	if tier < #NAMED then
		return NAMED[tier + 1]
	end
	local index = tier - #NAMED
	if index >= 26 * 26 then
		return "e" .. tostring(tier * 3)
	end
	local first = index // 26
	local second = index % 26
	return string.char(97 + first) .. string.char(97 + second)
end

-- Returns the suffix and tier number a value uses ("" and 0 below 1000).
function NumberFormat.suffix(value: number): (string, number)
	if not finite(value) or value < 1000 then
		return "", 0
	end
	local tier = math.floor(math.log10(value) / 3 + 1e-9)
	local rounded = value / 10 ^ (tier * 3)
	if rounded >= 999.5 then
		tier += 1
	end
	return suffixFor(tier), tier
end

-- Short text for a number with three significant digits. Negative numbers get a minus.
function NumberFormat.format(value: number): string
	if not finite(value) then
		return "0"
	end
	if value < 0 then
		return "-" .. NumberFormat.format(-value)
	end
	if value < 1000 then
		return tostring(math.floor(value))
	end
	local tier = math.floor(math.log10(value) / 3 + 1e-9)
	local scaled = value / 10 ^ (tier * 3)
	-- three significant digits: 1.23, 12.3, 123
	local text: string
	if scaled < 9.995 then
		text = string.format("%.2f", scaled)
	elseif scaled < 99.95 then
		text = string.format("%.1f", scaled)
	elseif scaled < 999.5 then
		text = string.format("%.0f", scaled)
	else
		tier += 1 -- 999.6 rounds up into the next tier: 1.00 of it
		text = "1.00"
	end
	if tonumber(text) and tonumber(text) :: number >= 999.5 then
		tier += 1
		text = "1.00"
	end
	return text .. suffixFor(tier)
end

-- Colour tier for a pop-up: "white" under 1,000, "gold" under a million, "purple" from there.
function NumberFormat.tier(value: number): string
	if not finite(value) or value < 1000 then
		return "white"
	elseif value < 1000000 then
		return "gold"
	end
	return "purple"
end

-- Text size scale for a pop-up: bigger numbers get bigger text (1 up to 1.8).
function NumberFormat.sizeScale(value: number): number
	if not finite(value) or value <= 0 then
		return 1
	end
	return math.clamp(1 + math.log10(math.max(value, 1)) * 0.12, 1, 1.8)
end

return NumberFormat
