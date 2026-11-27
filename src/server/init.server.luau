--!strict
-- Mog Wars server entry point. Systems expose init() then start(); this file runs them in order.
local Systems = script:WaitForChild("Systems")

-- Order matters: the map must exist before the capture system looks for zones.
local order = { "PlaceholderMap", "CaptureSystem" }

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
