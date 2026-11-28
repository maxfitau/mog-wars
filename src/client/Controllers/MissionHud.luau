--!strict
-- ALWAYS KNOW WHAT TO DO. A mission bar, top centre under the scoreboard, with ONE goal at a time, picking the nearest
-- useful flag: "Defend Rizz Ravine!" (a flag of yours that an enemy is capturing), "Capture Brainrot Bog - 80m", or
-- "Steal NPC Village from RED - 120m". A trail of glowing dots on the ground leads from you toward that flag, like a GPS
-- line. Display only: it reads the flags' attributes the server publishes.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FactionRules = require(Shared:WaitForChild("FactionRules"))
local ZoneGeometry = require(Shared:WaitForChild("ZoneGeometry"))
local UiTheme = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("UiTheme"))

local MissionHud = {}
local HudSlots = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("HudSlots"))
local overriding = false

local player = Players.LocalPlayer
local NAVY = Color3.fromRGB(18, 22, 58)
local panel: Frame
local panelStroke: UIStroke
local topLabel: TextLabel
local nameLabel: TextLabel
local chipLabel: TextLabel
local dots: { Part } = {}
local DOT_COUNT = 10
local DOT_SPACING = 7

-- "Bright red" -> "RED"
local function colourWord(id: number): string
	local info = FactionRules.byId(id)
	if not info then
		return "THEM"
	end
	local last = string.match(info.brickColor, "(%a+)$")
	return string.upper(last or info.name)
end

local function hideDots()
	for _, dot in dots do
		dot.Transparency = 1
	end
end

local function update()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local mine = player:GetAttribute("Faction")
	if not root or not root:IsA("BasePart") or type(mine) ~= "number" or Workspace:GetAttribute("WarPhase") ~= "War" then
		panel.Visible = false
		hideDots()
		return
	end
	local defendZone: BasePart? = nil
	local defendDistance = math.huge
	local attackZone: BasePart? = nil
	local attackDistance = math.huge
	local standingOn: BasePart? = nil
	for _, zone in CollectionService:GetTagged("Zone") do
		if zone:IsA("BasePart") then
			local offset = zone.CFrame:PointToObjectSpace(root.Position)
			if ZoneGeometry.contains(offset.X, offset.Y, offset.Z, zone.Size.X, zone.Size.Y, zone.Size.Z, 8) then
				standingOn = zone
			end
			local owner = zone:GetAttribute("OwnerFaction")
			local capturer = zone:GetAttribute("CapturerFaction")
			local progress = zone:GetAttribute("Progress")
			local distance = (zone.Position - root.Position).Magnitude
			if owner == mine and type(capturer) == "number" and capturer ~= 0 and capturer ~= mine and type(progress) == "number" and progress > 0.05 then
				if distance < defendDistance then
					defendZone, defendDistance = zone, distance
				end
			elseif owner ~= mine and distance < attackDistance then
				attackZone, attackDistance = zone, distance
			end
		end
	end
	local target: BasePart? = nil
	local top, name, defending = "CAPTURE", "", false
	local distance = 0
	if defendZone then
		target, defending = defendZone, true
		top, name, distance = "DEFEND", ("%s!"):format(tostring(defendZone:GetAttribute("TerritoryName"))), defendDistance
	elseif attackZone then
		target = attackZone
		distance = attackDistance
		local owner = attackZone:GetAttribute("OwnerFaction")
		name = tostring(attackZone:GetAttribute("TerritoryName"))
		if standingOn == attackZone then
			top = "HOLD"
		elseif type(owner) == "number" and owner ~= 0 then
			top = ("STEAL FROM %s"):format(colourWord(owner))
		end
	else
		top, name = "HOLD", "everything!"
	end
	local camera = workspace.CurrentCamera
	if camera then -- never reach into the aura box on the left or the minimap on the right: shrink on narrow screens
		panel.Size = UDim2.new(0, math.clamp(camera.ViewportSize.X - 640, 200, 360), 0, 46)
	end
	if overriding then
		return -- a banner is using the line slot right now
	end
	topLabel.Text = top
	nameLabel.Text = name
	chipLabel.Text = if target then ("%dm >"):format(math.floor(distance)) else "OK"
	-- navy and yellow normally; red when one of your territories is being attacked
	panel.BackgroundColor3 = if defending then Color3.fromRGB(190, 35, 50) else NAVY
	panelStroke.Color = if defending then Color3.new(1, 1, 1) else Color3.fromRGB(255, 205, 60)
	nameLabel.TextColor3 = if defending then Color3.new(1, 1, 1) else Color3.fromRGB(255, 215, 70)
	topLabel.TextColor3 = if defending then Color3.fromRGB(255, 215, 215) else Color3.fromRGB(255, 205, 60)
	panel.Visible = true

	player:SetAttribute("MissionPos", if target then target.Position else nil) -- the minimap highlights this flag
	-- the GPS trail: glowing dots on the ground between you and the flag (hidden where there is no ground to put them on)
	if not target then
		hideDots()
		return
	end
	local flat = Vector3.new(target.Position.X - root.Position.X, 0, target.Position.Z - root.Position.Z)
	local distance = flat.Magnitude
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character :: Instance }
	for index, dot in dots do
		local along = index * DOT_SPACING
		if distance < 12 or along > distance - 6 then
			dot.Transparency = 1
		else
			local point = root.Position + flat.Unit * along
			local hit = Workspace:Raycast(point + Vector3.new(0, 8, 0), Vector3.new(0, -26, 0), params)
			if hit and hit.Normal.Y > 0.6 then
				dot.CFrame = CFrame.new(hit.Position + Vector3.new(0, 0.2, 0))
				dot.Transparency = 0.1 + 0.05 * (index % 3)
			else
				dot.Transparency = 1
			end
		end
	end
