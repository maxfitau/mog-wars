--!strict
-- Pure maths for launch pads and ziplines, so it can be tested without Roblox.
-- A launch pad throws a player along a parabola that lands on a chosen spot on another island: pick a flight time, then
-- the sideways speed is distance / time and the upward speed is whatever gravity needs to bring the player down on the
-- target at exactly that time. A zipline carries a player in a straight line at a steady speed.

local LaunchRules = {}

LaunchRules.MIN_FLIGHT_SECONDS = 1.8
LaunchRules.MAX_FLIGHT_SECONDS = 3.6
LaunchRules.SIDEWAYS_SPEED = 55 -- studs per second, used to pick a flight time that suits the distance
LaunchRules.MAX_SPEED = 380 -- the client refuses throws of 400 or more

-- How long a flight over `distance` studs (flat) should take.
function LaunchRules.flightSeconds(distance: number): number
	if distance ~= distance then
		return LaunchRules.MIN_FLIGHT_SECONDS
	end
	return math.clamp(distance / LaunchRules.SIDEWAYS_SPEED, LaunchRules.MIN_FLIGHT_SECONDS, LaunchRules.MAX_FLIGHT_SECONDS)
end

-- The launch velocity (vx, vy, vz) from a point to a point under `gravity`, arriving after `seconds`.
function LaunchRules.velocity(fromX: number, fromY: number, fromZ: number, toX: number, toY: number, toZ: number, gravity: number, seconds: number): (number, number, number)
	local t = math.max(seconds, 0.1)
	return (toX - fromX) / t, ((toY - fromY) + 0.5 * gravity * t * t) / t, (toZ - fromZ) / t
end

function LaunchRules.speed(vx: number, vy: number, vz: number): number
	return math.sqrt(vx * vx + vy * vy + vz * vz)
end

-- Where a thrown player is after `t` seconds.
function LaunchRules.position(fromX: number, fromY: number, fromZ: number, vx: number, vy: number, vz: number, gravity: number, t: number): (number, number, number)
	return fromX + vx * t, fromY + vy * t - 0.5 * gravity * t * t, fromZ + vz * t
end

-- Seconds to ride a zipline of `length` studs at `speed`.
function LaunchRules.rideSeconds(length: number, speed: number): number
	if speed <= 0 then
		return 0
	end
	return length / speed
end

return LaunchRules
