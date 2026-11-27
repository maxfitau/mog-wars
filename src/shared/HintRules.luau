--!strict
-- Pure maths for the first-session hint: which zone is nearest, and which way to point an arrow at it.

local HintRules = {}

local function finite(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge
end

-- Angle in degrees to turn an up-pointing arrow so it points at a target, given the way the player is
-- facing. 0 is straight ahead, 90 is to the right, -90 to the left, 180 behind. All inputs are flat (x, z)
-- directions on the ground; they do not need to be unit length.
function HintRules.arrowAngle(targetX: number, targetZ: number, lookX: number, lookZ: number): number
	if not (finite(targetX) and finite(targetZ) and finite(lookX) and finite(lookZ)) then
		return 0
	end
	local lookLength = math.sqrt(lookX * lookX + lookZ * lookZ)
	if lookLength < 1e-6 or (targetX == 0 and targetZ == 0) then
		return 0
	end
	local forwardX, forwardZ = lookX / lookLength, lookZ / lookLength
	local rightX, rightZ = -forwardZ, forwardX
	local ahead = targetX * forwardX + targetZ * forwardZ
	local right = targetX * rightX + targetZ * rightZ
	return math.deg(math.atan2(right, ahead))
end

-- The index of the zone nearest to (x, z), or nil if there are none. Ties go to the earlier one.
function HintRules.nearest(x: number, z: number, zones: { { x: number, z: number } }): number?
	if not (finite(x) and finite(z)) then
		return nil
	end
	local best, bestDistance = nil, math.huge
	for index, zone in zones do
		if finite(zone.x) and finite(zone.z) then
			local dx, dz = zone.x - x, zone.z - z
			local distance = dx * dx + dz * dz
			if distance < bestDistance then
				best, bestDistance = index, distance
			end
		end
	end
	return best
end

return HintRules
