--!strict
-- Mog Wars client entry point. The client only displays and asks; the server decides.
-- Controllers expose init() then start(); this file runs them in order.
local Controllers = script:WaitForChild("Controllers")
local Features = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Features"))

local order = { "CaptureHud", "PointsHud", "WarHud", "ShoveController", "MogOffController", "RankHud", "BoxHud", "UnitsHud", "RewardsHud", "TrainingHud", "ShopHud" }
if Features.seasons then
	table.insert(order, "SeasonHud") -- switched off at launch
end
table.insert(order, "TravelHud")
table.insert(order, "TutorialHint")
table.insert(order, "RevealController") -- last: it shows each screen only once the player has reached it

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
