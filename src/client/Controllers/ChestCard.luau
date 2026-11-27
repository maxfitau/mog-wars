--!strict
-- The WAR CHEST: after the results, a free chest drops, shakes, and pops open with a random free reward (an aura burst, a
-- trail or aura colour, or a title). Never sold, no Robux. The server picks and grants the reward; this plays the scene.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NumberFormat = require(Shared:WaitForChild("NumberFormat"))
local Pace = require(Shared:WaitForChild("Pace"))
local UiTheme = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("UiTheme"))

local ChestCard = {}

local gui: ScreenGui

local function scene(kind: string, name: string, amount: number)
	local chest = Instance.new("Frame")
	chest.AnchorPoint = Vector2.new(0.5, 0.5)
	chest.Position = UDim2.new(0.5, 0, -0.2, 0)
	chest.Size = UDim2.new(0, 150, 0, 110)
	chest.BackgroundColor3 = Color3.fromRGB(150, 95, 45)
	chest.Parent = gui
	UiTheme.round(chest, UDim.new(0, 16))
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 205, 60)
	stroke.Thickness = 6
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = chest
	local lid = Instance.new("TextLabel")
	lid.Size = UDim2.new(1, 0, 1, 0)
	lid.BackgroundTransparency = 1
	lid.Font = UiTheme.font
	lid.TextScaled = true
	lid.TextColor3 = Color3.fromRGB(255, 220, 90)
	lid.Text = "WAR CHEST!"
	lid.Parent = chest
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.3, 0)
	padding.PaddingBottom = UDim.new(0.3, 0)
	padding.Parent = lid
	-- drop in
	TweenService:Create(chest, TweenInfo.new(0.7, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0.45, 0) }):Play()
	task.wait(0.9)
	-- shake
	for _ = 1, 6 do
		chest.Rotation = 8
		task.wait(0.07)
		chest.Rotation = -8
		task.wait(0.07)
	end
	chest.Rotation = 0
	-- pop open
	TweenService:Create(chest, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = UDim2.new(0, 330, 0, 190) }):Play()
	lid.Text = if kind == "aura" then ("+%s AURA!"):format(NumberFormat.format(amount)) elseif kind == "title" then ('NEW TITLE: "%s"'):format(name) else ("FREE: %s"):format(name)
	lid.TextColor3 = Color3.new(1, 1, 1)
	lid.TextStrokeColor3 = UiTheme.outline
	lid.TextStrokeTransparency = 0
	for _ = 1, 24 do -- confetti
		local piece = Instance.new("Frame")
		piece.Size = UDim2.new(0, 9, 0, 13)
		piece.Position = UDim2.new(0.5, math.random(-60, 60), 0.45, 0)
		piece.BackgroundColor3 = Color3.fromHSV(math.random(), 0.8, 1)
		piece.BorderSizePixel = 0
		piece.Parent = gui
		TweenService:Create(piece, TweenInfo.new(1.2, Enum.EasingStyle.Quad), { Position = UDim2.new(0.5, math.random(-200, 200), 0.85, 0), Rotation = math.random(-300, 300), BackgroundTransparency = 1 }):Play()
		task.delay(1.3, function()
			piece:Destroy()
		end)
	end
	task.wait(Pace.chest.seconds - 1.8)
	chest:Destroy()
end

function ChestCard.init()
	gui = Instance.new("ScreenGui")
	gui.Name = "ChestCard"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 12
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

function ChestCard.start()
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("WarChest") :: RemoteEvent
	remote.OnClientEvent:Connect(function(kind: any, name: any, amount: any)
		if type(kind) == "string" and type(name) == "string" and type(amount) == "number" then
			task.spawn(scene, kind, name, amount)
		end
	end)
end

return ChestCard
