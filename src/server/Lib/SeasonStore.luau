--!strict
-- The shared faction totals for a season week, kept across all servers.
--   add(week, faction, amount)  adds points to a faction's total for that week
--   standings(week)             returns { [faction] = points } for factions 1 to 4, or nil if it could not be read
-- In Studio this is an in-memory mock (totals live only for that Studio session). Outside Studio it uses
-- Roblox MemoryStore sorted maps, one per week, kept for 14 days. Every call is wrapped so a MemoryStore
-- failure never breaks the game: the season still counts each player's own points, and the standings just
-- show as unavailable. THE LIVE PART NEEDS A PLAYTEST in a published scratch place (needs playtest).

local RunService = game:GetService("RunService")

local FACTION_COUNT = 4
local EXPIRE_SECONDS = 14 * 24 * 60 * 60

local SeasonStore = {}

local mock: { [number]: { [number]: number } } = {}
local maps: { [number]: any } = {}
local warned = false

local function warnOnce(message: string)
	if not warned then
		warned = true
		warn("[SeasonStore] " .. message)
	end
end

local function liveMap(week: number): any
	if not maps[week] then
		maps[week] = game:GetService("MemoryStoreService"):GetSortedMap("MogWarsSeason" .. week)
	end
	return maps[week]
end

function SeasonStore.add(week: number, faction: number, amount: number): boolean
	if faction < 1 or faction > FACTION_COUNT or amount <= 0 or amount ~= amount then
		return false
	end
	if RunService:IsStudio() then
		mock[week] = mock[week] or {}
		mock[week][faction] = (mock[week][faction] or 0) + amount
		return true
	end
	local ok, err = pcall(function()
		liveMap(week):UpdateAsync(tostring(faction), function(old: any)
			return (if type(old) == "number" then old else 0) + amount
		end, EXPIRE_SECONDS)
	end)
	if not ok then
		warnOnce("could not add season points: " .. tostring(err))
	end
	return ok
end

function SeasonStore.standings(week: number): { [number]: number }?
	local result: { [number]: number } = {}
	if RunService:IsStudio() then
		for faction = 1, FACTION_COUNT do
			result[faction] = if mock[week] then (mock[week][faction] or 0) else 0
		end
		return result
	end
	for faction = 1, FACTION_COUNT do
		local ok, value = pcall(function()
			return liveMap(week):GetAsync(tostring(faction))
		end)
		if not ok then
			warnOnce("could not read season standings: " .. tostring(value))
			return nil
		end
		result[faction] = if type(value) == "number" then value else 0
	end
	return result
end

return SeasonStore
