--!strict
-- Pure spawn rules. A player spawns on their faction's front line: just outside the owned zone nearest the
-- centre of the map, on the side facing their own base. A faction that owns nothing spawns at its base.

export type ZoneInfo = { x: number, z: number, size: number, owner: number }

local SpawnRules = {}

local EDGE_GAP = 8 -- studs beyond the zone's edge (along the line to the base) for the spawn spot
local SPREAD = 3 -- studs between neighbouring spawn slots

local function finite(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge
end

-- The owned zone closest to the map centre (the front), or nil if the faction owns none.
-- Ties go to the zone listed first, so the answer never flickers.
function SpawnRules.frontZone(faction: number, zones: { ZoneInfo }): ZoneInfo?
	local best: ZoneInfo? = nil
	local bestDistance = math.huge
	for _, zone in zones do
		if zone.owner == faction and finite(zone.x) and finite(zone.z) then
			local distance = zone.x * zone.x + zone.z * zone.z
			if distance < bestDistance then
				best, bestDistance = zone, distance
			end
		end
	end
	return best
end

-- Where to put a spawning player. `slot` is a counter that spreads players out along the zone edge so they
-- do not stack. Returns x, z and "zone" or "base".
function SpawnRules.spawnPoint(
	faction: number,
	zones: { ZoneInfo },
	baseX: number,
	baseZ: number,
	slot: number
): (number, number, string)
	local zone = SpawnRules.frontZone(faction, zones)
	if not zone then
		return baseX, baseZ, "base"
	end
	local dx, dz = baseX - zone.x, baseZ - zone.z
	local length = math.sqrt(dx * dx + dz * dz)
	if not finite(length) or length < 1e-6 then
		dx, dz, length = 0, 1, 1
	end
	dx, dz = dx / length, dz / length
	-- Zones are squares, so walk out to where the line to the base leaves the square, then a little further.
	local distance = (zone.size / 2) / math.max(math.abs(dx), math.abs(dz)) + EDGE_GAP
	local sideways = ((math.floor(slot) % 5) - 2) * SPREAD
	return zone.x + dx * distance - dz * sideways, zone.z + dz * distance + dx * sideways, "zone"
end

return SpawnRules
