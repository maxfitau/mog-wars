--!strict
-- "⚔ ENTERING COOKED CANYON": a title card that slides in for 2 seconds whenever you cross into a territory, tinted with the
-- owner's team colour (white while nobody owns it). Smaller after the first time you enter that territory. Display only.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Territories = require(Shared:WaitForChild("Territories"))
local FactionRules = require(Shared:WaitForChild("FactionRules"))

local TerritoryBanner = {}

local player = Players.LocalPlayer

-- Which territory is this position in (nil = open sky)? The cave under the Gate is checked first.
local function whereIs(position: Vector3): any?
	for _, territory in Territories.list do
		if territory.radius == 0 then
			if math.abs(position.X - territory.x) < 90 and position.Z - territory.z > -60 and position.Z - territory.z < 52 and position.Y > territory.height - 4 and position.Y < territory.height + 34 then
				return territory
			end
		end
	end
	for _, territory in Territories.list do
		if territory.radius > 0 then
			local dx, dz = position.X - territory.x, position.Z - territory.z
			if math.sqrt(dx * dx + dz * dz) < territory.radius + 6 and position.Y > territory.height - 6 and position.Y < territory.height + 60 then
				-- inside the Gate's footprint but down in the cave height is the cave, handled above
				return territory
			end
		end
	end
	return nil
end

local function ownerOf(id: string): number
	for _, zone in CollectionService:GetTagged("Zone") do
		if zone:GetAttribute("Territory") == id then
			local owner = zone:GetAttribute("TerritoryOwner")
			return if type(owner) == "number" then owner else 0
		end
	end
	return 0
end

function TerritoryBanner.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "TerritoryBanner"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 15
	gui.Parent = player:WaitForChild("PlayerGui")

	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Size = UDim2.fromOffset(440, 54)
	card.Position = UDim2.new(0.5, 0, 0, -80)
	card.BackgroundColor3 = Color3.fromRGB(18, 22, 58)
	card.BackgroundTransparency = 0.12
	card.Visible = false
	card.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = card
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Parent = card
	local scale = Instance.new("UIScale")
	scale.Parent = card
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Parent = card
	local padding = Instance.new("UIPadding")
	padding.PaddingTop, padding.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8)
	padding.Parent = label

	local current: string? = nil
	local seen: { [string]: boolean } = {}
	local shownAt = 0
	local function show(territory: any)
		local first = not seen[territory.id]
		seen[territory.id] = true
		local owner = ownerOf(territory.id)
		local colour = if owner ~= 0 and FactionRules.factions[owner] then Color3.fromRGB(table.unpack(FactionRules.factions[owner].rgb)) else Color3.new(1, 1, 1)
		stroke.Color = colour
		label.TextColor3 = colour:Lerp(Color3.new(1, 1, 1), 0.45)
		label.Text = "⚔ ENTERING " .. string.upper(territory.name)
		scale.Scale = if first then 1 else 0.7
		card.Visible = true
		shownAt = os.clock()
		local mine = shownAt
		card.Position = UDim2.new(0.5, 0, 0, -80)
		TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0, 205) }):Play()
		task.delay(2, function()
			if shownAt == mine then
				TweenService:Create(card, TweenInfo.new(0.3), { Position = UDim2.new(0.5, 0, 0, -80) }):Play()
			end
		end)
	end

	local since = 0
	RunService.Heartbeat:Connect(function(dt)
		since += dt
		if since < 0.3 then
			return
		end
		since = 0
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			return
		end
		local territory = whereIs(root.Position)
		local id = if territory then territory.id else nil
		if id ~= current then
			current = id
			if territory then
				show(territory)
			end
		end
	end)
end

function TerritoryBanner.start() end

return TerritoryBanner
