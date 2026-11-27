--!strict
-- The four factions and pure assignment rules. Names are placeholders: change them here only.
-- Ids are 1 to 4; 0 always means "no faction".

export type Faction = {
	id: number,
	name: string,
	brickColor: string, -- a Roblox BrickColor name, used for Teams and spawn pads so they match
	rgb: { number }, -- red, green, blue 0 to 255; systems turn this into a Color3
}

local FactionRules = {}

FactionRules.factions = {
	{ id = 1, name = "Jawline Legion", brickColor = "Bright red", rgb = { 196, 40, 28 } },
	{ id = 2, name = "Mewing Order", brickColor = "Bright blue", rgb = { 13, 105, 172 } },
	{ id = 3, name = "Sigma Syndicate", brickColor = "Bright yellow", rgb = { 245, 205, 48 } },
	-- Renamed from "Aura Cartel" (see docs/compliance.md); change back here if you prefer.
	{ id = 4, name = "Aura Collective", brickColor = "Bright violet", rgb = { 107, 50, 124 } },
} :: { Faction }

function FactionRules.count(): number
	return #FactionRules.factions
end

function FactionRules.byId(id: number): Faction?
	return FactionRules.factions[id]
end

-- Pick the faction with the fewest players. Ties go to the lowest id, so the result is predictable.
-- `counts` maps faction id to current player count; missing ids count as 0.
function FactionRules.pickFaction(counts: { [number]: number }): number
	local bestId, bestCount = 1, math.huge
	for id = 1, #FactionRules.factions do
		local count = counts[id] or 0
		if count < bestCount then
			bestId, bestCount = id, count
		end
	end
	return bestId
end

-- True when the biggest and smallest factions differ by at most one player.
function FactionRules.isBalanced(counts: { [number]: number }): boolean
	local low, high = math.huge, 0
	for id = 1, #FactionRules.factions do
		local count = counts[id] or 0
		low = math.min(low, count)
		high = math.max(high, count)
	end
	return high - low <= 1
end

function FactionRules.color(faction: Faction): Color3
	return Color3.fromRGB(faction.rgb[1], faction.rgb[2], faction.rgb[3])
end

return FactionRules
