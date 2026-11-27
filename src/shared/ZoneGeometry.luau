--!strict
-- Pure "is this point inside the zone" test, in the zone part's own space (so rotated zones work).
-- The zone is a flat box; standing means being inside its footprint and within `headroom` studs above it.

local ZoneGeometry = {}

function ZoneGeometry.contains(
	localX: number,
	localY: number,
	localZ: number,
	sizeX: number,
	sizeY: number,
	sizeZ: number,
	headroom: number
): boolean
	for _, value in { localX, localY, localZ, sizeX, sizeY, sizeZ, headroom } do
		if value ~= value or value == math.huge or value == -math.huge then
			return false
		end
	end
	return math.abs(localX) <= sizeX / 2
		and math.abs(localZ) <= sizeZ / 2
		and localY >= -sizeY / 2
		and localY <= sizeY / 2 + headroom
end

return ZoneGeometry