end

function MissionHud.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "MissionHud"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")
	panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 112) -- just under the scoreboard
	panel.Size = UDim2.new(0, 360, 0, 46)
	panel.BackgroundColor3 = NAVY
	panel.Visible = false
	panel.Parent = gui
	UiTheme.round(panel, UDim.new(0, 23)) -- a dark navy pill ...
	panelStroke = Instance.new("UIStroke") -- ... with a yellow border
	panelStroke.Color = Color3.fromRGB(255, 205, 60)
	panelStroke.Thickness = 3
	panelStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	panelStroke.Parent = panel
	local icon = Instance.new("Frame") -- a yellow circle with a little flag
	icon.Position = UDim2.new(0, 5, 0.5, -17)
	icon.Size = UDim2.new(0, 34, 0, 34)
	icon.BackgroundColor3 = Color3.fromRGB(255, 205, 60)
	icon.Parent = panel
	UiTheme.round(icon, UDim.new(1, 0))
	local pole = Instance.new("Frame")
	pole.Position = UDim2.new(0, 11, 0, 7)
	pole.Size = UDim2.new(0, 3, 0, 20)
	pole.BackgroundColor3 = NAVY
	pole.BorderSizePixel = 0
	pole.Parent = icon
	local cloth = Instance.new("Frame")
	cloth.Position = UDim2.new(0, 14, 0, 7)
	cloth.Size = UDim2.new(0, 12, 0, 9)
	cloth.BackgroundColor3 = NAVY
	cloth.BorderSizePixel = 0
	cloth.Parent = icon
	topLabel = Instance.new("TextLabel")
	topLabel.BackgroundTransparency = 1
	topLabel.Position = UDim2.new(0, 46, 0, 4)
	topLabel.Size = UDim2.new(1, -140, 0, 13)
	topLabel.Font = UiTheme.font
	topLabel.TextScaled = true
	topLabel.TextXAlignment = Enum.TextXAlignment.Left
	topLabel.TextColor3 = Color3.fromRGB(255, 205, 60)
	topLabel.Text = "CAPTURE"
	topLabel.Parent = panel
	nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Position = UDim2.new(0, 46, 0, 17)
	nameLabel.Size = UDim2.new(1, -140, 0, 24)
	nameLabel.Font = UiTheme.font
	nameLabel.TextScaled = true
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextColor3 = Color3.fromRGB(255, 215, 70)
	nameLabel.Text = ""
	nameLabel.Parent = panel
	local chip = Instance.new("Frame") -- the white distance chip
	chip.AnchorPoint = Vector2.new(1, 0.5)
	chip.Position = UDim2.new(1, -8, 0.5, 0)
	chip.Size = UDim2.new(0, 84, 0, 28)
	chip.BackgroundColor3 = Color3.new(1, 1, 1)
	chip.Parent = panel
	UiTheme.round(chip, UDim.new(0, 14))
	chipLabel = Instance.new("TextLabel")
	chipLabel.BackgroundTransparency = 1
	chipLabel.Size = UDim2.new(1, -8, 1, -4)
	chipLabel.Position = UDim2.new(0, 4, 0, 2)
	chipLabel.Font = UiTheme.font
	chipLabel.TextScaled = true
	chipLabel.TextColor3 = NAVY
	chipLabel.Text = ""
	chipLabel.Parent = chip
	for _ = 1, DOT_COUNT do
		local dot = Instance.new("Part")
		dot.Shape = Enum.PartType.Cylinder
		dot.Size = Vector3.new(0.3, 2.4, 2.4)
		dot.Orientation = Vector3.new(0, 0, 90)
		dot.Anchored = true
		dot.CanCollide = false
		dot.CanQuery = false
		dot.CanTouch = false
		dot.Material = Enum.Material.Neon
		dot.Color = Color3.fromRGB(255, 225, 90)
		dot.Transparency = 1
		dot.Parent = Workspace
		table.insert(dots, dot)
	end
end

function MissionHud.start()
	-- the line slot: a banner replaces the mission text for a few seconds (HudSlots.line), then the mission returns
	HudSlots.setLineHandler({
		show = function(text: string, colour: Color3)
			overriding = true
			panel.Visible = true
			topLabel.Text = ""
			nameLabel.Text = string.upper(text)
			nameLabel.TextColor3 = colour
			chipLabel.Text = ""
			hideDots()
		end,
		hide = function()
			overriding = false
		end,
	})
	local clock = 0
	RunService.Heartbeat:Connect(function(dt)
		clock += dt
		if clock >= 0.2 then
			clock = 0
			local ok, err = pcall(update)
			if not ok then
				warn("[mog-wars] MissionHud: " .. tostring(err))
			end
		end
	end)
end

return MissionHud
