--!strict
-- Pure number formatting for the floating number pop-ups: 12, 1.2K, 4.7M. Suffixes: K, M, B, T, Qa.
-- The classic mistake is a number like 999,950 showing as "1000.0K". This rounds first and, if the rounded
-- value reaches 1000, moves up to the next suffix ("1M"). The client formats for display only and never reads
-- the text back as a number.

local NumberFormat = {}

local SUFFIXES = { "K", "M", "B", "T", "Qa" }

local function finite(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge
end

local function trim(text: string): string
	-- "1.0" becomes "1", "1.2" stays "1.2"
	return (text:gsub("%.0$", ""))
end

-- Short text for a number: no suffix below 1000, then one decimal and a suffix. Negative numbers get a minus.
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
	local power = 1
	while power < #SUFFIXES and value >= 1000 ^ (power + 1) do
		power += 1
	end
	local scaled = value / 1000 ^ power
	local rounded = math.floor(scaled * 10 + 0.5) / 10
	if rounded >= 1000 and power < #SUFFIXES then
		power += 1
		rounded = math.floor(value / 1000 ^ power * 10 + 0.5) / 10
	end
	return trim(string.format("%.1f", rounded)) .. SUFFIXES[power]
end

-- Colour tier for a pop-up: "white" under 1,000, "gold" under 1,000,000, "purple" from there.
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
