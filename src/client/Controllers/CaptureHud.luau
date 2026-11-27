--!strict
-- Slice 3 HUD: a bar for the zone you are standing in. It only DISPLAYS attributes the server set on the
-- zone part (Progress, OwnerFaction, CapturerFaction, Value). It never computes or decides capture state.
-- "Which zone am I in" is also only for display; the server does its own check for real.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UiTheme = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("UiTheme"))

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
local percent: TextLabel

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
	local territoryName = zone:GetAttribute("TerritoryName")
	local flagName = zone:GetAttribute("FlagName")
	local territoryId = zone:GetAttribute("Territory")
	local flagCount = zone:GetAttribute("FlagCount")
	local value = zone:GetAttribute("Value")
	local shown = if type(progress) == "number" then math.clamp(progress, 0, 1) else 0
	fill.Size = UDim2.new(shown, 0, 1, 0)
	percent.Text = if shown > 0 then ("%d%%"):format(math.floor(shown * 100)) else ""
	fill.BackgroundColor3 = if shown > 0 then factionColor(capturer) else factionColor(owner)
	-- "Gigachad Gate: 2/3 flags": how many of this territory's flags YOUR faction holds. A territory is only owned
	-- when one faction holds all of them.
	local myFaction = Players.LocalPlayer:GetAttribute("Faction")
	local total = if type(flagCount) == "number" then flagCount else 1
	local held = 0
	for _, other in CollectionService:GetTagged("Zone") do
		if other:GetAttribute("Territory") == territoryId and other:GetAttribute("OwnerFaction") == myFaction and myFaction ~= nil then
			held += 1
		end
	end
	local name = if type(territoryName) == "string" then territoryName else zone.Name
	title.Text = ("%s: %d/%d flag%s"):format(name, held, total, if total == 1 then "" else "s")
	local flagLabel = if type(flagName) == "string" and total > 1 then flagName .. ". " else ""
	if zone:GetAttribute("Contested") == true then
		subtitle.Text = flagLabel .. "CONTESTED! Splat the enemy"
		subtitle.TextColor3 = Color3.fromRGB(255, 150, 20)
		fill.BackgroundColor3 = Color3.fromRGB(255, 150, 20)
		return
	end
	subtitle.TextColor3 = Color3.new(1, 1, 1)
	if shown > 0 then
		subtitle.Text = ("%s%s is capturing: %d%%"):format(flagLabel, factionName(capturer), math.floor(shown * 100))
	else
		subtitle.Text = ("%sHeld by %s"):format(flagLabel, factionName(owner))
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
	frame.Size = UDim2.new(0.4, 0, 0, 76)
	frame.BackgroundColor3 = UiTheme.panel
	frame.BackgroundTransparency = 0.05
	frame.Visible = false
	frame.Parent = gui
	UiTheme.round(frame, UDim.new(0, 22))
	local outline = Instance.new("UIStroke")
	outline.Color = Color3.new(1, 1, 1)
	outline.Thickness = 3
	outline.Parent = frame
	local limit = Instance.new("UISizeConstraint")
	limit.MinSize = Vector2.new(240, 76)
	limit.MaxSize = Vector2.new(520, 76)
	limit.Parent = frame

	title = Instance.new("TextLabel")
	title.Text = "" -- never show Roblox's default placeholder text
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -16, 0, 22)
	title.Position = UDim2.new(0, 8, 0, 4)
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextScaled = true
	title.Font = UiTheme.font
	title.TextStrokeColor3 = UiTheme.outline
	title.TextStrokeTransparency = 0
	title.Parent = frame

	local track = Instance.new("Frame")
	track.Position = UDim2.new(0, 8, 0, 30)
	track.Size = UDim2.new(1, -16, 0, 20)
	track.BackgroundColor3 = Color3.fromRGB(30, 22, 55)
	track.ClipsDescendants = true
	track.Parent = frame
	UiTheme.round(track, UDim.new(0, 10))
	local trackOutline = Instance.new("UIStroke")
	trackOutline.Color = Color3.new(1, 1, 1)
	trackOutline.Thickness = 2
	trackOutline.Parent = track
	fill = Instance.new("Frame")
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = GREY
	fill.BorderSizePixel = 0
	fill.Parent = track
	percent = Instance.new("TextLabel")
	percent.Size = UDim2.new(1, 0, 1, 0)
	percent.BackgroundTransparency = 1
	percent.Font = UiTheme.font
	percent.TextScaled = true
	percent.TextColor3 = Color3.new(1, 1, 1)
	percent.TextStrokeColor3 = UiTheme.outline
	percent.TextStrokeTransparency = 0
	percent.Text = ""
	percent.ZIndex = 3
	percent.Parent = track

	subtitle = Instance.new("TextLabel")
	subtitle.Text = "" -- never show Roblox's default placeholder text
	subtitle.BackgroundTransparency = 1
	subtitle.Size = UDim2.new(1, -16, 0, 16)
	subtitle.Position = UDim2.new(0, 8, 0, 54)
	subtitle.TextColor3 = Color3.new(1, 1, 1)
	subtitle.TextScaled = true
	subtitle.Font = UiTheme.font
	subtitle.Parent = frame
end

function CaptureHud.start()
	RunService.RenderStepped:Connect(update)
end

return CaptureHud
