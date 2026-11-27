--!strict
-- Floating number pop-ups: "+300 aura", "+200 Mog Points", "+1 Diamond Box". The server sends a kind and an
-- amount (PopupSystem); this only draws them. Bigger numbers get bigger text and a colour tier: white under 1,000,
-- gold under a million, purple above (NumberFormat). Short suffixes: K, M, B, T, Qa. At most a few are on screen
-- at once and they move gently (no flashing), so they stay readable for young players.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("EconomyConfig"))
local NumberFormat = require(Shared:WaitForChild("NumberFormat"))
local UiTheme = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("UiTheme"))

local PopupController = {}

local MAX_ON_SCREEN = 6
local LIFETIME_SECONDS = 1.8

local TIER_COLORS = {
	white = Color3.fromRGB(255, 255, 255),
	gold = Color3.fromRGB(255, 215, 60),
	purple = Color3.fromRGB(190, 110, 255),
}

local gui: ScreenGui
local active: { TextLabel } = {}

local function show(text: string, amount: number)
	-- drop the oldest if too many are showing
	while #active >= MAX_ON_SCREEN do
		local oldest = table.remove(active, 1)
		if oldest then
			oldest:Destroy()
		end
	end
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Size = UDim2.new(0, 360, 0, math.floor(44 * NumberFormat.sizeScale(amount)))
	label.Position = UDim2.new(0.5, 0, 0.62, -(#active * 36)) -- stacked, so popups that arrive together do not overlap
	label.BackgroundTransparency = 1
	label.Font = UiTheme.font
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = TIER_COLORS[NumberFormat.tier(amount)] or TIER_COLORS.white
	label.TextStrokeColor3 = UiTheme.outline
	label.TextStrokeTransparency = 0
	label.Parent = gui
	table.insert(active, label)

	local tween = TweenService:Create(label, TweenInfo.new(LIFETIME_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = label.Position - UDim2.new(0, 0, 0, 90),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	tween.Completed:Connect(function()
		local at = table.find(active, label)
		if at then
			table.remove(active, at)
		end
		label:Destroy()
	end)
	tween:Play()
end

function PopupController.init()
	gui = Instance.new("ScreenGui")
	gui.Name = "RewardPopups" -- not in RevealRules: pop-ups are never hidden by it
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RewardPopup") :: RemoteEvent
	remote.OnClientEvent:Connect(function(kind: any, amount: any, detail: any)
		if type(amount) ~= "number" or amount ~= amount or amount <= 0 then
			return
		end
		local number = NumberFormat.format(amount)
		if kind == "points" then
			show(("+%s Mog Points"):format(number), amount)
		elseif kind == "aura" then
			show(("+%s aura"):format(number), amount)
		elseif kind == "box" then
			local tier = if type(detail) == "string" then Config.boxes.tiers[detail] else nil
			show(("+%s %s"):format(number, if tier then tier.displayName else "Box"), amount * 100) -- boxes always look special
		end
	end)
end

function PopupController.start() end

return PopupController
