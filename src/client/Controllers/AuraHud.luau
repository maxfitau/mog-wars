--!strict
-- Top left: your aura (your score), your rank and a bar that fills toward the next rank. Display only: the server owns
-- the numbers and mirrors them to the player's "Aura" and "Rank" attributes. Ranks are earned by total aura and only
-- change your glow, title and name colour, never your power.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("EconomyConfig"))
local NumberFormat = require(Shared:WaitForChild("NumberFormat"))
local RankRules = require(Shared:WaitForChild("RankRules"))
local UiTheme = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("UiTheme"))

local AuraHud = {}

local COLORS = {
	Color3.fromRGB(170, 170, 180),
	Color3.fromRGB(110, 215, 110),
	Color3.fromRGB(90, 160, 255),
	Color3.fromRGB(80, 225, 225),
	Color3.fromRGB(255, 205, 60),
	Color3.fromRGB(255, 120, 80),
	Color3.fromRGB(195, 105, 255),
}

function AuraHud.init()
	local player = Players.LocalPlayer
	pcall(function()
		game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) -- no inventory bar: nothing to hold
	end)
	local gui = Instance.new("ScreenGui")
	gui.Name = "AuraHud"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.Position = UDim2.new(0, 16, 0, 56)
	panel.Size = UDim2.new(0, 270, 0, 70)
	panel.BackgroundColor3 = UiTheme.panel
	panel.Parent = gui
	UiTheme.round(panel, UDim.new(0, 20))
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Thickness = 3
	stroke.Parent = panel
	local scale = Instance.new("UIScale")
	scale.Parent = panel

	local rankLabel = Instance.new("TextLabel")
	rankLabel.Position = UDim2.new(0, 12, 0, 4)
	rankLabel.Size = UDim2.new(0.5, -12, 0, 28)
	rankLabel.BackgroundTransparency = 1
	rankLabel.Font = UiTheme.font
	rankLabel.TextScaled = true
	rankLabel.TextXAlignment = Enum.TextXAlignment.Left
	rankLabel.TextStrokeColor3 = UiTheme.outline
	rankLabel.TextStrokeTransparency = 0
	rankLabel.Text = "NPC"
	rankLabel.Parent = panel

	local auraLabel = Instance.new("TextLabel")
	auraLabel.Position = UDim2.new(0.4, 0, 0, 2)
	auraLabel.Size = UDim2.new(0.6, -12, 0, 32)
	auraLabel.BackgroundTransparency = 1
	auraLabel.Font = UiTheme.font
	auraLabel.TextScaled = true
	auraLabel.TextXAlignment = Enum.TextXAlignment.Right
	auraLabel.TextColor3 = Color3.fromRGB(150, 235, 255)
	auraLabel.TextStrokeColor3 = UiTheme.outline
	auraLabel.TextStrokeTransparency = 0
	auraLabel.Text = "0 aura"
	auraLabel.Parent = panel

	local track = Instance.new("Frame")
	track.Position = UDim2.new(0, 12, 0, 38)
	track.Size = UDim2.new(1, -24, 0, 20)
	track.BackgroundColor3 = Color3.fromRGB(30, 22, 55)
	track.ClipsDescendants = true
	track.Parent = panel
	UiTheme.round(track, UDim.new(0, 10))
	local trackStroke = Instance.new("UIStroke")
	trackStroke.Color = Color3.new(1, 1, 1)
	trackStroke.Thickness = 2
	trackStroke.Parent = track
	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BorderSizePixel = 0
	fill.Parent = track
	local barLabel = Instance.new("TextLabel")
	barLabel.Size = UDim2.new(1, 0, 1, 0)
	barLabel.BackgroundTransparency = 1
	barLabel.Font = UiTheme.font
	barLabel.TextScaled = true
	barLabel.TextColor3 = Color3.new(1, 1, 1)
	barLabel.TextStrokeColor3 = UiTheme.outline
	barLabel.TextStrokeTransparency = 0
	barLabel.ZIndex = 3
	barLabel.Text = ""
	barLabel.Parent = track

	local last = -1
	local function refresh()
		local auraValue = player:GetAttribute("Aura")
		local aura = if type(auraValue) == "number" then auraValue else 0
		local rank, floor, ceiling = RankRules.progress(Config, aura)
		local shownRank = math.max(rank, if type(player:GetAttribute("Rank")) == "number" then player:GetAttribute("Rank") else 1)
		local color = COLORS[math.clamp(shownRank, 1, #COLORS)]
		rankLabel.Text = string.upper(Config.ranks[math.clamp(shownRank, 1, #Config.ranks)].name)
		rankLabel.TextColor3 = color
		fill.BackgroundColor3 = color
		auraLabel.Text = ("%s aura"):format(NumberFormat.format(aura))
		if ceiling then
			local fraction = math.clamp((aura - floor) / math.max(1, ceiling - floor), 0, 1)
			fill.Size = UDim2.new(fraction, 0, 1, 0)
			barLabel.Text = ("%s / %s"):format(NumberFormat.format(aura), NumberFormat.format(ceiling))
		else
			fill.Size = UDim2.new(1, 0, 1, 0)
			barLabel.Text = "MAX RANK!"
		end
		if last >= 0 and aura > last then
			scale.Scale = 1.1 -- a little bounce whenever your aura goes up
			TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
		last = aura
	end
	player:GetAttributeChangedSignal("Aura"):Connect(refresh)
	player:GetAttributeChangedSignal("Rank"):Connect(refresh)
	refresh()
end

function AuraHud.start() end

return AuraHud
