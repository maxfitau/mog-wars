--!strict
-- Shows the war phase, countdown and each faction's score. Display only: it reads Workspace attributes
-- the server publishes (WarPhase, WarPhaseEndsAt, WarWinner, Score1..4) and never decides anything.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local FactionRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FactionRules"))

local WarHud = {}

local label: TextLabel
local scoreLabels: { TextLabel } = {}

local function clock(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return ("%d:%02d"):format(seconds // 60, seconds % 60)
end

local function update()
	local phase = Workspace:GetAttribute("WarPhase")
	local endsAt = Workspace:GetAttribute("WarPhaseEndsAt")
	if type(phase) ~= "string" or type(endsAt) ~= "number" then
		label.Text = "Waiting for the server..."
		return
	end
	local remaining = endsAt - Workspace:GetServerTimeNow()
	if phase == "War" then
		label.Text = ("War %s  %s"):format(tostring(Workspace:GetAttribute("WarNumber")), clock(remaining))
	else
		local winner = Workspace:GetAttribute("WarWinner")
		local faction = if type(winner) == "number" then FactionRules.byId(winner) else nil
		local note = if faction then faction.name .. " won! " elseif Workspace:GetAttribute("WarNumber") ~= 0 then "Draw. " else ""
		label.Text = ("%sNext war in %s"):format(note, clock(remaining))
	end
	for id, text in scoreLabels do
		local score = Workspace:GetAttribute("Score" .. id)
		text.Text = ("%d"):format(if type(score) == "number" then score else 0)
	end
end

function WarHud.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "WarHud"
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Position = UDim2.new(0, 16, 0, 76) -- under Mog Points, top left
	frame.Size = UDim2.new(0, 230, 0, 92)
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	frame.BackgroundTransparency = 0.25
	frame.Parent = gui
	local corner = Instance.new("UICorner")
	corner.Parent = frame

	label = Instance.new("TextLabel")
	label.Text = "War" -- replaced every frame; never leave the default placeholder text
	label.BackgroundTransparency = 1
	label.Position = UDim2.new(0, 8, 0, 4)
	label.Size = UDim2.new(1, -16, 0, 28)
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = frame

	local count = FactionRules.count()
	for id = 1, count do
		local faction = FactionRules.factions[id]
		local box = Instance.new("TextLabel")
		box.Size = UDim2.new(1 / count, -8, 0, 40)
		box.Position = UDim2.new((id - 1) / count, 4, 0, 40)
		box.BackgroundColor3 = FactionRules.color(faction)
		box.TextColor3 = Color3.new(1, 1, 1)
		box.TextScaled = true
		box.Font = Enum.Font.GothamBold
		box.Text = "0"
		box.Parent = frame
		local boxCorner = Instance.new("UICorner")
		boxCorner.Parent = box
		scoreLabels[id] = box
	end
end

function WarHud.start()
	local reported = false
	RunService.RenderStepped:Connect(function()
		local ok, err = pcall(update)
		if not ok and not reported then
			reported = true
			warn("[mog-wars] WarHud update error: " .. tostring(err))
		end
	end)
end

return WarHud
