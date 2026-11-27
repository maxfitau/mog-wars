--!strict
-- Pure helpers for the two islands (War Island and Training Island). No Roblox calls.

export type Island = { x: number, z: number, size: number }

local IslandRules = {}

local function finite(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge
end

-- Which island a point on the ground is on: "training" inside the Training Island square, otherwise "war".
function IslandRules.islandAt(x: number, z: number, training: Island): string
	if not (finite(x) and finite(z)) then
		return "war"
	end
	local half = training.size / 2
	if math.abs(x - training.x) <= half and math.abs(z - training.z) <= half then
		return "training"
	end
	return "war"
end

-- The world position of a point given in Training Island's local coordinates.
function IslandRules.worldPoint(training: Island, localX: number, localZ: number): (number, number)
	return training.x + localX, training.z + localZ
end

-- May a player travel? Returns ok and a stable reason: "bad_input", "already_there", "in_duel", "recently_hit", "too_soon".
function IslandRules.canTravel(
	destination: any,
	currentIsland: string,
	inDuel: boolean,
	secondsSinceLastTravel: number,
	secondsOfPenaltyLeft: number,
	cooldownSeconds: number
): (boolean, string?)
	if destination ~= "training" and destination ~= "war" then
		return false, "bad_input"
	end
	if (destination == "training") == (currentIsland == "training") then
		return false, "already_there"
	end
	if inDuel then
		return false, "in_duel"
	end
	if secondsOfPenaltyLeft > 0 then
		return false, "recently_hit" -- no escaping right after being shoved or losing a mog-off
	end
	if not finite(secondsSinceLastTravel) or secondsSinceLastTravel < cooldownSeconds then
		return false, "too_soon"
	end
	return true, nil
end

return IslandRules
