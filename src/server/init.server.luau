--!strict
-- Mog Wars server entry point. Systems expose init() then start(); this file runs them in order.
-- Each system is loaded, initialised and started on its own, so if one has an error the others (and the map)
-- still come up, and the Output window says which one failed: look for "[mog-wars] FAILED".
local Systems = script:WaitForChild("Systems")

-- Order matters: factions create the Teams first, then the map builds matching spawns, then captures start.
local order = { "DataService", "PopupSystem", "FriendService", "FactionSystem", "PlaceholderMap", "BotService", "CaptureSystem", "SpawnSystem", "ShoveSystem", "MogOffSystem", "RankSystem", "BoxSystem", "UnitSystem", "RewardsSystem", "SeasonService", "TrainingSystem", "ShopSystem", "TravelSystem", "TerritorySystem", "AssetCheckSystem", "WarSystem" }

type System = { init: () -> (), start: () -> () }

local loaded: { { name: string, system: System } } = {}
for _, name in order do
	local ok, result = pcall(function()
		return require(Systems:WaitForChild(name))
	end)
	if ok then
		table.insert(loaded, { name = name, system = result :: System })
	else
		warn(("[mog-wars] FAILED to load %s: %s"):format(name, tostring(result)))
	end
end
for _, entry in loaded do
	local ok, err = pcall(entry.system.init)
	if not ok then
		warn(("[mog-wars] FAILED in %s.init: %s"):format(entry.name, tostring(err)))
	end
end
for _, entry in loaded do
	local ok, err = pcall(entry.system.start)
	if not ok then
		warn(("[mog-wars] FAILED in %s.start: %s"):format(entry.name, tostring(err)))
	end
end

print(("[mog-wars] server started (%d of %d systems loaded)"):format(#loaded, #order))
