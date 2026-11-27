--!strict
-- Big achievement pop-up cards ("FIRST FLAG!") that slide in from the right, under the top bar, then slide away. At most one at a
-- time; the rest wait their turn. Display only: the server decides when an achievement unlocks (about 30, saved, some with titles).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UiTheme = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("UiTheme"))

local AchievementCards = {}

local gui: ScreenGui
local queue: { { string } } = {}
local showing = false

local function showNext()
	if showing then
		return
	end
	local item = table.remove(queue, 1)
	if not item then
		return
	end
	showing = true
	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(1, 0)
	card.Position = UDim2.new(1.6, 0, 0, 120)
	card.Size = UDim2.new(0, 300, 0, 86)
	card.BackgroundColor3 = UiTheme.panel
	card.Parent = gui
	UiTheme.round(card, UDim.new(0, 18))
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 205, 60)
	stroke.Thickness = 4
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = card
	local function label(text: string, y: number, height: number, color: Color3)
		local item_ = Instance.new("TextLabel")
		item_.BackgroundTransparency = 1
		item_.Position = UDim2.new(0, 12, 0, y)
		item_.Size = UDim2.new(1, -24, 0, height)
		item_.Font = UiTheme.font
		item_.TextScaled = true
		item_.TextXAlignment = Enum.TextXAlignment.Left
		item_.TextColor3 = color
		item_.TextStrokeColor3 = UiTheme.outline
		item_.TextStrokeTransparency = 0
		item_.Text = text
		item_.Parent = card
	end
	label("ACHIEVEMENT!", 6, 18, Color3.fromRGB(255, 205, 60))
	label(item[1], 26, 30, Color3.new(1, 1, 1))
	label(if item[3] ~= "" then ("%s  -  Title: %s"):format(item[2], item[3]) else item[2], 58, 20, Color3.fromRGB(190, 235, 255))
	TweenService:Create(card, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(1, -16, 0, 120) }):Play()
	task.delay(3.4, function()
		local out = TweenService:Create(card, TweenInfo.new(0.35), { Position = UDim2.new(1.6, 0, 0, 120) })
		out.Completed:Connect(function()
			card:Destroy()
			showing = false
			showNext()
		end)
		out:Play()
	end)
end

function AchievementCards.init()
	gui = Instance.new("ScreenGui")
	gui.Name = "AchievementCards"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 15
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

function AchievementCards.start()
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("AchievementUnlocked") :: RemoteEvent
	remote.OnClientEvent:Connect(function(name: any, desc: any, title: any)
		if type(name) == "string" and type(desc) == "string" and type(title) == "string" then
			table.insert(queue, { name, desc, title })
			showNext()
		end
	end)
end

return AchievementCards
