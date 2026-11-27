--!strict
-- Plain-Luau tests, no Roblox needed. Run from the repo root with the standalone Luau runtime:
--   luau tests/MapLayout.test.luau
-- STATUS: written but NOT yet run (no Luau runtime in the cloud session). Run it on a PC first.

local MapLayout = require("../src/shared/MapLayout")

local failures = 0

local function check(name: string, condition: boolean)
	if condition then
		print("PASS " .. name)
	else
		failures += 1
		print("FAIL " .. name)
	end
end

local zones = MapLayout.zones
local half = MapLayout.baseplateSize / 2

check("8 to 12 territories (DESIGN.md)", #zones >= 8 and #zones <= 12)
check("one home base per faction", #MapLayout.bases == 4)

local names: { [string]: boolean } = {}
local unique = true
local sane = true
local inside = true
for _, zone in zones do
	if names[zone.name] then
		unique = false
	end
	names[zone.name] = true
	if zone.value < 1 or zone.value ~= math.floor(zone.value) or zone.size <= 0 then
		sane = false
	end
	if math.abs(zone.x) + zone.size / 2 > half or math.abs(zone.z) + zone.size / 2 > half then
		inside = false
	end
end
check("zone names are unique", unique)
check("zone values and sizes make sense", sane)
check("every zone is on the baseplate", inside)

-- no two zones touch (at least 8 studs between them) so a player is only ever in one zone
local apart = true
for i = 1, #zones do
	for j = i + 1, #zones do
		local a, b = zones[i], zones[j]
		local gapX = math.abs(a.x - b.x) - (a.size + b.size) / 2
		local gapZ = math.abs(a.z - b.z) - (a.size + b.size) / 2
		if math.max(gapX, gapZ) < 8 then
			apart = false
		end
	end
end
check("zones do not touch each other", apart)

-- bases are safe: on the plate and well away from every zone
local safe = true
local onPlate = true
for _, base in MapLayout.bases do
	if math.abs(base.x) + MapLayout.baseSize / 2 > half or math.abs(base.z) + MapLayout.baseSize / 2 > half then
		onPlate = false
	end
	for _, zone in zones do
		local gapX = math.abs(base.x - zone.x) - (MapLayout.baseSize + zone.size) / 2
		local gapZ = math.abs(base.z - zone.z) - (MapLayout.baseSize + zone.size) / 2
		if math.max(gapX, gapZ) < 8 then
			safe = false
		end
	end
end
check("bases are on the baseplate", onPlate)
check("bases are at least 8 studs from every zone", safe)

-- there is exactly one centre zone and it is worth the most
local best = 0
for _, zone in zones do
	best = math.max(best, zone.value)
end
check("the centre zone is worth the most", zones[1].name == "Zone_Centre" and zones[1].value == best)

if failures > 0 then
	error(failures .. " test(s) failed")
end
print("All tests passed")
