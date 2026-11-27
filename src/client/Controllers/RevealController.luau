--!strict
-- Shows the game gradually. A brand-new player sees only the zone bar. The server works out a "RevealStage"
-- from how much the player has done (RevealRules) and mirrors it to the player; this controller switches
-- each screen on when the stage reaches it and never switches one off again as the player progresses.
-- Display only: hiding a screen takes nothing away from the server.

local Players = game:GetService("Players")

local RevealRules = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("RevealRules"))

local RevealController = {}

local player = Players.LocalPlayer

local function apply()
	local stage = player:GetAttribute("RevealStage")
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return
	end
	for _, gui in playerGui:GetChildren() do
		if gui:IsA("ScreenGui") then
			local shown = RevealRules.visible(gui.Name, stage)
			if shown ~= nil then
				gui.Enabled = shown
			end
		end
	end
end

function RevealController.init() end

function RevealController.start()
	local playerGui = player:WaitForChild("PlayerGui")
	player:GetAttributeChangedSignal("RevealStage"):Connect(apply)
	playerGui.ChildAdded:Connect(function()
		task.defer(apply)
	end)
	apply()
end

return RevealController
