--!strict
-- Plain-Luau tests, no Roblox needed: luau tests/Features.test.luau
-- STATUS: written but NOT yet run (no Luau runtime in the cloud session). Run it on the Mac first.
-- The simple game: only the war, shove, ranks (by aura), the daily reward, the shop, bots and speed pads are ON.

local Features = require("../src/shared/Features")

local failures = 0
local function check(name: string, condition: boolean)
	if condition then
		print("PASS " .. name)
	else
		failures += 1
		print("FAIL " .. name)
	end
end

for _, name in { "war", "shove", "ranks", "dailyStreak", "cosmeticShop", "bots", "speedPads", "launchPads", "ziplines", "abilities", "moglings", "stashes", "dash", "overtime", "stealing", "rifts" } do
	check(name .. " is ON", (Features :: any)[name] == true)
end
for _, name in {
	"combat", "mogOffs", "mogOffsInWar", "trainingIsland", "treadmill", "trainingStations", "boxes", "units", "prestige",
	"arena", "pickups", "airshipTaxis", "tankMode", "discoveryCards", "territoryTrickle", "seasons", "mogPoints", "squadBonus", "friendPlacement", "barracks",
} do
	check(name .. " is OFF", (Features :: any)[name] == false)
end

if failures > 0 then
	error(failures .. " test(s) failed")
end
print("All tests passed")
