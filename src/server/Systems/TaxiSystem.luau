--!strict
-- AIRSHIP TAXIS (free, never sold). Each team has an airship that shuttles between its spawn island and the Gigachad Gate plaza.
-- Hold the prompt at a dock: after a 3 second boarding countdown the ship takes everyone who signed up (up to 6) on a
-- smooth flight over the clouds and sets them down at the other dock. While it is away the prompts say so. The server moves
-- the ship and carries the passengers (like ziplines and lifts), so lag cannot break the ride. Numbers are in Pace.taxi.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Pace = require(Shared:WaitForChild("Pace"))
local FactionRules = require(Shared:WaitForChild("FactionRules"))
local MapLayout = require(Shared:WaitForChild("MapLayout"))
local Territories = require(Shared:WaitForChild("Territories"))
local PopupSystem = require(script.Parent:WaitForChild("PopupSystem"))

local TaxiSystem = {}

type Dock = { position: Vector3, prompt: ProximityPrompt, label: TextLabel }
type Ship = {
	faction: number,
	model: Model,
	propeller: Part,
	docks: { Dock },
	at: number, -- which dock it is at (1 = home island, 2 = Gate), 0 while flying
	boarding: { Player },
	flying: boolean,
	frame: CFrame,
}

local ships: { Ship } = {}

local function part(parent: Instance, name: string, size: Vector3, colour: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = colour
	p.Material = material
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

-- The airship: a wooden gondola under a fat cream balloon with a team-colour band and banner, a propeller and lanterns.
local function buildShip(colour: Color3): (Model, Part)
	local model = Instance.new("Model")
	model.Name = "AirshipTaxi"
	local origin = CFrame.new(0, 0, 0)
	local hull = part(model, "Hull", Vector3.new(12, 5, 26), Color3.fromRGB(120, 84, 52), Enum.Material.WoodPlanks, Enum.PartType.Ball)
	hull.CFrame = origin
	model.PrimaryPart = hull
	local function add(name: string, size: Vector3, offset: Vector3, c: Color3, material: Enum.Material, shape: Enum.PartType?): Part
		local p = part(model, name, size, c, material, shape)
		p.CFrame = origin * CFrame.new(offset)
		return p
	end
	add("Deck", Vector3.new(9, 0.6, 20), Vector3.new(0, 1.6, 0), Color3.fromRGB(176, 128, 74), Enum.Material.WoodPlanks)
	for _, side in { -1, 1 } do
		add("Rail", Vector3.new(0.4, 1.4, 20), Vector3.new(side * 4.4, 2.6, 0), Color3.fromRGB(104, 72, 48), Enum.Material.Wood)
		add("Rope", Vector3.new(0.3, 12, 0.3), Vector3.new(side * 4, 8, -3), Color3.fromRGB(235, 220, 190), Enum.Material.Fabric)
		add("Rope", Vector3.new(0.3, 12, 0.3), Vector3.new(side * 4, 8, 4), Color3.fromRGB(235, 220, 190), Enum.Material.Fabric)
	end
	add("Balloon", Vector3.new(16, 15, 32), Vector3.new(0, 16, 0), Color3.fromRGB(245, 235, 210), Enum.Material.Fabric, Enum.PartType.Ball)
	add("Band", Vector3.new(16.6, 3, 18), Vector3.new(0, 16, 0), colour, Enum.Material.Fabric, Enum.PartType.Ball)
	add("Banner", Vector3.new(0.3, 5, 3), Vector3.new(0, 4.8, 11), colour, Enum.Material.Fabric)
	add("Mast", Vector3.new(0.6, 8, 0.6), Vector3.new(0, 6, 10.5), Color3.fromRGB(104, 72, 48), Enum.Material.Wood)
	add("Rudder", Vector3.new(0.5, 4, 4), Vector3.new(0, 3.4, 13), Color3.fromRGB(104, 72, 48), Enum.Material.WoodPlanks)
	local lantern = add("Lantern", Vector3.new(1.6, 2, 1.6), Vector3.new(0, 3.4, -9.4), Color3.fromRGB(255, 190, 90), Enum.Material.Neon, Enum.PartType.Ball)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 190, 90)
	light.Range = 28
	light.Parent = lantern
	local propeller = add("Propeller", Vector3.new(0.3, 5, 0.9), Vector3.new(0, 0.4, 13.4), Color3.fromRGB(70, 56, 46), Enum.Material.Wood)
	model.Parent = Workspace
	return model, propeller
