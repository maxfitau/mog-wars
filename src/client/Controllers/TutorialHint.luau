--!strict
-- The only tutorial: a small bobbing arrow and a short label ("Capture me!") floating above the nearest GOLD flag, in the
-- world, not on the screen. It shows until you are standing on a flag and for good after your first capture. Display only.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ZoneGeometry = require(Shared:WaitForChild("ZoneGeometry"))

local TutorialHint = {}

local player = Players.LocalPlayer
local marker: BillboardGui
local arrow: TextLabel
local target: BasePart? = nil

local function hide()
	marker.Enabled = false
	marker.Adornee = nil
	target = nil
end

local function update()
	local stage = player:GetAttribute("RevealStage")
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if (type(stage) == "number" and stage >= 1) or not root or not root:IsA("BasePart") then
		hide()
		return
	end
	local mine = player:GetAttribute("Faction")
	local nearest: BasePart? = nil
	local nearestDistance = math.huge
	for _, zone in CollectionService:GetTagged("Zone") do
		if zone:IsA("BasePart") then
			local offset = zone.CFrame:PointToObjectSpace(root.Position)
			if ZoneGeometry.contains(offset.X, offset.Y, offset.Z, zone.Size.X, zone.Size.Y, zone.Size.Z, 8) then
				hide() -- already on a flag: the capture bar takes over
				return
			end
			-- a Gold flag (value 1) that is not ours yet
			if zone:GetAttribute("Value") == 1 and zone:GetAttribute("OwnerFaction") ~= mine then
				local distance = (zone.Position - root.Position).Magnitude
				if distance < nearestDistance then
					nearest, nearestDistance = zone, distance
				end
			end
		end
	end
	if nearest ~= target then
		target = nearest
		marker.Adornee = nearest
	end
	marker.Enabled = nearest ~= nil
end

function TutorialHint.init()
	marker = Instance.new("BillboardGui")
	marker.Name = "TutorialHint" -- a world marker, not a screen banner
	marker.Size = UDim2.new(0, 96, 0, 64)
	marker.StudsOffset = Vector3.new(0, 16, 0) -- above the flag pole
	marker.AlwaysOnTop = true
	marker.MaxDistance = 1000
	marker.Enabled = false
	marker.ResetOnSpawn = false
	marker.Parent = player:WaitForChild("PlayerGui")

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0.45, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 230, 90)
	label.TextStrokeColor3 = Color3.fromRGB(35, 25, 60)
	label.TextStrokeTransparency = 0
	label.Text = "Capture me!"
	label.Parent = marker

	arrow = Instance.new("TextLabel")
	arrow.Position = UDim2.new(0, 0, 0.45, 0)
	arrow.Size = UDim2.new(1, 0, 0.55, 0)
	arrow.BackgroundTransparency = 1
	arrow.Font = Enum.Font.FredokaOne
	arrow.TextScaled = true
	arrow.TextColor3 = Color3.fromRGB(255, 230, 90)
	arrow.TextStrokeColor3 = Color3.fromRGB(35, 25, 60)
	arrow.TextStrokeTransparency = 0
	arrow.Text = "▼"
	arrow.Parent = marker

	-- a gentle bob so it catches the eye
	TweenService:Create(arrow, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Position = UDim2.new(0, 0, 0.6, 0) }):Play()
end

function TutorialHint.start()
	local clock = 0
	RunService.Heartbeat:Connect(function(dt)
		clock += dt
		if clock >= 0.25 then
			clock = 0
			update()
		end
	end)
end

return TutorialHint
