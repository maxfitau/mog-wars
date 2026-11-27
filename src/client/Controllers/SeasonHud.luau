--!strict
-- Weekly season panel, bottom right: time left, each faction's score and your own points this week, plus a
-- reminder that capturing with friends earns a squad bonus. Display only: the server counts everything and
-- publishes SeasonWeek, SeasonEndsAt and SeasonScore1..4 on Workspace and SeasonPoints on you. Standings show
-- factions only, never individual players.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local FactionRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FactionRules"))

local SeasonHud = {}

local player = Players.LocalPlayer
local title: TextLabel
local mine: TextLabel
local scoreLabels: { TextLabel } = {}
local toast: TextLabel
local toastUntil = 0

local function timeLeft(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local days = seconds // 86400
	local hours = (seconds % 86400) // 3600
	if days > 0 then
		return ("%dd %dh"):format(days, hours)
	end
	return ("%dh %dm"):format(hours, (seconds % 3600) // 60)
end

local function update()
	local week = Workspace:GetAttribute("SeasonWeek")
	local endsAt = Workspace:GetAttribute("SeasonEndsAt")
	if type(week) == "number" and type(endsAt) == "number" then
		title.Text = ("Weekly season: %s left"):format(timeLeft(endsAt - Workspace:GetServerTimeNow()))
	else
		title.Text = "Weekly season"
	end
	for id, label in scoreLabels do
		local score = Workspace:GetAttribute("SeasonScore" .. id)
		label.Text = tostring(if type(score) == "number" then score else 0)
	end
	local points = player:GetAttribute("SeasonPoints")
	mine.Text = ("Your points: %d. Capture with friends for a squad bonus!"):format(if type(points) == "number" then points else 0)
	toast.Visible = Workspace:GetServerTimeNow() < toastUntil
end

function SeasonHud.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "SeasonHud"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(1, 1)
	frame.Position = UDim2.new(1, -16, 1, -16)
	frame.Size = UDim2.new(0, 250, 0, 104)
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	frame.BackgroundTransparency = 0.25
	frame.Parent = gui
	local corner = Instance.new("UICorner")
	corner.Parent = frame

	title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.new(0, 8, 0, 4)
	title.Size = UDim2.new(1, -16, 0, 22)
	title.TextColor3 = Color3.fromRGB(255, 220, 90)
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.Parent = frame

	local count = FactionRules.count()
	for id = 1, count do
		local faction = FactionRules.factions[id]
		local box = Instance.new("TextLabel")
		box.Size = UDim2.new(1 / count, -6, 0, 30)
		box.Position = UDim2.new((id - 1) / count, 3, 0, 30)
		box.BackgroundColor3 = FactionRules.color(faction)
		box.TextColor3 = Color3.new(1, 1, 1)
		box.Font = Enum.Font.GothamBold
		box.TextScaled = true
		box.Text = "0"
		box.Parent = frame
		local boxCorner = Instance.new("UICorner")
		boxCorner.Parent = box
		scoreLabels[id] = box
	end

	mine = Instance.new("TextLabel")
	mine.BackgroundTransparency = 1
	mine.Position = UDim2.new(0, 8, 0, 66)
	mine.Size = UDim2.new(1, -16, 0, 32)
	mine.TextWrapped = true
	mine.TextColor3 = Color3.fromRGB(220, 220, 230)
	mine.Font = Enum.Font.Gotham
	mine.TextSize = 13
	mine.Parent = frame

	toast = Instance.new("TextLabel")
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0.1, 0)
	toast.Size = UDim2.new(0, 380, 0, 56)
	toast.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	toast.BackgroundTransparency = 0.1
	toast.TextColor3 = Color3.fromRGB(255, 220, 90)
	toast.Font = Enum.Font.GothamBold
	toast.TextScaled = true
	toast.TextWrapped = true
	toast.Visible = false
	toast.ZIndex = 5
	toast.Parent = gui
	local toastCorner = Instance.new("UICorner")
	toastCorner.Parent = toast

	local result = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SeasonResult") :: RemoteEvent
	result.OnClientEvent:Connect(function(kind: any, week: any, winner: any)
		local faction = if type(winner) == "number" then FactionRules.byId(winner) else nil
		local name = if faction then faction.name else "a faction"
		if kind == "champion" then
			toast.Text = ("%s won last week's season! You earned the Season Champion title."):format(name)
		elseif kind == "missed" then
			toast.Text = ("Last week's season is over. %s won."):format(name)
		else
			return
		end
		toastUntil = Workspace:GetServerTimeNow() + 6
	end)
end

function SeasonHud.start()
	RunService.RenderStepped:Connect(update)
end

return SeasonHud
