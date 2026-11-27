--!strict
-- First-session hint, on War Island only. Until a player has captured a zone (RevealStage 0), show one line, "Run to a glowing
-- zone and stand in it!", with an arrow that points at the nearest zone. It disappears once they are standing
-- in a zone (the zone bar takes over) and for good after their first capture. Display only.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HintRules = require(Shared:WaitForChild("HintRules"))
local ZoneGeometry = require(Shared:WaitForChild("ZoneGeometry"))

local TutorialHint = {}

local player = Players.LocalPlayer
local frame: Frame
local arrow: TextLabel

local function update()
	local stage = player:GetAttribute("RevealStage")
	if player:GetAttribute("Island") == "training" then
		frame.Visible = false -- the hint is only for War Island
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local camera = Workspace.CurrentCamera
	if (type(stage) == "number" and stage >= 1) or not root or not root:IsA("BasePart") or not camera then
		frame.Visible = false
		return
	end

	local zones = {}
	local parts: { BasePart } = {}
	for _, zone in CollectionService:GetTagged("Zone") do
		if zone:IsA("BasePart") then
			local offset = zone.CFrame:PointToObjectSpace(root.Position)
			if ZoneGeometry.contains(offset.X, offset.Y, offset.Z, zone.Size.X, zone.Size.Y, zone.Size.Z, 8) then
				frame.Visible = false -- already standing in one: the zone bar shows what to do
				return
			end
			table.insert(zones, { x = zone.Position.X, z = zone.Position.Z })
			table.insert(parts, zone)
		end
	end
	local index = HintRules.nearest(root.Position.X, root.Position.Z, zones)
	if not index then
		frame.Visible = false
		return
	end
	local target = parts[index].Position
	local look = camera.CFrame.LookVector
	arrow.Rotation = HintRules.arrowAngle(target.X - root.Position.X, target.Z - root.Position.Z, look.X, look.Z)
	frame.Visible = true
end

function TutorialHint.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "TutorialHint" -- not in RevealRules, so it is never hidden by it
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, 16)
	frame.Size = UDim2.new(0.6, 0, 0, 92)
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	frame.BackgroundTransparency = 0.2
	frame.Visible = false
	frame.Parent = gui
	local corner = Instance.new("UICorner")
	corner.Parent = frame
	local limit = Instance.new("UISizeConstraint")
	limit.MinSize = Vector2.new(240, 92)
	limit.MaxSize = Vector2.new(520, 92)
	limit.Parent = frame

	arrow = Instance.new("TextLabel")
	arrow.BackgroundTransparency = 1
	arrow.Position = UDim2.new(0, 10, 0, 10)
	arrow.Size = UDim2.new(0, 72, 0, 72)
	arrow.Text = "▲"
	arrow.TextColor3 = Color3.fromRGB(255, 220, 90)
	arrow.TextScaled = true
	arrow.Font = Enum.Font.GothamBold
	arrow.Parent = frame

	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Position = UDim2.new(0, 92, 0, 8)
	text.Size = UDim2.new(1, -102, 1, -16)
	text.TextWrapped = true
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextColor3 = Color3.new(1, 1, 1)
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.Text = "Run to a glowing zone and stand in it!"
	text.Parent = frame
end

function TutorialHint.start()
	RunService.RenderStepped:Connect(update)
end

return TutorialHint
