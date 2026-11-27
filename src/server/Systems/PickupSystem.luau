--!strict
-- Free pickups that appear around War Island every so often (Pace.pickups). Never sold for Robux. Server only:
--   Protein Shake        a speed boost
--   Aura Refill          refills aura charge and ego
--   Main Character Mode  double aura for a while, with a golden glow and a spotlight on you
-- The server picks the spot, checks the player is really close, and applies the effect.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Pace = require(Shared:WaitForChild("Pace"))
local CombatSystem = require(script.Parent:WaitForChild("CombatSystem"))
local MovementSystem = require(script.Parent:WaitForChild("MovementSystem"))
local PopupSystem = require(script.Parent:WaitForChild("PopupSystem"))

local PickupSystem = {}

local rng = Random.new()
local active: { Part } = {}

local function colorOf(kind: any): Color3
	return Color3.fromRGB(kind.color[1], kind.color[2], kind.color[3])
end

local function pickKind(): any
	local total = 0
	for _, kind in Pace.pickups.kinds do
		total += kind.weight
	end
	local roll = rng:NextNumber() * total
	for _, kind in Pace.pickups.kinds do
		roll -= kind.weight
		if roll <= 0 then
			return kind
		end
	end
	return Pace.pickups.kinds[1]
end

-- A random spot on solid ground (not water, not on a roof or a wall).
local function findSpot(): Vector3?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { Workspace:FindFirstChild("Pickups") :: Instance }
	for _ = 1, 12 do
		local angle = rng:NextNumber() * math.pi * 2
		local radius = Pace.pickups.minRadius + rng:NextNumber() * (Pace.pickups.maxRadius - Pace.pickups.minRadius)
		local x, z = math.cos(angle) * radius, math.sin(angle) * radius
		local result = Workspace:Raycast(Vector3.new(x, 150, z), Vector3.new(0, -300, 0), params)
		if result and result.Material ~= Enum.Material.Water and result.Position.Y > -1 and result.Position.Y < 2.5 and result.Normal.Y > 0.8 then
			return result.Position
		end
	end
	return nil
end

local function applyEffect(player: Player, kindId: string, name: string)
	if kindId == "shake" then
		MovementSystem.boost(player, "shake", Pace.speed.shake.boost, Pace.speed.shake.seconds)
	elseif kindId == "refill" then
		CombatSystem.refill(player)
	elseif kindId == "main" then
		local untilTime = Workspace:GetServerTimeNow() + Pace.pickups.mainCharacterSeconds
		player:SetAttribute("MainCharacterUntil", untilTime)
		local character = player.Character
		if character then
			local glow = Instance.new("Highlight")
			glow.Name = "MainCharacterGlow"
			glow.FillColor = Color3.fromRGB(255, 215, 80)
			glow.OutlineColor = Color3.new(1, 1, 1)
			glow.FillTransparency = 0.55
			glow.Parent = character
			local root = character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				local spot = Instance.new("SpotLight") -- the spotlight on the main character
				spot.Name = "MainCharacterSpot"
				spot.Face = Enum.NormalId.Top
				spot.Angle = 70
				spot.Range = 40
				spot.Brightness = 6
				spot.Color = Color3.fromRGB(255, 235, 170)
				spot.Parent = root
				Debris:AddItem(spot, Pace.pickups.mainCharacterSeconds)
			end
			Debris:AddItem(glow, Pace.pickups.mainCharacterSeconds)
		end
	end
	PopupSystem.send(player, "pickup", 1, name)
end

local function remove(part: Part)
	local at = table.find(active, part)
	if at then
		table.remove(active, at)
	end
	part:Destroy()
end

local function spawnOne()
	local spot = findSpot()
	if not spot then
		return
	end
	local kind = pickKind()
	local folder = Workspace:FindFirstChild("Pickups")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Pickups"
		folder.Parent = Workspace
	end
	local color = colorOf(kind)
	local part = Instance.new("Part")
	part.Name = "Pickup_" .. kind.id
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(3.4, 3.4, 3.4)
	part.Position = spot + Vector3.new(0, 3, 0)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = true
	part.Material = Enum.Material.Neon
	part.Color = color
	part:SetAttribute("Kind", kind.id)
	part:SetAttribute("PickupName", kind.name)
	part.Parent = folder
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 16
	light.Brightness = 2
	light.Parent = part
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 150, 0, 30)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.MaxDistance = 70
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(35, 25, 60)
	label.Text = string.upper(kind.name)
	label.Parent = gui
	CollectionService:AddTag(part, "Pickup")
	table.insert(active, part)
	Debris:AddItem(part, Pace.pickups.lifetimeSeconds)
	task.delay(Pace.pickups.lifetimeSeconds + 0.1, function()
		local at = table.find(active, part)
		if at then
			table.remove(active, at)
		end
	end)
	part.Touched:Connect(function(hit)
		local model = hit:FindFirstAncestorOfClass("Model")
		local player = if model then Players:GetPlayerFromCharacter(model) else nil
		local root = if model then model:FindFirstChild("HumanoidRootPart") else nil
		if not player or not root or not root:IsA("BasePart") or part.Parent == nil then
			return
		end
		if (root.Position - part.Position).Magnitude > Pace.pickups.collectDistance + 4 then
			return
		end
		remove(part) -- taken: only one player gets it
		applyEffect(player, kind.id, kind.name)
	end)
end

function PickupSystem.init() end

function PickupSystem.start()
	task.spawn(function()
		while true do
			task.wait(Pace.pickups.everySeconds)
			if Workspace:GetAttribute("WarPhase") == "War" and #active < Pace.pickups.maxActive then
				local ok, err = pcall(spawnOne)
				if not ok then
					warn("[mog-wars] pickup error: " .. tostring(err))
				end
			end
		end
	end)
end

return PickupSystem
