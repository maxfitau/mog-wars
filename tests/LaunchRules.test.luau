--!strict
-- Plain-Luau tests, no Roblox needed: luau tests/LaunchRules.test.luau
-- STATUS: written but NOT yet run (no Luau runtime in the cloud session). Run it on the Mac first.

local LaunchRules = require("../src/shared/LaunchRules")
local MapLayout = require("../src/shared/MapLayout")
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

local GRAVITY = 196.2

check("short hops take the minimum time", LaunchRules.flightSeconds(20) == LaunchRules.MIN_FLIGHT_SECONDS)
check("long flights are capped", LaunchRules.flightSeconds(5000) == LaunchRules.MAX_FLIGHT_SECONDS)
check("nan distance is safe", LaunchRules.flightSeconds(0 / 0) == LaunchRules.MIN_FLIGHT_SECONDS)
check("a 110 stud flight takes 2 seconds", math.abs(LaunchRules.flightSeconds(110) - 2) < 1e-9)

-- the thrown player really lands on the target at the flight time
do
	local vx, vy, vz = LaunchRules.velocity(0, 35, 0, 90, 110, -60, GRAVITY, 2.5)
	local x, y, z = LaunchRules.position(0, 35, 0, vx, vy, vz, GRAVITY, 2.5)
	check("the parabola lands on the target", math.abs(x - 90) < 1e-6 and math.abs(y - 110) < 1e-6 and math.abs(z + 60) < 1e-6)
	check("the player is coming down when they land", vy - GRAVITY * 2.5 < 0)
end

-- every launch pad route on the map (between the islands) stays under the throw limit
do
	local islands: { { x: number, z: number, y: number, r: number } } = {}
	for _, base in MapLayout.bases do
		table.insert(islands, { x = base.x, z = base.z, y = MapLayout.baseIslandHeight, r = MapLayout.baseIslandRadius })
	end
	for _, territory in Territories.list do
		if territory.radius > 0 then
			table.insert(islands, { x = territory.x, z = territory.z, y = territory.height, r = territory.radius })
		end
	end
	local worst = 0
	for _, a in islands do
		for _, b in islands do
			local dx, dz = b.x - a.x, b.z - a.z
			local distance = math.sqrt(dx * dx + dz * dz) - a.r - b.r + 40 -- rim to rim, plus some slack
			if a ~= b and distance < 260 then -- only islands near enough to have a launch pad between them
				local t = LaunchRules.flightSeconds(math.max(distance, 10))
				local vx, vy, vz = LaunchRules.velocity(0, a.y + 3, 0, math.max(distance, 10), b.y + 3, 0, GRAVITY, t)
				worst = math.max(worst, LaunchRules.speed(vx, vy, vz))
			end
		end
	end
	check("no launch between islands is faster than the client allows", worst < LaunchRules.MAX_SPEED)
end

check("a 240 stud zipline at 60 studs a second takes 4 seconds", math.abs(LaunchRules.rideSeconds(240, 60) - 4) < 1e-9)
check("a zero speed zipline is safe", LaunchRules.rideSeconds(100, 0) == 0)

if failures > 0 then
	error(failures .. " test(s) failed")
end
print("All tests passed")
