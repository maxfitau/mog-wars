--!strict
-- The only tutorial: a big arrow that points at the nearest GOLD flag with "Stand here to capture!". It shows until the
-- player is standing on a flag (the capture bar takes over) and for good after their first capture. It disappears once they are standing
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
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local camera = Workspace.CurrentCamera
	if (type(stage) == "number" and stage >= 1) or not root or not root:IsA("BasePart") or not camera then
		frame.Visible = false
		return
	end

	-- Point at the nearest territory with only ONE flag (the easiest) if there is one; otherwise any flag.
	local zones = {}
	local parts: { BasePart } = {}
	local easyZones = {}
	local easyParts: { BasePart } = {}
	for _, zone in CollectionService:GetTagged("Zone") do
		if zone:IsA("BasePart") then
			local offset = zone.CFrame:PointToObjectSpace(root.Position)
			if ZoneGeometry.contains(offset.X, offset.Y, offset.Z, zone.Size.X, zone.Size.Y, zone.Size.Z, 8) then
				frame.Visible = false -- already standing in one: the zone bar shows what to do
				return
			end
			table.insert(zones, { x = zone.Position.X, z = zone.Position.Z })
			table.insert(parts, zone)
			if zone:GetAttribute("Value") == 1 and zone:GetAttribute("OwnerFaction") ~= player:GetAttribute("Faction") then -- a Gold flag that is not ours yet
				table.insert(easyZones, { x = zone.Position.X, z = zone.Position.Z })
				table.insert(easyParts, zone)
			end
		end
	end
	local useEasy = #easyZones > 0
	local index = HintRules.nearest(root.Position.X, root.Position.Z, if useEasy then easyZones else zones)
	if not index then
		frame.Visible = false
		return
	end
	local target = (if useEasy then easyParts[index] else parts[index]).Position
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
	frame.Position = UDim2.new(0.5, 0, 0, 70)
	frame.Size = UDim2.new(0.6, 0, 0, 100)
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	frame.BackgroundTransparency = 0.2
	frame.Visible = false
	frame.Parent = gui
	local corner = Instance.new("UICorner")
	corner.Parent = frame
	local limit = Instance.new("UISizeConstraint")
	limit.MinSize = Vector2.new(240, 100)
	limit.MaxSize = Vector2.new(520, 100)
	limit.Parent = frame

	arrow = Instance.new("TextLabel")
	arrow.BackgroundTransparency = 1
	arrow.Position = UDim2.new(0, 10, 0, 10)
	arrow.Size = UDim2.new(0, 84, 0, 84)
	arrow.Text = "▲"
	arrow.TextColor3 = Color3.fromRGB(255, 220, 90)
	arrow.TextScaled = true
	arrow.Font = Enum.Font.FredokaOne
	arrow.Parent = frame

	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Position = UDim2.new(0, 92, 0, 8)
	text.Size = UDim2.new(1, -102, 1, -16)
	text.TextWrapped = true
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextColor3 = Color3.new(1, 1, 1)
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.Text = "Stand here to capture!"
	text.Parent = frame
end

function TutorialHint.start()
	RunService.RenderStepped:Connect(update)
end

return TutorialHint
