--!strict
-- Plain-Luau tests, no Roblox needed. Run from the repo root with the standalone Luau runtime:
--   luau tests/SpawnRules.test.luau
-- STATUS: written but NOT yet run (no Luau runtime in the cloud session). Run it on a PC first.

local MapLayout = require("../src/shared/MapLayout")
local SpawnRules = require("../src/shared/SpawnRules")

local failures = 0

local function check(name: string, condition: boolean)
	if condition then
		print("PASS " .. name)
	else
		failures += 1
		print("FAIL " .. name)
	end
end

local function zonesOwnedBy(owners: { [string]: number }): { SpawnRules.ZoneInfo }
	local list = {}
	for _, spec in MapLayout.zones do
		table.insert(list, { x = spec.x, z = spec.z, size = spec.size, owner = owners[spec.name] or 0 })
	end
	return list
end

local base1 = MapLayout.bases[1]

-- no zones owned: spawn at the base
do
	local x, z, kind = SpawnRules.spawnPoint(1, zonesOwnedBy({}), base1.x, base1.z, 0)
	check("a faction with no zones spawns at its base", kind == "base" and x == base1.x and z == base1.z)
end

-- front zone is the owned zone nearest the centre
do
	local zones = zonesOwnedBy({ Zone_NorthWest = 1, Zone_North = 1, Zone_East = 2 })
	local front = SpawnRules.frontZone(1, zones)
	check("the front zone is the owned zone nearest the centre", front ~= nil and (front :: SpawnRules.ZoneInfo).x == 0 and (front :: SpawnRules.ZoneInfo).z == -60)
	check("another faction's zones are not used", (SpawnRules.frontZone(3, zones)) == nil)
end

-- the spawn point sits outside the zone on the side facing the base
do
	local zones = zonesOwnedBy({ Zone_North = 1 })
	local x, z, kind = SpawnRules.spawnPoint(1, zones, base1.x, base1.z, 2) -- slot 2 has no sideways shift
	check("owned zone gives a zone spawn", kind == "zone")
	local dx, dz = x - 0, z - (-60)
	check("the spawn is a few studs outside the zone edge", math.max(math.abs(dx), math.abs(dz)) - 28 / 2 >= 4)
	local toBaseX, toBaseZ = base1.x - 0, base1.z - (-60)
	check("the spawn is on the side facing the faction base", dx * toBaseX + dz * toBaseZ > 0)
	check("the spawn is not inside any zone", (function()
		for _, spec in MapLayout.zones do
			if math.abs(x - spec.x) <= spec.size / 2 and math.abs(z - spec.z) <= spec.size / 2 then
				return false
			end
		end
		return true
	end)())
end

-- every owned zone, for every base and slot, gives a spot outside all zones and on the plate
do
	local clear = true
	for _, owned in MapLayout.zones do
		local zones = zonesOwnedBy({ [owned.name] = 1 })
		for _, base in MapLayout.bases do
			for slot = 0, 4 do
				local x, z = SpawnRules.spawnPoint(1, zones, base.x, base.z, slot)
				for _, spec in MapLayout.zones do
					if math.abs(x - spec.x) <= spec.size / 2 and math.abs(z - spec.z) <= spec.size / 2 then
						clear = false
					end
				end
				if math.abs(x) > MapLayout.baseplateSize / 2 or math.abs(z) > MapLayout.baseplateSize / 2 then
					clear = false
				end
			end
		end
	end
	check("no spawn spot lands inside a zone or off the plate", clear)
end

-- slots spread players out and repeat
do
	local zones = zonesOwnedBy({ Zone_North = 1 })
	local x0, z0 = SpawnRules.spawnPoint(1, zones, base1.x, base1.z, 0)
	local x1, z1 = SpawnRules.spawnPoint(1, zones, base1.x, base1.z, 1)
	local x5, z5 = SpawnRules.spawnPoint(1, zones, base1.x, base1.z, 5)
	check("different slots give different spots", x0 ~= x1 or z0 ~= z1)
	check("slots repeat every five", x0 == x5 and z0 == z5)
end

-- bad input does not break it
do
	local zones: { SpawnRules.ZoneInfo } = { { x = 0 / 0, z = 0, size = 28, owner = 1 } }
	check("a zone with nan position is ignored", SpawnRules.frontZone(1, zones) == nil)
	local x, z, kind = SpawnRules.spawnPoint(1, { { x = 5, z = 5, size = 28, owner = 1 } }, 5, 5, 0)
	check("a base on top of the zone still gives a finite spawn", kind == "zone" and x == x and z == z)
end

if failures > 0 then
	error(failures .. " test(s) failed")
end
print("All tests passed")
