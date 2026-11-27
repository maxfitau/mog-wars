--!strict
-- Plain-Luau tests, no Roblox needed. Run from the repo root with the standalone Luau runtime:
--   luau tests/RevealRules.test.luau
-- STATUS: written but NOT yet run (no Luau runtime in the cloud session). Run it on a PC first.

local RevealRules = require("../src/shared/RevealRules")
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

check("a new player is at stage 0", RevealRules.stage(0, 0) == 0)
check("the first capture reaches stage 1", RevealRules.stage(1, 0) == 1)
check("the first finished war reaches stage 2", RevealRules.stage(0, 1) == 2 and RevealRules.stage(5, 1) == 2)
check("two wars reach stage 3", RevealRules.stage(9, 2) == 3)
check("three wars reach the top stage", RevealRules.stage(9, 3) == RevealRules.MAX_STAGE and RevealRules.stage(9, 300) == RevealRules.MAX_STAGE)
check("bad numbers count as zero", RevealRules.stage(0 / 0, -4) == 0 and RevealRules.stage(nil, "x") == 0 and RevealRules.stage(math.huge, 0) == 0)

-- a brand-new player sees only the zone bar
local visibleAtZero = {}
for screen in RevealRules.screens do
	if RevealRules.visible(screen, 0) then
		table.insert(visibleAtZero, screen)
	end
end
check("a brand-new player sees only the zone bar", #visibleAtZero == 1 and visibleAtZero[1] == "CaptureHud")
check("every screen is visible at the top stage", (function()
	for screen in RevealRules.screens do
		if not RevealRules.visible(screen, RevealRules.MAX_STAGE) then
			return false
		end
	end
	return true
end)())
check("screens appear in order, never disappear", (function()
	for screen, needed in RevealRules.screens do
		for stage = 0, RevealRules.MAX_STAGE do
			local shown = RevealRules.visible(screen, stage)
			if (stage >= needed) ~= shown then
				return false
			end
		end
	end
	return true
end)())
check("unknown screens are left alone", RevealRules.visible("SomethingElse", 0) == nil)
check("the mog-off screen is never hidden", RevealRules.screens.MogOffHud == nil)

-- launch switches match the owner's launch list
check("launch has the war, ranks, boxes, units, treadmill, streak and shop", Features.war and Features.ranks and Features.boxes and Features.units and Features.treadmill and Features.dailyStreak and Features.cosmeticShop)
check("seasons and the squad bonus are switched off at launch", not Features.seasons and not Features.squadBonus)
check("features that are not built are off", not Features.trainingStations and not Features.prestige and not Features.arena)

if failures > 0 then
	error(failures .. " test(s) failed")
end
print("All tests passed")
