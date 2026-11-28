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
local HudSlots = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("HudSlots"))
local Levels = require(Shared:WaitForChild("Levels"))
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
	panel.Size = UDim2.new(0, 270, 0, 108)
	panel.BackgroundColor3 = UiTheme.panel
	panel.Parent = gui
	UiTheme.round(panel, UDim.new(0, 20))
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Thickness = 3
	stroke.Parent = panel
	local scale = Instance.new("UIScale")
	local baseScale = HudSlots.leftScale()
	scale.Scale = baseScale
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

	local stashLabel = Instance.new("TextLabel")
	stashLabel.Position = UDim2.new(0, 12, 0, 62)
	stashLabel.Size = UDim2.new(1, -24, 0, 18)
	stashLabel.BackgroundTransparency = 1
	stashLabel.Font = UiTheme.font
	stashLabel.TextScaled = true
	stashLabel.TextXAlignment = Enum.TextXAlignment.Left
	stashLabel.TextColor3 = Color3.fromRGB(255, 215, 90)
	stashLabel.TextStrokeColor3 = UiTheme.outline
	stashLabel.TextStrokeTransparency = 0
	stashLabel.Text = ""
	stashLabel.Parent = panel

	local teaser = Instance.new("TextLabel") -- the next ability, as a teaser
	teaser.Position = UDim2.new(0, 12, 0, 84)
	teaser.Size = UDim2.new(1, -24, 0, 18)
	teaser.BackgroundTransparency = 1
	teaser.Font = UiTheme.font
	teaser.TextScaled = true
	teaser.TextXAlignment = Enum.TextXAlignment.Left
	teaser.TextColor3 = Color3.fromRGB(190, 235, 255)
	teaser.TextStrokeColor3 = UiTheme.outline
	teaser.TextStrokeTransparency = 0
	teaser.Text = ""
	teaser.Parent = panel

	local ABILITY_AT = { [2] = "Glow-Up Dash", [3] = "Mog Stare", [4] = "Jawline Slam", [5] = "Hair Flip", [6] = "Mewing Shield", [7] = "Total Mog" }
	local lastDecile = -1
	local targetAura, shownAura = 0, 0
	local lastTier = -1
	local tierFlash = Instance.new("TextLabel")
	tierFlash.BackgroundTransparency = 1
	tierFlash.Size = UDim2.new(1, 0, 0, 22)
	tierFlash.Position = UDim2.new(0, 0, 1, 2)
	tierFlash.Font = Enum.Font.GothamBlack
	tierFlash.TextScaled = true
	tierFlash.TextColor3 = Color3.fromRGB(255, 215, 80)
	tierFlash.TextTransparency = 1
	tierFlash.Text = ""
	tierFlash.Parent = auraLabel
	local function sparkle()
		for index = 1, 7 do -- a little burst of stars at the end of the bar at every 10 percent
			local star = Instance.new("Frame")
			star.Size = UDim2.new(0, 8, 0, 8)
			star.Position = UDim2.new(fill.Size.X.Scale, 0, 0.5, -4)
			star.BackgroundColor3 = Color3.fromRGB(255, 240, 150)
			star.BorderSizePixel = 0
			star.Rotation = 45
			star.ZIndex = 4
			star.Parent = track
			TweenService:Create(star, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = star.Position + UDim2.new(0, math.random(-24, 24), 0, math.random(-26, 6)),
				BackgroundTransparency = 1,
				Size = UDim2.new(0, 2, 0, 2),
			}):Play()
			task.delay(0.65, function()
				star:Destroy()
			end)
		end
	end

	local last = -1
	local function refresh()
		local found, total = player:GetAttribute("StashesFound"), player:GetAttribute("StashesTotal")
		if type(found) == "number" and type(total) == "number" then
			stashLabel.Text = if player:GetAttribute("StashHunter") == true then "STASH HUNTER! 12/12" else ("Stashes found %d/%d"):format(found, total)
		end
		local auraValue = player:GetAttribute("Aura")
		local aura = if type(auraValue) == "number" then auraValue else 0
		local level, floor, ceiling = Levels.progress(aura)
		local names = {}
		for index, entry in Config.ranks do
			names[index] = entry.name
		end
		local shownRank = Levels.rankOfLevel(level)
		local color = COLORS[math.clamp(shownRank, 1, #COLORS)]
		rankLabel.Text = string.upper(Levels.name(level, names)) .. (if level > 0 then "" else "")
		rankLabel.TextColor3 = color
		fill.BackgroundColor3 = color
		targetAura = aura
		if ceiling then
			local fraction = math.clamp((aura - floor) / math.max(1, ceiling - floor), 0, 1)
			fill.Size = UDim2.new(fraction, 0, 1, 0)
			barLabel.Text = ("%s / %s"):format(NumberFormat.format(aura), NumberFormat.format(ceiling))
			local decile = math.floor(fraction * 10)
			if lastDecile >= 0 and decile > lastDecile then
				sparkle() -- sparkle (and, once you add a sound id, a ding) at every 10 percent
			end
			lastDecile = decile
			local nextRank = Levels.rankOfLevel(level + 1)
			local nextName = if nextRank > shownRank then ABILITY_AT[nextRank] else nil
			teaser.Text = if nextName then ("%s unlocks in %s aura!"):format(nextName, NumberFormat.format(ceiling - aura)) else ("Next level in %s aura!"):format(NumberFormat.format(ceiling - aura))
		else
			fill.Size = UDim2.new(1, 0, 1, 0)
			barLabel.Text = "MAX RANK!"
			teaser.Text = ""
			lastDecile = -1
		end
		if last >= 0 and aura > last then
			scale.Scale = baseScale * 1.1 -- a little bounce whenever your aura goes up
			TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = baseScale }):Play()
		end
		last = aura
	end
	game:GetService("RunService").RenderStepped:Connect(function(dt) -- the number rolls up instead of jumping
		shownAura += (targetAura - shownAura) * math.min(1, dt * 8)
		if math.abs(targetAura - shownAura) < math.max(1, targetAura * 1e-4) then
			shownAura = targetAura
		end
		local _, tier = NumberFormat.suffix(shownAura)
		if tier > lastTier and lastTier >= 0 then
			scale.Scale = baseScale * 1.25 -- NEW TIER: the counter pops and flashes the new suffix
			TweenService:Create(scale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = baseScale }):Play()
			tierFlash.Text = "NEW TIER: " .. string.upper((NumberFormat.suffix(shownAura))) .. "!"
			tierFlash.TextTransparency = 0
			TweenService:Create(tierFlash, TweenInfo.new(1.6), { TextTransparency = 1 }):Play()
		end
		lastTier = tier
		auraLabel.Text = ("%s aura"):format(NumberFormat.format(math.floor(shownAura + 0.5)))
	end)
	player:GetAttributeChangedSignal("Aura"):Connect(refresh)
	player:GetAttributeChangedSignal("Rank"):Connect(refresh)
	player:GetAttributeChangedSignal("StashesFound"):Connect(refresh)
	refresh()
end

function AuraHud.start() end

return AuraHud
