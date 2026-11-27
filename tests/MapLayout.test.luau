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

-- War Island portals: one by every base, on the plate, clear of zones and bases
check("one portal by every base", #MapLayout.warPortals == #MapLayout.bases)
do
	local clear = true
	for _, portal in MapLayout.warPortals do
		if math.abs(portal.x) + portal.size / 2 > half or math.abs(portal.z) + portal.size / 2 > half then
			clear = false
		end
		for _, zone in zones do
			local gapX = math.abs(portal.x - zone.x) - (portal.size + zone.size) / 2
			local gapZ = math.abs(portal.z - zone.z) - (portal.size + zone.size) / 2
			if math.max(gapX, gapZ) < 8 then
				clear = false
			end
		end
		for _, base in MapLayout.bases do
			local gapX = math.abs(portal.x - base.x) - (portal.size + MapLayout.baseSize) / 2
			local gapZ = math.abs(portal.z - base.z) - (portal.size + MapLayout.baseSize) / 2
			if math.max(gapX, gapZ) < 4 then
				clear = false
			end
		end
	end
	check("war portals are on the plate and clear of zones and bases", clear)
end

-- Training Island
local island = MapLayout.trainingIsland
local islandHalf = island.size / 2
check("the islands are far apart (at least 200 studs of empty space)", math.abs(island.x) - islandHalf - half >= 200 or math.abs(island.z) - islandHalf - half >= 200)

-- every item on Training Island as a rectangle (centre x, centre z, width, length), local coordinates
local items: { { name: string, x: number, z: number, width: number, length: number } } = {}
for index, mill in island.treadmills do
	table.insert(items, { name = "treadmill " .. index, x = mill.x, z = mill.z, width = mill.width, length = mill.length })
end
table.insert(items, { name = "shop", x = island.shop.x, z = island.shop.z, width = island.shop.size, length = island.shop.size })
table.insert(items, { name = "return portal", x = island.returnPortal.x, z = island.returnPortal.z, width = island.returnPortal.size, length = island.returnPortal.size })
table.insert(items, { name = "prestige altar (reserved)", x = island.reserved.prestigeAltar.x, z = island.reserved.prestigeAltar.z, width = island.reserved.prestigeAltar.width, length = island.reserved.prestigeAltar.length })
table.insert(items, { name = "arena plots (reserved)", x = island.reserved.arenaPlots.x, z = island.reserved.arenaPlots.z, width = island.reserved.arenaPlots.width, length = island.reserved.arenaPlots.length })

do
	local inside = true
	for _, item in items do
		if math.abs(item.x) + item.width / 2 > islandHalf or math.abs(item.z) + item.length / 2 > islandHalf then
			inside = false
			print("outside the island: " .. item.name)
		end
	end
	check("everything on Training Island is on the platform", inside)

	local apart = true
	for i = 1, #items do
		for j = i + 1, #items do
			local a, b = items[i], items[j]
			local gapX = math.abs(a.x - b.x) - (a.width + b.width) / 2
			local gapZ = math.abs(a.z - b.z) - (a.length + b.length) / 2
			if math.max(gapX, gapZ) < 8 then
				apart = false
				print("too close: " .. a.name .. " and " .. b.name)
			end
		end
	end
	check("training stations, shop, portal and reserved areas do not touch", apart)

	local landing = true
	for _, item in items do
		local gapX = math.abs(island.arrival.x - item.x) - item.width / 2
		local gapZ = math.abs(island.arrival.z - item.z) - item.length / 2
		if math.max(gapX, gapZ) < 6 then
			landing = false
			print("arrival too close to: " .. item.name)
		end
	end
	check("the arrival spot is clear of everything and away from the return portal", landing)
end
check("all training stations are treadmills for now (4 of them, grouped in one row)", #island.treadmills == 4 and island.treadmills[1].z == island.treadmills[4].z)

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
