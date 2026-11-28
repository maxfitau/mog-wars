--!strict
-- Plain-Luau tests, no Roblox needed. Run from the repo root with the standalone Luau runtime:
--   luau tests/SeasonConfig.test.luau
-- STATUS: written but NOT yet run (no Luau runtime in the cloud session). Run it on a PC first.

local SeasonConfig = require("../src/shared/SeasonConfig")

local failures = 0

local function check(name: string, condition: boolean)
	if condition then
		print("PASS " .. name)
	else
		failures += 1
		print("FAIL " .. name)
	end
end

check("four seasons", #SeasonConfig.seasons == 4)
check("the current season is a real one", SeasonConfig.isValid(SeasonConfig.current))
check("winter is first", SeasonConfig.seasons[1].id == "winter")
check("lookup by id", (SeasonConfig.byId("autumn") :: any).name == "Autumn")
check("unknown id", SeasonConfig.byId("monsoon") == nil)
check("unknown is not valid", not SeasonConfig.isValid("monsoon"))
check("non-string is not valid", not SeasonConfig.isValid(5))

local ids: { [string]: boolean } = {}
local unique = true
for _, season in SeasonConfig.seasons do
	if ids[season.id] then
		unique = false
	end
	ids[season.id] = true
	check("name set for " .. season.id, #season.name > 0)
	check("accent is a colour for " .. season.id, #season.accent == 3)
end
check("ids are unique", unique)

check("next after winter", SeasonConfig.nextId("winter") == "spring")
check("next after autumn wraps", SeasonConfig.nextId("autumn") == "winter")
check("next of junk", SeasonConfig.nextId("zzz") == "winter")

local saved = SeasonConfig.current
SeasonConfig.current = "summer"
check("current season follows the one line", SeasonConfig.currentSeason().id == "summer")
SeasonConfig.current = "typo"
check("a typo falls back to the first season", SeasonConfig.currentSeason().id == "winter")
SeasonConfig.current = saved

if failures > 0 then
	error(("%d test(s) failed"):format(failures))
end
print("all SeasonConfig tests passed")
