--!strict
-- Plain-Luau tests, no Roblox needed. Run from the repo root with the standalone Luau runtime:
--   luau tests/IslandRules.test.luau
-- STATUS: written but NOT yet run (no Luau runtime in the cloud session). Run it on a PC first.

local IslandRules = require("../src/shared/IslandRules")
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

local island = MapLayout.trainingIsland

check("the middle of War Island is on war", IslandRules.islandAt(0, 0, island) == "war")
check("every war base is on war", (function()
	for _, base in MapLayout.bases do
		if IslandRules.islandAt(base.x, base.z, island) ~= "war" then
			return false
		end
	end
	return true
end)())
check("every zone is on war", (function()
	for _, zone in MapLayout.zones do
		if IslandRules.islandAt(zone.x, zone.z, island) ~= "war" then
			return false
		end
	end
	return true
end)())
check("the centre of Training Island is on training", IslandRules.islandAt(island.x, island.z, island) == "training")
check("the edge of Training Island counts", IslandRules.islandAt(island.x + island.size / 2, island.z, island) == "training")
check("just past the edge is war", IslandRules.islandAt(island.x + island.size / 2 + 1, island.z, island) == "war")
check("bad numbers count as war", IslandRules.islandAt(0 / 0, 0, island) == "war" and IslandRules.islandAt(math.huge, 0, island) == "war")

local wx, wz = IslandRules.worldPoint(island, island.arrival.x, island.arrival.z)
check("the arrival spot is on Training Island", IslandRules.islandAt(wx, wz, island) == "training")

-- travel rules
local ok, reason = IslandRules.canTravel("training", "war", false, 10, 0, 3)
check("going to training from war is allowed", ok and reason == nil)
ok, reason = IslandRules.canTravel("war", "training", false, 10, 0, 3)
check("going back to war from training is allowed", ok)
ok, reason = IslandRules.canTravel("training", "training", false, 10, 0, 3)
check("you cannot travel to where you already are", not ok and reason == "already_there")
ok, reason = IslandRules.canTravel("war", "war", false, 10, 0, 3)
check("you cannot go to war when already there", not ok and reason == "already_there")
ok, reason = IslandRules.canTravel("moon", "war", false, 10, 0, 3)
check("an unknown destination is refused", not ok and reason == "bad_input")
ok, reason = IslandRules.canTravel(5, "war", false, 10, 0, 3)
check("a non-string destination is refused", not ok and reason == "bad_input")
ok, reason = IslandRules.canTravel("training", "war", true, 10, 0, 3)
check("no travel during a mog-off", not ok and reason == "in_duel")
ok, reason = IslandRules.canTravel("training", "war", false, 10, 2, 3)
check("no travel right after being hit", not ok and reason == "recently_hit")
ok, reason = IslandRules.canTravel("training", "war", false, 1, 0, 3)
check("travel has a cooldown", not ok and reason == "too_soon")
ok, reason = IslandRules.canTravel("training", "war", false, 0 / 0, 0, 3)
check("a bad time is refused", not ok and reason == "too_soon")

if failures > 0 then
	error(failures .. " test(s) failed")
end
print("All tests passed")
