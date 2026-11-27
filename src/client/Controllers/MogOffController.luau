--!strict
-- Shows the mog-off duel and sends taps. Display only: the server counts taps (and caps their speed),
-- decides the winner, and publishes MogOffStartsAt, MogOffEndsAt, MogOffOpponent, MogOffTaps and
-- MogOffResult on this player. Tap with F, the screen button, or a touch tap on the button.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MogOffController = {}

local player = Players.LocalPlayer
local panel: Frame
local title: TextLabel
local info: TextLabel
local banner: TextLabel
local tapRemote: RemoteEvent
local bannerUntil = 0

local function attr(name: string, fallback: any): any
	local value = player:GetAttribute(name)
	return if value ~= nil then value else fallback
end

local function update()
	local now = Workspace:GetServerTimeNow()
	local startsAt = attr("MogOffStartsAt", 0)
	local endsAt = attr("MogOffEndsAt", 0)
	local live = type(endsAt) == "number" and endsAt > now
	panel.Visible = live
	if live then
		local opponent = attr("MogOffOpponent", "")
		if now < startsAt then
			title.Text = "MOG-OFF vs " .. tostring(opponent)
			info.Text = ("Get ready... %.1f"):format(startsAt - now)
		else
			title.Text = "TAP! TAP! TAP!"
			info.Text = ("%.1fs left   Your taps: %d"):format(endsAt - now, attr("MogOffTaps", 0))
		end
	end
	banner.Visible = now < bannerUntil
end

function MogOffController.init()
	tapRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("MogOffTap") :: RemoteEvent

	local gui = Instance.new("ScreenGui")
	gui.Name = "MogOffHud"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.new(0.5, 0, 0.55, 0)
	panel.Size = UDim2.new(0, 300, 0, 200)
	panel.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	panel.BackgroundTransparency = 0.15
	panel.Visible = false
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.Parent = panel

	title = Instance.new("TextLabel")
	title.Text = "" -- never show Roblox's default placeholder text
	title.BackgroundTransparency = 1
	title.Position = UDim2.new(0, 8, 0, 8)
	title.Size = UDim2.new(1, -16, 0, 34)
	title.TextColor3 = Color3.fromRGB(255, 220, 90)
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.Parent = panel

	info = Instance.new("TextLabel")
	info.Text = "" -- never show Roblox's default placeholder text
	info.BackgroundTransparency = 1
	info.Position = UDim2.new(0, 8, 0, 46)
	info.Size = UDim2.new(1, -16, 0, 24)
	info.TextColor3 = Color3.new(1, 1, 1)
	info.Font = Enum.Font.Gotham
	info.TextScaled = true
	info.Parent = panel

	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(0.5, 0)
	button.Position = UDim2.new(0.5, 0, 0, 82)
	button.Size = UDim2.new(0, 200, 0, 100)
	button.BackgroundColor3 = Color3.fromRGB(230, 90, 60)
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Font = Enum.Font.GothamBold
	button.TextScaled = true
	button.Text = "TAP (F)"
	button.Parent = panel
	local buttonCorner = Instance.new("UICorner")
	buttonCorner.Parent = button
	button.Activated:Connect(function()
		tapRemote:FireServer()
	end)

	banner = Instance.new("TextLabel")
	banner.Text = "" -- never show Roblox's default placeholder text
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0.25, 0)
	banner.Size = UDim2.new(0, 320, 0, 54)
	banner.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	banner.BackgroundTransparency = 0.2
	banner.TextColor3 = Color3.new(1, 1, 1)
	banner.Font = Enum.Font.GothamBold
	banner.TextScaled = true
	banner.Visible = false
	banner.Parent = gui
	local bannerCorner = Instance.new("UICorner")
	bannerCorner.Parent = banner

	player:GetAttributeChangedSignal("MogOffResult"):Connect(function()
		local result = attr("MogOffResult", "")
		if result == "won" then
			banner.Text = "You won the mog-off!"
		elseif result == "lost" then
			banner.Text = "Nice try! Shake it off."
		elseif result == "draw" then
			banner.Text = "A draw!"
		else
			return
		end
		bannerUntil = Workspace:GetServerTimeNow() + 2.5
	end)
end

function MogOffController.start()
	ContextActionService:BindAction("MogOffTap", function(_name, state)
		if state == Enum.UserInputState.Begin then
			tapRemote:FireServer()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.F)
	RunService.RenderStepped:Connect(update)
end

return MogOffController
