--!strict
-- Mog Wars server entry point. Systems expose init() then start(); this file runs them in order.
local Systems = script:WaitForChild("Systems")

-- Order matters: factions create the Teams first, then the map builds matching spawns, then captures start.
local order = { "DataService", "FactionSystem", "PlaceholderMap", "CaptureSystem", "ShoveSystem", "MogOffSystem", "RankSystem", "WarSystem" }

local loaded = {}
for _, name in order do
	local system = require(Systems:WaitForChild(name)) :: { init: () -> (), start: () -> () }
	table.insert(loaded, system)
end
for _, system in loaded do
	system.init()
end
for _, system in loaded do
	system.start()
end

print("[mog-wars] server started")
