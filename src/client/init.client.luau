--!strict
-- Mog Wars client entry point. The client only displays and asks; the server decides.
-- Controllers expose init() then start(); this file runs them in order.
local Controllers = script:WaitForChild("Controllers")
local Features = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Features"))

-- Only the screens for switched-on features are loaded (see src/shared/Features.luau). The HUD is three things:
-- aura and rank (top left), the war timer and team scores with the capture bar (top centre), and the shove button
-- (bottom right). The shop and the daily reward are the only other screens.
local order = { "SoundController", "AuraHud", "WarHud", "CaptureHud", "ShoveController", "PopupController", "ResultsHud", "TutorialHint", "SignFader" }
local function add(name: string, on: boolean)
	if on then
		table.insert(order, name)
	end
end
add("ZiplineController", Features.ziplines)
add("AbilityController", Features.abilities)
add("GliderController", Features.rifts)
add("UnlockCard", Features.abilities)
add("MissionHud", true)
add("EventController", Features.events)
add("TerritoryBanner", true)
add("FlagVisuals", true)
add("MoodController", true)
add("ActivityPing", true)
add("WeaponController", Features.weapons)
add("WeaponIndex", Features.weapons)
add("EventCountdown", Features.weeklyEvents)
add("ReactionController", Features.reactions)
add("QuestBoard", Features.dailyQuests)
add("SeasonPassHud", Features.seasonPass)
add("MinimapHud", true)
add("QuestPanel", true)
add("AchievementCards", true)
add("ChestCard", true)
add("ShopHud", Features.cosmeticShop)
add("RewardsHud", Features.dailyStreak)
add("CombatController", Features.combat)
add("KillFeed", Features.combat)
add("MogOffController", Features.mogOffs)
add("BoxHud", Features.boxes)
add("UnitsHud", Features.units)
add("TrainingHud", Features.trainingIsland)
add("TravelHud", Features.trainingIsland)
add("SeasonHud", Features.seasons)
add("RevealController", Features.discoveryCards) -- last: it shows each screen only once the player has reached it

-- Each controller is loaded, initialised and started on its own, so one error does not stop the others;
-- look for "[mog-wars] FAILED" in the Output window.
type Controller = { init: () -> (), start: () -> () }

local loaded: { { name: string, controller: Controller } } = {}
for _, name in order do
	local ok, result = pcall(function()
		return require(Controllers:WaitForChild(name, 10) :: ModuleScript)
	end)
	if ok then
		table.insert(loaded, { name = name, controller = result :: Controller })
	else
		warn(("[mog-wars] FAILED to load %s: %s"):format(name, tostring(result)))
	end
end
-- each controller starts on its own thread, so one that waits on something that never arrives cannot block the HUD
local pendingInit = #loaded
for _, entry in loaded do
	task.spawn(function()
		local ok, err = pcall(entry.controller.init)
		if not ok then
			warn(("[mog-wars] FAILED in %s.init: %s"):format(entry.name, tostring(err)))
		end
		pendingInit -= 1
	end)
end
local waited = 0
while pendingInit > 0 and waited < 8 do
	task.wait(0.1)
	waited += 0.1
end
for _, entry in loaded do
	task.spawn(function()
		local ok, err = pcall(entry.controller.start)
		if not ok then
			warn(("[mog-wars] FAILED in %s.start: %s"):format(entry.name, tostring(err)))
		end
	end)
end

print(("[mog-wars] client started (%d of %d screens loaded)"):format(#loaded, #order))
