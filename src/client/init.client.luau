--!strict
-- Mog Wars client entry point. The client only displays and asks; the server decides.
-- Controllers expose init() then start(); this file runs them in order.
local Controllers = script:WaitForChild("Controllers")
local Features = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Features"))

local order = { "CaptureHud", "PointsHud", "WarHud", "ShoveController", "MogOffController", "RankHud", "BoxHud", "UnitsHud", "RewardsHud", "TrainingHud", "ShopHud" }
if Features.seasons then
	table.insert(order, "SeasonHud") -- switched off at launch
end
table.insert(order, "PopupController")
table.insert(order, "AssetCheckController")
table.insert(order, "TravelHud")
table.insert(order, "TutorialHint")
table.insert(order, "RevealController") -- last: it shows each screen only once the player has reached it

-- Each controller is loaded, initialised and started on its own, so one error does not stop the others;
-- look for "[mog-wars] FAILED" in the Output window.
type Controller = { init: () -> (), start: () -> () }

local loaded: { { name: string, controller: Controller } } = {}
for _, name in order do
	local ok, result = pcall(function()
		return require(Controllers:WaitForChild(name))
	end)
	if ok then
		table.insert(loaded, { name = name, controller = result :: Controller })
	else
		warn(("[mog-wars] FAILED to load %s: %s"):format(name, tostring(result)))
	end
end
for _, entry in loaded do
	local ok, err = pcall(entry.controller.init)
	if not ok then
		warn(("[mog-wars] FAILED in %s.init: %s"):format(entry.name, tostring(err)))
	end
end
for _, entry in loaded do
	local ok, err = pcall(entry.controller.start)
	if not ok then
		warn(("[mog-wars] FAILED in %s.start: %s"):format(entry.name, tostring(err)))
	end
end

print(("[mog-wars] client started (%d of %d screens loaded)"):format(#loaded, #order))
