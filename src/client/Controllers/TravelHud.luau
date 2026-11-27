--!strict
-- The big travel button, bottom right. On War Island it says TRAIN and sends you to Training Island; on
-- Training Island it says BACK TO WAR and sends you to your faction's front line. Display only: the server
-- checks every trip (and the portals work without this button). Hidden for brand-new players until the
-- first-session reveal reaches it; BACK TO WAR is always shown on Training Island.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local RevealRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RevealRules"))
local UiTheme = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("UiTheme"))

local TravelHud = {}

local player = Players.LocalPlayer
local button: TextButton
local toast: TextLabel
local toastUntil = 0

local MESSAGES: { [string]: string } = {
	in_duel = "Finish your mog-off first!",
	recently_hit = "Hold on, you just got hit!",
	too_soon = "Not so fast!",
	already_there = "You are already there.",
	not_ready = "Wait a second, still loading.",
	bad_input = "Something went wrong. Try again.",
}

local function update()
	local island = player:GetAttribute("Island")
	local onTraining = island == "training"
	if onTraining then
		button.Text = "BACK TO WAR"
		button.BackgroundColor3 = UiTheme.colors.green
		button.Visible = true
	else
		button.Text = "TRAIN"
		button.BackgroundColor3 = UiTheme.colors.orange
		button.Visible = RevealRules.visible("TrainButton", player:GetAttribute("RevealStage")) == true
	end
	toast.Visible = Workspace:GetServerTimeNow() < toastUntil
end

function TravelHud.init()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local request = remotes:WaitForChild("TravelRequest") :: RemoteEvent
	local result = remotes:WaitForChild("TravelResult") :: RemoteEvent

	local gui = Instance.new("ScreenGui")
	gui.Name = "TravelHud" -- not in RevealRules: this screen decides its own visibility
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	button = UiTheme.button(gui, "TRAIN", UiTheme.colors.orange, UDim2.new(0, 240, 0, 92))
	button.AnchorPoint = Vector2.new(1, 1)
	button.Position = UDim2.new(1, -16, 1, -16)
	button.Visible = false
	button.Activated:Connect(function()
		request:FireServer(if player:GetAttribute("Island") == "training" then "war" else "training")
	end)

	toast = Instance.new("TextLabel")
	toast.Text = "" -- never show Roblox's default placeholder text
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0.18, 0)
	toast.Size = UDim2.new(0, 360, 0, 60)
	toast.BackgroundColor3 = UiTheme.panel
	toast.TextColor3 = UiTheme.colors.yellow
	toast.Font = UiTheme.font
	toast.TextScaled = true
	toast.Visible = false
	toast.ZIndex = 5
	toast.Parent = gui
	UiTheme.round(toast)
	UiTheme.outlineBox(toast)

	result.OnClientEvent:Connect(function(ok: any, reason: any)
		if ok == true then
			return
		end
		toast.Text = MESSAGES[tostring(reason)] or "You can not go there right now."
		toastUntil = Workspace:GetServerTimeNow() + 2.5
	end)
end

function TravelHud.start()
	RunService.RenderStepped:Connect(update)
end

return TravelHud
