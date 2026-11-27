--!strict
-- Mog Wars client entry point. The client only displays and asks; the server decides.
-- Controllers expose init() then start(); this file runs them in order.
local Controllers = script:WaitForChild("Controllers")

local order = { "CaptureHud", "PointsHud", "WarHud", "ShoveController" }

local loaded = {}
for _, name in order do
	local controller = require(Controllers:WaitForChild(name)) :: { init: () -> (), start: () -> () }
	table.insert(loaded, controller)
end
for _, controller in loaded do
	controller.init()
end
for _, controller in loaded do
	controller.start()
end

print("[mog-wars] client started")
