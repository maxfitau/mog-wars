--!strict
-- Floating number pop-ups ("+1", "+10", "+300 aura"), banners (MOGGED!, DOUBLE MOG, REDUCED TO NPC, pickups), the
-- combo counter, coins flying to the points counter and a small screen punch on captures. The server sends a kind and
-- an amount (PopupSystem); this only draws them. Bigger numbers get bigger text and a colour tier: white under 1,000,
-- gold under a million, purple above (NumberFormat), with short suffixes K, M, B, T, Qa. Everything sits BELOW the
-- crosshair, in the corners or at the top, so it never covers the aim. Few things are on screen at once.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("EconomyConfig"))
local NumberFormat = require(Shared:WaitForChild("NumberFormat"))
local Weapons = require(Shared:WaitForChild("Weapons"))
local UiTheme = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("UiTheme"))

local PopupController = {}

local MAX_ON_SCREEN = 6
local MAX_COINS = 8
local LIFETIME_SECONDS = 1.4

local TIER_COLORS = {
	white = Color3.fromRGB(255, 255, 255),
	gold = Color3.fromRGB(255, 215, 60),
	purple = Color3.fromRGB(190, 110, 255),
}

local gui: ScreenGui
local active: { TextLabel } = {}
local banner: TextLabel
local bannerToken = 0
local comboLabel: TextLabel
local comboToken = 0
local punchUntil = 0
local coins = 0
local flash: Frame

local function playSound(id: string, pitch: number)
	if id == "" then
		return -- no licensed sound ids yet (Weapons.combat.sounds): pitch still rises when you add them
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.PlaybackSpeed = pitch
	sound.Volume = 0.5
	sound.Parent = gui
	sound:Play()
	game:GetService("Debris"):AddItem(sound, 3)
end

local function show(text: string, amount: number, color: Color3?)
	while #active >= MAX_ON_SCREEN do
		local oldest = table.remove(active, 1)
		if oldest then
			oldest:Destroy()
		end
	end
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Size = UDim2.new(0, 300, 0, math.floor(36 * NumberFormat.sizeScale(amount)))
	label.Position = UDim2.new(0.5, math.random(-40, 40), 0.64, #active * 26) -- below the crosshair, stacked downward
	label.BackgroundTransparency = 1
	label.Font = UiTheme.font
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color or TIER_COLORS[NumberFormat.tier(amount)] or TIER_COLORS.white
	label.TextStrokeColor3 = UiTheme.outline
	label.TextStrokeTransparency = 0
	label.Parent = gui
	table.insert(active, label)

	local tween = TweenService:Create(label, TweenInfo.new(LIFETIME_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = label.Position - UDim2.new(0, 0, 0, 60),
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

-- A big banner at the top of the screen (one at a time).
local function showBanner(text: string, color: Color3, seconds: number)
	bannerToken += 1
	local token = bannerToken
	banner.Text = text
	banner.TextColor3 = color
	banner.TextTransparency = 0
	banner.TextStrokeTransparency = 0
	banner.Visible = true
	banner.Size = UDim2.new(0, 560, 0, 90)
	TweenService:Create(banner, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.new(0, 460, 0, 66) }):Play()
	task.delay(seconds, function()
		if bannerToken == token then
			local fade = TweenService:Create(banner, TweenInfo.new(0.3), { TextTransparency = 1, TextStrokeTransparency = 1 })
			fade:Play()
		end
	end)
end

-- The combo counter, right of the crosshair: x2, x3, x4 ... it bounces and the pitch rises.
local function showCombo(multiplier: number)
	if multiplier < 2 then
		return
	end
	comboToken += 1
	local token = comboToken
	comboLabel.Text = ("COMBO x%d"):format(multiplier)
	comboLabel.Visible = true
	comboLabel.TextTransparency = 0
	comboLabel.Size = UDim2.new(0, 260, 0, 60)
	TweenService:Create(comboLabel, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.new(0, 200, 0, 44) }):Play()
	playSound(Weapons.combat.sounds.combo, 1 + 0.12 * (multiplier - 1))
	task.delay(Weapons.combat.comboWindowSeconds, function()
		if comboToken == token then
			comboLabel.Visible = false
		end
	end)
end

-- Coins (or aura orbs) fly from the middle of the screen to a counter in the top right.
local function flyTo(color: Color3, count: number, targetY: number)
	for index = 1, count do
		if coins >= MAX_COINS then
			return
		end
		coins += 1
		local coin = Instance.new("Frame")
		coin.AnchorPoint = Vector2.new(0.5, 0.5)
		coin.Size = UDim2.new(0, 18, 0, 18)
		coin.Position = UDim2.new(0.5, math.random(-30, 30), 0.6, math.random(0, 30))
		coin.BackgroundColor3 = color
		coin.Parent = gui
		UiTheme.round(coin, UDim.new(1, 0))
		local rim = Instance.new("UIStroke")
		rim.Color = Color3.new(1, 1, 1)
		rim.Thickness = 2
		rim.Parent = coin
		task.delay((index - 1) * 0.07, function()
			local tween = TweenService:Create(coin, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.new(1, -60, 0, targetY),
				Size = UDim2.new(0, 10, 0, 10),
			})
			tween.Completed:Connect(function()
				coins -= 1
				coin:Destroy()
			end)
			tween:Play()
		end)
	end