end

local function buildDock(name: string, position: Vector3, text: string): Dock
	local pad = part(Workspace, name, Vector3.new(14, 1, 14), Color3.fromRGB(150, 105, 62), Enum.Material.WoodPlanks, Enum.PartType.Cylinder)
	pad.Size = Vector3.new(1, 14, 14)
	pad.CFrame = CFrame.new(position + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
	pad.CanCollide = true
	local ring = part(Workspace, name .. "Ring", Vector3.new(0.3, 14.6, 14.6), Color3.fromRGB(255, 205, 60), Enum.Material.Neon, Enum.PartType.Cylinder)
	ring.Transparency = 0.4
	ring.CFrame = CFrame.new(position + Vector3.new(0, 1.05, 0)) * CFrame.Angles(0, 0, math.rad(90))
	local post = part(Workspace, name .. "Post", Vector3.new(0.8, 7, 0.8), Color3.fromRGB(104, 72, 48), Enum.Material.Wood)
	post.CFrame = CFrame.new(position + Vector3.new(5, 4, 0))
	post.CanCollide = true
	local anchor = part(Workspace, name .. "Sign", Vector3.new(7, 2.4, 0.4), Color3.fromRGB(235, 220, 190), Enum.Material.WoodPlanks)
	anchor.CFrame = CFrame.new(position + Vector3.new(5, 8, 0))
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Board"
	prompt.ObjectText = "Airship Taxi"
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 54)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.MaxDistance = 220
	gui.AlwaysOnTop = false
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 232, 170)
	label.TextStrokeTransparency = 0
	label.Text = text
	label.Parent = gui
	return { position = position, prompt = prompt, label = label }
end

local function setDockStates(ship: Ship)
	for index, dock in ship.docks do
		local here = ship.at == index
		dock.prompt.Enabled = here and not ship.flying
		dock.label.Text = if here and not ship.flying then (if index == 1 then "AIRSHIP: Gigachad Gate" else "AIRSHIP: Home island") else "Airship is away..."
	end
end

-- Fly the ship along `points` at Pace.taxi.speed, carrying `passengers` on the deck.
local function fly(ship: Ship, points: { Vector3 }, passengers: { Player })
	local seats = { Vector3.new(-2.4, 4.6, -4), Vector3.new(2.4, 4.6, -4), Vector3.new(-2.4, 4.6, 1), Vector3.new(2.4, 4.6, 1), Vector3.new(-2.4, 4.6, 6), Vector3.new(2.4, 4.6, 6) }
	local riders: { { player: Player, root: BasePart, humanoid: Humanoid, seat: Vector3 } } = {}
	for index, player in passengers do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
			pcall(function()
				root:SetNetworkOwner(nil) -- the server carries them
			end)
			humanoid.PlatformStand = true
			table.insert(riders, { player = player, root = root, humanoid = humanoid, seat = seats[index] or seats[1] })
		end
	end
	local yaw = ship.frame
	local position = points[1]
	for index = 2, #points do
		local target = points[index]
		while (target - position).Magnitude > 1.5 do
			local dt = task.wait()
			local step = (target - position)
			position += step.Unit * math.min(Pace.taxi.speed * dt, step.Magnitude)
			local flat = Vector3.new(step.X, 0, step.Z)
			if flat.Magnitude > 1 then
				yaw = yaw:Lerp(CFrame.lookAt(Vector3.zero, flat), math.min(1, dt * 2.5))
			end
			local bob = math.sin(os.clock() * 2) * 0.4
			ship.frame = CFrame.new(position + Vector3.new(0, bob, 0)) * (yaw - yaw.Position)
			ship.model:PivotTo(ship.frame)
			ship.propeller.CFrame = ship.frame * CFrame.new(0, 0.4, 13.4) * CFrame.Angles(os.clock() * 20 % (math.pi * 2), 0, 0)
			for _, rider in riders do
				if rider.root.Parent and rider.humanoid.Health > 0 then
					rider.root.CFrame = ship.frame * CFrame.new(rider.seat)
					rider.root.AssemblyLinearVelocity = Vector3.zero
				end
			end
		end
	end
	return riders
end

