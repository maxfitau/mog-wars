--!strict
-- Slice 3 HUD: a bar for the zone you are standing in. It only DISPLAYS attributes the server set on the
-- zone part (Progress, OwnerFaction, CapturerFaction, Value). It never computes or decides capture state.
-- "Which zone am I in" is also only for display; the server does its own check for real.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FactionRules = require(Shared:WaitForChild("FactionRules"))
local ZoneGeometry = require(Shared:WaitForChild("ZoneGeometry"))

local HEADROOM = 8
local GREY = Color3.fromRGB(200, 200, 200)

local CaptureHud = {}

local frame: Frame
local fill: Frame
local title: TextLabel
local subtitle: TextLabel

local function factionName(id: any): string
	local faction = if type(id) == "number" then FactionRules.byId(id) else nil
	return if faction then faction.name else "nobody"
end

local function factionColor(id: any): Color3
	local faction = if type(id) == "number" then FactionRules.byId(id) else nil
	return if faction then FactionRules.color(faction) else GREY
end

local function zoneUnderPlayer(): BasePart?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil
	end
	for _, zone in CollectionService:GetTagged("Zone") do
		if zone:IsA("BasePart") then
			local offset = zone.CFrame:PointToObjectSpace(root.Position)
			if ZoneGeometry.contains(offset.X, offset.Y, offset.Z, zone.Size.X, zone.Size.Y, zone.Size.Z, HEADROOM) then
				return zone
			end
		end
	end
	return nil
end

local function update()
	local zone = zoneUnderPlayer()
	frame.Visible = zone ~= nil
	if not zone then
		return
	end
	local progress = zone:GetAttribute("Progress")
	local owner = zone:GetAttribute("OwnerFaction")
	local capturer = zone:GetAttribute("CapturerFaction")
	local value = zone:GetAttribute("Value")
	local shown = if type(progress) == "number" then math.clamp(progress, 0, 1) else 0
	fill.Size = UDim2.new(shown, 0, 1, 0)
	fill.BackgroundColor3 = if shown > 0 then factionColor(capturer) else factionColor(owner)
	title.Text = ("%s%s"):format(zone.Name:gsub("^Zone_", ""), if value == 2 then " (worth double)" else "")
	if shown > 0 then
		subtitle.Text = ("%s is capturing: %d%%"):format(factionName(capturer), math.floor(shown * 100))
	else
		subtitle.Text = ("Held by %s"):format(factionName(owner))
	end
end

function CaptureHud.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "CaptureHud"
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, 16)
	frame.Size = UDim2.new(0.4, 0, 0, 64)
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	frame.BackgroundTransparency = 0.25
	frame.Visible = false
	frame.Parent = gui
	local corner = Instance.new("UICorner")
	corner.Parent = frame
	local limit = Instance.new("UISizeConstraint")
	limit.MinSize = Vector2.new(220, 64)
	limit.MaxSize = Vector2.new(520, 64)
	limit.Parent = frame

	title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -16, 0, 22)
	title.Position = UDim2.new(0, 8, 0, 4)
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.Parent = frame

	local track = Instance.new("Frame")
	track.Position = UDim2.new(0, 8, 0, 30)
	track.Size = UDim2.new(1, -16, 0, 12)
	track.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
	track.Parent = frame
	fill = Instance.new("Frame")
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = GREY
	fill.BorderSizePixel = 0
	fill.Parent = track

	subtitle = Instance.new("TextLabel")
	subtitle.BackgroundTransparency = 1
	subtitle.Size = UDim2.new(1, -16, 0, 16)
	subtitle.Position = UDim2.new(0, 8, 0, 44)
	subtitle.TextColor3 = Color3.fromRGB(220, 220, 230)
	subtitle.TextScaled = true
	subtitle.Font = Enum.Font.Gotham
	subtitle.Parent = frame
end

function CaptureHud.start()
	RunService.RenderStepped:Connect(update)
end

return CaptureHud
