--!strict
-- Plain-Luau tests, no Roblox needed. Run from the repo root with the standalone Luau runtime:
--   luau tests/SpawnRules.test.luau
-- STATUS: written but NOT yet run (no Luau runtime in the cloud session). Run it on a PC first.
-- Only flags on the ground are used for front-line spawning (raised flags such as the lighthouse top are skipped).

local MapLayout = require("../src/shared/MapLayout")
local SpawnRules = require("../src/shared/SpawnRules")
local Territories = require("../src/shared/Territories")

local failures = 0

local function check(name: string, condition: boolean)
	if condition then
		print("PASS " .. name)
	else
		failures += 1
		print("FAIL " .. name)
	end
end

-- every ground flag, with an owner taken from `owners` (keyed by the flag's part name)
local ground = {}
for _, entry in Territories.allFlags() do
	-- front-line spawns use the flag's open-ground approach point when it has one (raised and indoor flags do)
	local spot = entry.flag.approach or entry.flag
	if entry.flag.approach or entry.flag.y <= 3 then
		table.insert(ground, { name = Territories.partName(entry.territory, entry.index), flag = { x = spot.x, z = spot.z, size = entry.flag.size } })
	end
end

local function zonesOwnedBy(owners: { [string]: number }): { SpawnRules.ZoneInfo }
	local list = {}
	for _, item in ground do
		table.insert(list, { x = item.flag.x, z = item.flag.z, size = item.flag.size, owner = owners[item.name] or 0 })
	end
	return list
end

local function insideAnyFlag(x: number, z: number): boolean
	for _, item in ground do
		if math.abs(x - item.flag.x) <= item.flag.size / 2 and math.abs(z - item.flag.z) <= item.flag.size / 2 then
			return true
		end
	end
	return false
end

local base1 = MapLayout.bases[1]

local function groundByName(name: string): { x: number, z: number, size: number }
	for _, item in ground do
		if item.name == name then
			return item.flag
		end
	end
	error("no ground flag named " .. name)
end

do
	local x, z, kind = SpawnRules.spawnPoint(1, zonesOwnedBy({}), base1.x, base1.z, 0)
	check("a faction with no flags spawns at its base", kind == "base" and x == base1.x and z == base1.z)
end

-- the front line is the owned flag nearest the centre
do
	local zones = zonesOwnedBy({ Flag_gigachad_gate_1 = 1, Flag_locked_in_lighthouse_1 = 1, Flag_gigachad_gate_2 = 2 })
	local front = SpawnRules.frontZone(1, zones)
	local nearest = groundByName("Flag_gigachad_gate_1") -- closer to the centre than the lighthouse flag
	check(
		"the front flag is the owned flag nearest the centre",
		front ~= nil and (front :: SpawnRules.ZoneInfo).x == nearest.x and (front :: SpawnRules.ZoneInfo).z == nearest.z
	)
	check("another faction's flags are not used", SpawnRules.frontZone(3, zones) == nil)
end

-- the spawn point sits outside the flag on the side facing the base
do
	local flag = groundByName("Flag_gigachad_gate_1")
	local zones = zonesOwnedBy({ Flag_gigachad_gate_1 = 1 })
	local x, z, kind = SpawnRules.spawnPoint(1, zones, base1.x, base1.z, 2) -- slot 2 has no sideways shift
	check("an owned flag gives a flag spawn", kind == "zone")
	local dx, dz = x - flag.x, z - flag.z
	check("the spawn is a few studs outside the flag edge", math.max(math.abs(dx), math.abs(dz)) - flag.size / 2 >= 4)
	local toBaseX, toBaseZ = base1.x - flag.x, base1.z - flag.z
	check("the spawn is on the side facing the faction base", dx * toBaseX + dz * toBaseZ > 0)
	check("the spawn is not inside any flag", not insideAnyFlag(x, z))
end

-- every owned ground flag, for every base and slot, gives a spot outside all flags and on the plate
do
	local clear = true
	for _, item in ground do
		local zones = zonesOwnedBy({ [item.name] = 1 })
		for _, base in MapLayout.bases do
			for slot = 0, 4 do
				local x, z = SpawnRules.spawnPoint(1, zones, base.x, base.z, slot)
				if insideAnyFlag(x, z) then
					clear = false
					print("spawn inside a flag for " .. item.name)
				end
				if math.abs(x) > MapLayout.baseplateSize / 2 or math.abs(z) > MapLayout.baseplateSize / 2 then
					clear = false
				end
			end
		end
	end
	check("no spawn spot lands inside a flag or off the plate", clear)
end

-- slots spread players out and repeat
do
	local zones = zonesOwnedBy({ Flag_gigachad_gate_1 = 1 })
	local x0, z0 = SpawnRules.spawnPoint(1, zones, base1.x, base1.z, 0)
	local x1, z1 = SpawnRules.spawnPoint(1, zones, base1.x, base1.z, 1)
	local x5, z5 = SpawnRules.spawnPoint(1, zones, base1.x, base1.z, 5)
	check("different slots give different spots", x0 ~= x1 or z0 ~= z1)
	check("slots repeat every five", x0 == x5 and z0 == z5)
end

-- bad input does not break it
do
	local zones: { SpawnRules.ZoneInfo } = { { x = 0 / 0, z = 0, size = 28, owner = 1 } }
	check("a flag with nan position is ignored", SpawnRules.frontZone(1, zones) == nil)
	local x, z, kind = SpawnRules.spawnPoint(1, { { x = 5, z = 5, size = 28, owner = 1 } }, 5, 5, 0)
	check("a base on top of the flag still gives a finite spawn", kind == "zone" and x == x and z == z)
end

if failures > 0 then
	error(failures .. " test(s) failed")
end
print("All tests passed")