end

-- A small screen punch: a quick white flash and a short camera jolt.
local function punch()
	flash.BackgroundTransparency = 0.82
	TweenService:Create(flash, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
	punchUntil = os.clock() + 0.2
end

function PopupController.init()
	gui = Instance.new("ScreenGui")
	gui.Name = "RewardPopups" -- not in RevealRules: pop-ups are never hidden by it
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	flash = Instance.new("Frame")
	flash.Size = UDim2.new(1, 0, 1, 0)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Parent = gui

	banner = Instance.new("TextLabel")
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0.17, 0)
	banner.Size = UDim2.new(0, 460, 0, 66)
	banner.BackgroundTransparency = 1
	banner.Font = UiTheme.font
	banner.TextScaled = true
	banner.TextStrokeColor3 = UiTheme.outline
	banner.Visible = false
	banner.Text = ""
	banner.Parent = gui

	comboLabel = Instance.new("TextLabel")
	comboLabel.AnchorPoint = Vector2.new(0, 0.5)
	comboLabel.Position = UDim2.new(0.5, 90, 0.46, 0) -- right of the crosshair, not on it
	comboLabel.Size = UDim2.new(0, 200, 0, 44)
	comboLabel.BackgroundTransparency = 1
	comboLabel.Font = UiTheme.font
	comboLabel.TextScaled = true
	comboLabel.TextXAlignment = Enum.TextXAlignment.Left
	comboLabel.TextColor3 = Color3.fromRGB(255, 190, 60)
	comboLabel.TextStrokeColor3 = UiTheme.outline
	comboLabel.TextStrokeTransparency = 0
	comboLabel.Visible = false
	comboLabel.Text = ""
	comboLabel.Parent = gui

	RunService:BindToRenderStep("MogWarsPunch", Enum.RenderPriority.Camera.Value + 2, function()
		local camera = Workspace.CurrentCamera
		if camera and os.clock() < punchUntil then
			camera.CFrame *= CFrame.Angles(math.rad((math.random() - 0.5) * 1.6), math.rad((math.random() - 0.5) * 1.6), 0)
		end
	end)

	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RewardPopup") :: RemoteEvent
	remote.OnClientEvent:Connect(function(kind: any, amount: any, detail: any)
		if type(amount) ~= "number" or amount ~= amount or amount <= 0 then
			return
		end
		local number = NumberFormat.format(amount)
		if kind == "points" then
			show(("+%s Mog Points"):format(number), amount)
			flyTo(Color3.fromRGB(255, 205, 50), math.clamp(math.floor(math.log(amount + 1, 4)) + 1, 1, 4), 30)
		elseif kind == "aura" then
			show(("+%s"):format(number), amount, if amount >= 25 then nil else Color3.fromRGB(150, 235, 255))
			if amount >= 10 then
				flyTo(Color3.fromRGB(120, 220, 255), 2, 110)
			end
		elseif kind == "mogged" then
			showBanner("MOGGED!", Color3.fromRGB(190, 110, 255), 1.0)
		elseif kind == "announce" then
			showBanner(if type(detail) == "string" then string.upper(detail) else "STREAK", Color3.fromRGB(255, 190, 60), 1.8)
		elseif kind == "combo" then
			showCombo(amount)
		elseif kind == "bonk" then
			-- the funny shove pop-up: BONK! for the shover (amount 1) or for whoever got bonked (amount 2)
			showBanner(if amount >= 2 then "BONKED!" else "BONK!", Color3.fromRGB(255, 160, 40), 0.8)
			punch()
		elseif kind == "whoosh" then
			showBanner("WHOOSH!", Color3.fromRGB(150, 220, 255), 1.2)
		elseif kind == "rankup" then
			showBanner(("RANK UP! %s"):format(if type(detail) == "string" then string.upper(detail) else ""), Color3.fromRGB(255, 215, 60), 2.4)
			punch()
		elseif kind == "rush" then
			show("AURA RUSH!", 1000, Color3.fromRGB(120, 255, 170))
		elseif kind == "knockout" then
			showBanner("REDUCED TO NPC", Color3.fromRGB(190, 190, 200), 1.8)
		elseif kind == "capture" then
			punch()
			show("FLAG CAPTURED!", 100000)
		elseif kind == "pickup" then
			showBanner(if type(detail) == "string" then string.upper(detail) .. "!" else "PICKUP!", Color3.fromRGB(120, 255, 170), 1.6)
		elseif kind == "box" then
			local tier = if type(detail) == "string" then Config.boxes.tiers[detail] else nil
			show(("+%s %s"):format(number, if tier then tier.displayName else "Box"), amount * 100) -- boxes always look special
		end
	end)
end

function PopupController.start() end

return PopupController
