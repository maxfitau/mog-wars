--!strict
-- Rank panel: current rank, next rank and its cost, and a Rank up button.
-- Display only. The server mirrors Points and Rank onto the player and decides every rank-up; the button
-- just asks, and the answer comes back as a message.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("EconomyConfig"))

local RankHud = {}

local player = Players.LocalPlayer
local rankLabel: TextLabel
local nextLabel: TextLabel
local button: TextButton
local toast: TextLabel
local toastUntil = 0

local MESSAGES: { [string]: string } = {
	not_enough_points = "Not enough Mog Points yet.",
	max_rank = "You are already a Mog God!",
	not_loaded = "Still loading your data.",
	bad_input = "Something went wrong. Try again.",
}

local function number(name: string, fallback: number): number
	local value = player:GetAttribute(name)
	return if type(value) == "number" then value else fallback
end

local function update()
	local rank = math.clamp(number("Rank", 1), 1, #Config.ranks)
	local points = number("Points", 0)
	rankLabel.Text = Config.ranks[rank].name
	local nextEntry = Config.ranks[rank + 1]
	if nextEntry then
		nextLabel.Text = ("Next: %s for %d points"):format(nextEntry.name, nextEntry.cost)
		button.Visible = true
		button.BackgroundColor3 = if points >= nextEntry.cost then Color3.fromRGB(70, 180, 100) else Color3.fromRGB(90, 90, 100)
		button.Text = if points >= nextEntry.cost then "Rank up!" else "Need more points"
	else
		nextLabel.Text = "Top rank reached"
		button.Visible = false
	end
	toast.Visible = Workspace:GetServerTimeNow() < toastUntil
end

function RankHud.init()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local request = remotes:WaitForChild("RankUpRequest") :: RemoteEvent
	local result = remotes:WaitForChild("RankUpResult") :: RemoteEvent

	local gui = Instance.new("ScreenGui")
	gui.Name = "RankHud"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0, 1)
	frame.Position = UDim2.new(0, 16, 1, -110) -- bottom left, above the daily box (the top right is Roblox's player list)
	frame.Size = UDim2.new(0, 230, 0, 120)
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	frame.BackgroundTransparency = 0.25
	frame.Parent = gui
	local corner = Instance.new("UICorner")
	corner.Parent = frame

	rankLabel = Instance.new("TextLabel")
	rankLabel.Text = "" -- never show Roblox's default placeholder text
	rankLabel.BackgroundTransparency = 1
	rankLabel.Position = UDim2.new(0, 8, 0, 6)
	rankLabel.Size = UDim2.new(1, -16, 0, 26)
	rankLabel.TextColor3 = Color3.fromRGB(255, 220, 90)
	rankLabel.Font = Enum.Font.GothamBold
	rankLabel.TextScaled = true
	rankLabel.Parent = frame

	nextLabel = Instance.new("TextLabel")
	nextLabel.Text = "" -- never show Roblox's default placeholder text
	nextLabel.BackgroundTransparency = 1
	nextLabel.Position = UDim2.new(0, 8, 0, 36)
	nextLabel.Size = UDim2.new(1, -16, 0, 20)
	nextLabel.TextColor3 = Color3.new(1, 1, 1)
	nextLabel.Font = Enum.Font.Gotham
	nextLabel.TextScaled = true
	nextLabel.Parent = frame

	button = Instance.new("TextButton")
	button.Text = "" -- never show Roblox's default placeholder text
	button.Position = UDim2.new(0, 8, 0, 66)
	button.Size = UDim2.new(1, -16, 0, 44)
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Font = Enum.Font.GothamBold
	button.TextScaled = true
	button.Parent = frame
	local buttonCorner = Instance.new("UICorner")
	buttonCorner.Parent = button
	button.Activated:Connect(function()
		request:FireServer()
	end)

	toast = Instance.new("TextLabel")
	toast.Text = "" -- never show Roblox's default placeholder text
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0.18, 0)
	toast.Size = UDim2.new(0, 320, 0, 50)
	toast.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	toast.BackgroundTransparency = 0.2
	toast.TextColor3 = Color3.new(1, 1, 1)
	toast.Font = Enum.Font.GothamBold
	toast.TextScaled = true
	toast.Visible = false
	toast.Parent = gui
	local toastCorner = Instance.new("UICorner")
	toastCorner.Parent = toast

	result.OnClientEvent:Connect(function(ok: any, reason: any)
		if ok == true then
			local rank = math.clamp(number("Rank", 1), 1, #Config.ranks)
			toast.Text = ("Ranked up to %s!"):format(Config.ranks[rank].name)
		else
			toast.Text = MESSAGES[tostring(reason)] or "Could not rank up."
		end
		toastUntil = Workspace:GetServerTimeNow() + 3
	end)
end

function RankHud.start()
	RunService.RenderStepped:Connect(update)
end

return RankHud
