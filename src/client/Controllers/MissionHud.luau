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

local player = Players.LocalPlayer
local panel: Frame
local label: TextLabel
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
	local text = ""
	if defendZone then
		target = defendZone
		text = ("Defend %s! - %dm"):format(tostring(defendZone:GetAttribute("TerritoryName")), math.floor(defendDistance))
	elseif attackZone then
		target = attackZone
		local owner = attackZone:GetAttribute("OwnerFaction")
		local name = tostring(attackZone:GetAttribute("TerritoryName"))
		if standingOn == attackZone then
			text = ("Hold the flag! Capturing %s..."):format(name)
		elseif type(owner) == "number" and owner ~= 0 then
			text = ("Steal %s from %s! - %dm"):format(name, colourWord(owner), math.floor(attackDistance))
		else
			text = ("Capture %s - %dm"):format(name, math.floor(attackDistance))
		end
	else
		text = "Your team holds everything! Defend it!"
	end
	label.Text = text
	panel.Visible = true

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
	panel.Position = UDim2.new(0.5, 0, 0, 66) -- just under the scoreboard
	panel.Size = UDim2.new(0, 400, 0, 34)
	panel.BackgroundColor3 = Color3.fromRGB(255, 190, 50)
	panel.Visible = false
	panel.Parent = gui
	UiTheme.round(panel, UDim.new(0, 17))
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Thickness = 3
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = panel
	local limit = Instance.new("UISizeConstraint")
	limit.MinSize = Vector2.new(240, 34)
	limit.MaxSize = Vector2.new(520, 34)
	limit.Parent = panel
	label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -16, 1, -6)
	label.Position = UDim2.new(0, 8, 0, 3)
	label.BackgroundTransparency = 1
	label.Font = UiTheme.font
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(60, 30, 80)
	label.Text = ""
	label.Parent = panel
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
