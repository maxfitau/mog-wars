--!strict
-- Pure level maths for BIG NUMBERS: levels, ranks, the income multiplier and the aura needed for each level. No Roblox calls.
-- Level 0 is NPC. Levels 1-10 are Rookie I-X, 11-20 Sigma I-X, and so on up to Mog God I-X (levels 51-60), then endless
-- "Mog God *1, *2 ..." (level 61 and up). All the numbers come from Pace.levels.

local Pace = require(script.Parent:WaitForChild("Pace"))

local Levels = {}

local settings = Pace.levels
local ROMAN = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X" }

-- Seconds a level takes (at the nominal income) when you are leaving `level`.
local function secondsFor(level: number): number
	local lastEnd = 0
	for _, band in settings.bands do
		lastEnd = band[1] + band[2]
		if level >= band[1] and level < lastEnd then
			return band[3] + (band[4] - band[3]) * (level - band[1]) / math.max(1, band[2] - 1)
		end
	end
	return settings.starSeconds * settings.starGrowth ^ (level - lastEnd) -- the star levels after Mog God X
end

-- Seconds an active player spends on the level they are leaving (used by the pacing test).
function Levels.secondsFor(level: number): number
	return secondsFor(level)
end

-- The multiplier on all aura income at a level.
function Levels.multiplier(level: number): number
	return settings.growth ^ math.clamp(level, 0, settings.maxLevel)
end

-- The aura a normal player earns each second at a level.
function Levels.nominalIncome(level: number): number
	return settings.nominalIncome * Levels.multiplier(level)
end

-- cumulative[n] = the total aura you need to BE at level n (cumulative[0] = 0).
local cumulative: { number } = { [0] = 0 } :: any
for level = 1, settings.maxLevel do
	cumulative[level] = math.min(cumulative[level - 1] + secondsFor(level - 1) * Levels.nominalIncome(level - 1), settings.maxAura)
end

function Levels.cumulative(level: number): number
	return cumulative[math.clamp(math.floor(level), 0, settings.maxLevel)]
end

-- The level a player has reached with `aura` total aura (never goes down as aura goes up).
function Levels.levelForAura(aura: number): number
	if aura ~= aura or aura <= 0 then
		return 0
	end
	local low, high = 0, settings.maxLevel
	while low < high do
		local middle = (low + high + 1) // 2
		if cumulative[middle] <= aura then
			low = middle
		else
			high = middle - 1
		end
	end
	return low
end

-- The rank number (1 NPC ... 7 Mog God) of a level.
function Levels.rankOfLevel(level: number): number
	if level <= 0 then
		return 1
	end
	return math.min(7, 1 + math.ceil(level / settings.perRank))
end

-- The first level of a rank (rank 2, Rookie, starts at level 1).
function Levels.firstLevelOfRank(rank: number): number
	if rank <= 1 then
		return 0
	end
	return (rank - 2) * settings.perRank + 1
end

-- 0 below the star levels, otherwise 1 for Mog God *1, 2 for *2 ...
function Levels.star(level: number): number
	return math.max(0, level - 6 * settings.perRank)
end

-- "NPC", "Rookie IV", "Mog God X", "Mog God *5". `names` is the list of seven rank names.
function Levels.name(level: number, names: { string }): string
	if level <= 0 then
		return names[1]
	end
	local star = Levels.star(level)
	if star > 0 then
		return names[7] .. " ★" .. tostring(star)
	end
	local rank = Levels.rankOfLevel(level)
	return names[rank] .. " " .. ROMAN[level - Levels.firstLevelOfRank(rank) + 1]
end

-- For the bar: the level, the aura where it started and the aura where the next level starts.
function Levels.progress(aura: number): (number, number, number)
	local level = Levels.levelForAura(aura)
	return level, cumulative[level], cumulative[math.min(level + 1, settings.maxLevel)]
end

-- A whole number that sorts like the aura and fits in a leaderboard (they only hold integers below about 9.2e18).
function Levels.sortKey(aura: number): number
	if aura ~= aura or aura <= 0 then
		return 0
	end
	return math.floor(math.log10(aura + 1) * 1e9)
end

Levels.MAX_AURA = settings.maxAura

return Levels