local function release(riders: any, landing: Vector3)
	for index, rider in riders do
		if rider.root.Parent then
			rider.root.CFrame = CFrame.new(landing + Vector3.new((index - 3.5) * 2.2, 4, 0))
			rider.root.AssemblyLinearVelocity = Vector3.zero
			pcall(function()
				rider.root:SetNetworkOwner(rider.player)
			end)
		end
		rider.humanoid.PlatformStand = false
	end
end

local function depart(ship: Ship)
	if ship.flying or ship.at == 0 then
		return
	end
	local from = ship.at
	local to = if from == 1 then 2 else 1
	local origin = ship.docks[from].position
	local destination = ship.docks[to].position
	local crew: { Player } = {}
	for _, player in ship.boarding do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and (root.Position - origin).Magnitude < 40 and #crew < Pace.taxi.seats then
			table.insert(crew, player)
		end
	end
	ship.boarding = {}
	ship.flying = true
	ship.at = 0
	setDockStates(ship)
	local cruise = math.max(origin.Y, destination.Y) + Pace.taxi.cruiseHeight
	local shipHeight = Pace.taxi.hoverHeight
	local points = {
		origin + Vector3.new(0, shipHeight, 0),
		Vector3.new(origin.X, cruise, origin.Z),
		Vector3.new(destination.X, cruise, destination.Z),
		destination + Vector3.new(0, shipHeight, 0),
	}
	local riders = fly(ship, points, crew)
	release(riders, destination + Vector3.new(0, 0.5, 0))
	ship.at = to
	ship.flying = false
	setDockStates(ship)
	for _, rider in riders do
		PopupSystem.send(rider.player, "pickup", 1, "Landed!")
	end
end

function TaxiSystem.init() end

function TaxiSystem.start()
	local gateCentre = Vector3.new(0, Territories.gateHeight, 0)
	for index, faction in FactionRules.factions do
		local base = MapLayout.bases[index]
		local baseCentre = Vector3.new(base.x, MapLayout.baseIslandHeight, base.z)
		local toMiddle = Vector3.new(-base.x, 0, -base.z).Unit
		local side = toMiddle:Cross(Vector3.yAxis)
		local homeDock = buildDock("TaxiDock" .. index, baseCentre - side * 30 - toMiddle * 2, "AIRSHIP: Gigachad Gate")
		local toBase = Vector3.new(base.x, 0, base.z).Unit
		local gateDock = buildDock("TaxiGateDock" .. index, gateCentre + toBase * 100, "AIRSHIP: Home island")
		local model, propeller = buildShip(FactionRules.color(faction))
		local ship: Ship = { faction = faction.id, model = model, propeller = propeller, docks = { homeDock, gateDock }, at = 1, boarding = {}, flying = false, frame = CFrame.lookAt(homeDock.position + Vector3.new(0, Pace.taxi.hoverHeight, 0), homeDock.position + Vector3.new(0, Pace.taxi.hoverHeight, 0) + toMiddle) }
		model:PivotTo(ship.frame)
		table.insert(ships, ship)
		setDockStates(ship)
		for dockIndex, dock in ship.docks do
			dock.prompt.Triggered:Connect(function(player: Player)
				if ship.at ~= dockIndex or ship.flying then
					return
				end
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if not root or not root:IsA("BasePart") or (root.Position - dock.position).Magnitude > 30 then
					return
				end
				if table.find(ship.boarding, player) or #ship.boarding >= Pace.taxi.seats then
					return
				end
				table.insert(ship.boarding, player)
				PopupSystem.send(player, "announce", 1, "All aboard! Leaving soon")
				if #ship.boarding == 1 then
					task.delay(Pace.taxi.boardSeconds, function()
						depart(ship)
					end)
				end
			end)
		end
	end
	-- the parked ships bob gently
	RunService.Heartbeat:Connect(function()
		for _, ship in ships do
			if not ship.flying and ship.at ~= 0 then
				local dock = ship.docks[ship.at]
				local frame = CFrame.new(dock.position + Vector3.new(0, Pace.taxi.hoverHeight + math.sin(os.clock() * 1.6 + ship.faction) * 0.5, 0)) * (ship.frame - ship.frame.Position)
				ship.model:PivotTo(frame)
				ship.propeller.CFrame = frame * CFrame.new(0, 0.4, 13.4) * CFrame.Angles(os.clock() * 4 % (math.pi * 2), 0, 0)
			end
		end
	end)
end

return TaxiSystem
