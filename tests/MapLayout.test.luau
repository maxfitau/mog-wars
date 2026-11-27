--!strict
-- Plain-Luau tests, no Roblox needed. Run from the repo root with the standalone Luau runtime:
--   luau tests/MapLayout.test.luau
-- STATUS: written but NOT yet run (no Luau runtime in the cloud session). Run it on a PC first.
-- The territories and flags are tested in tests/Territories.test.luau.

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

local half = MapLayout.baseplateSize / 2

-- four corner bases, on the plate
check("one home base per faction", #MapLayout.bases == 4)
do
	local onPlate = true
	local corners = true
	for _, base in MapLayout.bases do
		if math.abs(base.x) + MapLayout.baseSize / 2 > half or math.abs(base.z) + MapLayout.baseSize / 2 > half then
			onPlate = false
		end
		if math.abs(base.x) < half * 0.6 or math.abs(base.z) < half * 0.6 then
			corners = false
		end
	end
	check("bases are on the baseplate", onPlate)
	check("the bases are in the four corners", corners)
end

-- one portal to Training Island, at the top (north) edge, on the plate
check("one portal on War Island", #MapLayout.warPortals == 1)
do
	local portal = MapLayout.warPortals[1]
	check("the portal is at the top edge, in the middle", portal.z < -half * 0.8 and portal.x == 0)
	check("the portal is on the plate", math.abs(portal.z) + portal.size / 2 <= half)
	local clear = true
	for _, base in MapLayout.bases do
		local gapX = math.abs(portal.x - base.x) - (portal.size + MapLayout.baseSize) / 2
		local gapZ = math.abs(portal.z - base.z) - (portal.size + MapLayout.baseSize) / 2
		if math.max(gapX, gapZ) < 8 then
			clear = false
		end
	end
	check("the portal is clear of every base", clear)
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
