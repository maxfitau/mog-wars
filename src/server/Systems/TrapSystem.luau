--!strict
-- CHUD CHAMBERS TRAPS: cartoon, kid-friendly, server-controlled traps. NOTHING here ever hurts: a trap knocks you back, flings
-- you, or slimes you ("TRAPPED!") and sends you to the dungeon entrance after a moment. Every trap telegraphs (glows and
-- shakes) about Pace.traps.warnSeconds before it fires. Players and Moglings are hit alike, so Moglings sometimes fail.
-- Knocking an enemy that you shoved recently into a trap pays "TRAP SHOVE!" (seconds of income). This module is a library:
-- ChudChambers.luau builds the dungeon and calls the functions below, so everything runs from the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Pace = require(Shared:WaitForChild("Pace"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local PopupSystem = require(script.Parent:WaitForChild("PopupSystem"))
local MovementSystem = require(script.Parent:WaitForChild("MovementSystem"))
local BotService = require(script.Parent:WaitForChild("BotService"))
local StealSystem = require(script.Parent:WaitForChild("StealSystem"))

local TrapSystem = {}

type Actor = { root: BasePart, humanoid: Humanoid, player: Player?, bot: any? }

local hitCooldown: { [BasePart]: number } = setmetatable({}, { __mode = "k" }) :: any
local entrance = Vector3.new(0, 5, 0)

function TrapSystem.setEntrance(position: Vector3)
	entrance = position
end

local function actors(): { Actor }
	local list: { Actor } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 and player:GetAttribute("Ziplining") ~= true then
			table.insert(list, { root = root, humanoid = humanoid, player = player })
		end
	end
	for _, bot in BotService.list() do
		if BotService.isAlive(bot) then
			table.insert(list, { root = bot.root, humanoid = bot.humanoid, player = nil, bot = bot })
		end
	end
	return list
end

local function playSound(at: Vector3, id: string)
	if id == "" then
		return
	end
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Transparency = 1
	part.Position = at
	part.Parent = Workspace
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.RollOffMaxDistance = 120
	sound.Parent = part
	sound:Play()
	Debris:AddItem(part, 4)
end

-- Shoving an enemy into a trap pays the shover.
local function credit(victim: Actor)
	local victimPlayer = victim.player
	if not victimPlayer then
		return
	end
	local attacker = StealSystem.recentAttacker(victimPlayer, Pace.traps.shoveWindowSeconds)
	if attacker and attacker ~= victimPlayer then
		local shown = DataService.addAura(attacker, Pace.traps.shoveSeconds * Pace.levels.nominalIncome)
		PopupSystem.send(attacker, "trapshove", 1, "")
		if shown > 0 then
			PopupSystem.send(attacker, "aura", shown, "")
		end
	end
end

-- Can this actor be hit right now? (a short cooldown so one swing cannot hit twice)
local function ready(actor: Actor, seconds: number?): boolean
	local now = os.clock()
	if now < (hitCooldown[actor.root] or 0) then
		return false
	end
	hitCooldown[actor.root] = now + (seconds or 1.2)
	return true
end

-- Throw an actor away along `direction` (flat) with a little hop.
function TrapSystem.knock(actor: Actor, direction: Vector3, power: number?)
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 0.01 then
		flat = Vector3.xAxis
	end
	local strength = power or Pace.traps.knock
	if actor.player then
		MovementSystem.launch(actor.player, flat.Unit * strength + Vector3.new(0, 28, 0))
	elseif actor.bot then
		BotService.knockback(actor.bot, flat.Unit.X, flat.Unit.Z, strength / 3.5)
	end
	credit(actor)
end

-- Slime an actor: "TRAPPED!", a green glow, a funny hold, then back to `backTo` (the entrance by default).
function TrapSystem.trapped(actor: Actor, backTo: Vector3?)
	local destination = backTo or entrance
	local character = actor.root.Parent
	if actor.player then
		PopupSystem.send(actor.player, "trapped", 1, "")
		MovementSystem.freeze(actor.player, Pace.traps.trappedSeconds)
	elseif actor.bot then
		BotService.stun(actor.bot, Pace.traps.trappedSeconds)
	end
	if character then
		local glow = Instance.new("Highlight")
		glow.FillColor = Color3.fromRGB(110, 230, 70)
		glow.OutlineColor = Color3.fromRGB(190, 255, 120)
		glow.FillTransparency = 0.35
		glow.Parent = character
		Debris:AddItem(glow, Pace.traps.trappedSeconds)
	end
	playSound(actor.root.Position, Pace.traps.sounds.slime)
	credit(actor)
	task.delay(Pace.traps.trappedSeconds, function()
		if actor.root.Parent and actor.humanoid.Health > 0 then
			actor.root.CFrame = CFrame.new(destination)
			actor.root.AssemblyLinearVelocity = Vector3.zero
		end
	end)
end

local function neonPart(folder: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	if shape then
		part.Shape = shape
	end
	part.Parent = folder
	return part
end

-- A part that jiggles for `seconds` (the telegraph).
local function shake(parts: { Part }, seconds: number)
	local origins = {}
	for index, part in parts do
		origins[index] = part.CFrame
	end
	local start = os.clock()
	while os.clock() - start < seconds do
		for index, part in parts do
			part.CFrame = origins[index] * CFrame.new((math.random() - 0.5) * 0.5, (math.random() - 0.5) * 0.3, (math.random() - 0.5) * 0.5)
		end
		task.wait(0.04)
	end
	for index, part in parts do
		part.CFrame = origins[index]
	end
end

-- 1. SWINGING GAMING CHAIRS: a chair on a chain swings across the walkway on a rhythm. `pivot` is the ceiling point,
-- `along` the flat direction it swings in. Hit = knocked back the way it is swinging.
function TrapSystem.swingingChair(folder: Instance, pivot: Vector3, along: Vector3, length: number, amplitude: number, period: number, phase: number)
	local model = Instance.new("Model")
	model.Name = "SwingingChair"
	local hub = neonPart(model, "Pivot", Vector3.new(1, 1, 1), CFrame.new(pivot), Color3.fromRGB(60, 60, 70))
	hub.Transparency = 1
	model.PrimaryPart = hub
	local chain = neonPart(model, "Chain", Vector3.new(0.4, length, 0.4), CFrame.new(pivot - Vector3.new(0, length / 2, 0)), Color3.fromRGB(170, 170, 185))
	chain.Material = Enum.Material.Metal
	local seatAt = pivot - Vector3.new(0, length, 0)
	local seat = neonPart(model, "Seat", Vector3.new(4, 1, 4), CFrame.new(seatAt), Color3.fromRGB(235, 50, 80))
	seat.Material = Enum.Material.SmoothPlastic
	local back = neonPart(model, "Back", Vector3.new(4, 5, 1), CFrame.new(seatAt + Vector3.new(0, 2.8, -2)), Color3.fromRGB(235, 50, 80))
	back.Material = Enum.Material.SmoothPlastic
	local glow = neonPart(model, "Glow", Vector3.new(4.2, 0.5, 4.2), CFrame.new(seatAt - Vector3.new(0, 0.8, 0)), Color3.fromRGB(255, 230, 60))
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 90, 90)
	light.Range = 16
	light.Parent = glow
	model.Parent = folder
	local axis = along.Unit:Cross(Vector3.yAxis)
	RunService.Heartbeat:Connect(function()
		if not model.Parent then
			return
		end
		local t = Workspace:GetServerTimeNow()
		local angle = amplitude * math.sin(t * 2 * math.pi / period + phase)
		local frame = CFrame.new(pivot) * CFrame.fromAxisAngle(axis, -angle)
		model:PivotTo(frame)
		local velocitySign = math.cos(t * 2 * math.pi / period + phase)
		local seatPosition = frame:PointToWorldSpace(Vector3.new(0, -length, 0))
		light.Brightness = 1 + math.abs(angle / amplitude) * 2 -- glows brighter at the ends of the swing
		for _, actor in actors() do
			local offset = actor.root.Position - seatPosition
			if offset.Magnitude < 5.5 and ready(actor) then
				playSound(seatPosition, Pace.traps.sounds.boom)
				TrapSystem.knock(actor, along * (if velocitySign >= 0 then 1 else -1))
			end
		end
	end)
end

-- 2. ROLLING CRISP-BAG BOULDER: step on the plate, the plate glows and the bag rattles for a second, then it rolls
-- from `from` to `to`. Dodge sideways.
function TrapSystem.boulder(folder: Instance, plateAt: Vector3, from: Vector3, to: Vector3)
	local plate = neonPart(folder, "BoulderPlate", Vector3.new(7, 0.5, 7), CFrame.new(plateAt + Vector3.new(0, 0.25, 0)), Color3.fromRGB(255, 190, 40))
	plate.CanCollide = true
	local bag = neonPart(folder, "CrispBagBoulder", Vector3.new(9, 9, 9), CFrame.new(from), Color3.fromRGB(235, 70, 60), Enum.PartType.Ball)
	bag.Material = Enum.Material.Foil
	bag.Transparency = 0.0
	local label = Instance.new("BillboardGui")
	label.Size = UDim2.fromOffset(160, 40)
	label.AlwaysOnTop = false
	label.Parent = bag
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = "CHUD CRUNCH"
	text.Font = Enum.Font.GothamBlack
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(255, 235, 90)
	text.TextStrokeTransparency = 0
	text.Parent = label
	bag.Position = from + Vector3.new(0, 4.5, 0)
	local busy = false
	task.spawn(function()
		while folder.Parent do
			task.wait(0.15)
			if not busy then
				for _, actor in actors() do
					local offset = actor.root.Position - plateAt
					if math.sqrt(offset.X ^ 2 + offset.Z ^ 2) < 3.5 and math.abs(offset.Y) < 6 then
						busy = true
						plate.Color = Color3.fromRGB(255, 50, 50)
						playSound(plateAt, Pace.traps.sounds.warn)
						shake({ bag }, Pace.traps.warnSeconds)
						local start = from + Vector3.new(0, 4.5, 0)
						local finish = to + Vector3.new(0, 4.5, 0)
						local travel = (finish - start)
						local seconds = travel.Magnitude / 22
						local begun = os.clock()
						local roll = 0
						while os.clock() - begun < seconds do
							local fraction = (os.clock() - begun) / seconds
							local position = start + travel * fraction
							roll += 0.3
							bag.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, roll)
							for _, victim in actors() do
								local away = victim.root.Position - position
								if away.Magnitude < 7.5 and ready(victim) then
									playSound(position, Pace.traps.sounds.boom)
									local side = Vector3.new(away.X, 0, away.Z)
									TrapSystem.knock(victim, if side.Magnitude > 1 then side else travel.Unit:Cross(Vector3.yAxis))
								end
							end
							task.wait()
						end
						bag.Position = from + Vector3.new(0, 4.5, 0)
						task.wait(5)
						plate.Color = Color3.fromRGB(255, 190, 40)
						busy = false
						break
					end
				end
			end
		end
	end)
end

-- 3. ENERGY-DRINK CAN AVALANCHE: a plate drops a pile of cans over `region` (centre, size); anyone under them is knocked
-- along `knockDir` (back toward the hall).
function TrapSystem.canAvalanche(folder: Instance, plateAt: Vector3, regionCentre: Vector3, regionSize: Vector3, knockDir: Vector3, ceilingY: number)
	local plate = neonPart(folder, "CanPlate", Vector3.new(6, 0.5, 6), CFrame.new(plateAt + Vector3.new(0, 0.25, 0)), Color3.fromRGB(80, 210, 255))
	plate.CanCollide = true
	local colours = { Color3.fromRGB(80, 220, 120), Color3.fromRGB(255, 210, 60), Color3.fromRGB(70, 140, 255), Color3.fromRGB(255, 90, 60) }
	local cans: { Part } = {}
	for index = 1, 16 do
		local can = neonPart(folder, "EnergyCan", Vector3.new(1.6, 3, 1.6), CFrame.new(regionCentre + Vector3.new((math.random() - 0.5) * regionSize.X, ceilingY - 1.5, (math.random() - 0.5) * regionSize.Z)), colours[index % 4 + 1], Enum.PartType.Cylinder)
		can.Material = Enum.Material.Metal
		can.Orientation = Vector3.new(0, 0, 90)
		table.insert(cans, can)
	end
	local homes: { CFrame } = {}
	for index, can in cans do
		homes[index] = can.CFrame
	end
	local busy = false
	task.spawn(function()
		while folder.Parent do
			task.wait(0.15)
			if not busy then
				for _, actor in actors() do
					local offset = actor.root.Position - plateAt
					if math.sqrt(offset.X ^ 2 + offset.Z ^ 2) < 3.2 and math.abs(offset.Y) < 6 then
						busy = true
						plate.Color = Color3.fromRGB(255, 50, 50)
						playSound(plateAt, Pace.traps.sounds.warn)
						shake(cans, Pace.traps.warnSeconds)
						for index, can in cans do
							local landing = Vector3.new(homes[index].Position.X, regionCentre.Y + 1.5, homes[index].Position.Z)
							TweenService:Create(can, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = landing }):Play()
						end
						task.wait(0.5)
						playSound(regionCentre, Pace.traps.sounds.boom)
						for _, victim in actors() do
							local offsetV = victim.root.Position - regionCentre
							if math.abs(offsetV.X) < regionSize.X / 2 + 1 and math.abs(offsetV.Z) < regionSize.Z / 2 + 1 and offsetV.Y > -4 and offsetV.Y < 14 and ready(victim, 2) then
								TrapSystem.knock(victim, knockDir)
							end
						end
						task.wait(3)
						for index, can in cans do
							can.CFrame = homes[index]
						end
						task.wait(4)
						plate.Color = Color3.fromRGB(80, 210, 255)
						busy = false
						break
					end
				end
			end
		end
	end)
end

-- 4. COLLAPSING PIZZA-BOX FLOOR over a cheese-dust goo pit: every few seconds some tiles crack (orange, shaking) and drop.
-- At least one tile in each row stays safe. `columns` x `rows` tiles of `tile` studs, centred on `centre` (the floor level).
function TrapSystem.pizzaFloor(folder: Instance, centre: Vector3, columns: number, rows: number, tile: number)
	local grid: { { Part } } = {}
	local base = Color3.fromRGB(240, 215, 160)
	local alt = Color3.fromRGB(225, 120, 60)
	for column = 1, columns do
		grid[column] = {}
		for row = 1, rows do
			local position = centre + Vector3.new((column - (columns + 1) / 2) * tile, -0.5, (row - (rows + 1) / 2) * tile)
			local part = Instance.new("Part")
			part.Name = "PizzaBoxTile"
			part.Size = Vector3.new(tile - 0.2, 1, tile - 0.2)
			part.Position = position
			part.Anchored = true
			part.Color = if (column + row) % 2 == 0 then base else alt
			part.Material = Enum.Material.Cardboard
			part.Parent = folder
			grid[column][row] = part
		end
	end
	task.spawn(function()
		while folder.Parent do
			task.wait(5)
			local cracked: { Part } = {}
			for column = 1, columns do
				local safe = math.random(1, rows)
				for row = 1, rows do
					if row ~= safe and math.random() < 0.6 then
						table.insert(cracked, grid[column][row])
					end
				end
			end
			for _, part in cracked do
				part.Color = Color3.fromRGB(255, 110, 40)
				part.Material = Enum.Material.Neon
			end
			playSound(centre, Pace.traps.sounds.warn)
			local homes = {}
			for index, part in cracked do
				homes[index] = part.CFrame
			end
			shake(cracked, Pace.traps.warnSeconds + 0.4)
			for _, part in cracked do
				part.CanCollide = false
				TweenService:Create(part, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = part.Position - Vector3.new(0, 10, 0), Transparency = 1 }):Play()
			end
			task.wait(4)
			for index, part in cracked do
				part.CFrame = homes[index]
				part.Transparency = 0
				part.CanCollide = true
				part.Material = Enum.Material.Cardboard
				part.Color = if (index % 2) == 0 then base else alt
			end
		end
	end)
end

-- 5. RGB KEYBOARD LASER GRID: rainbow beams sweep slowly back and forth along a corridor. Touch one and you are zapped back to
-- `backTo` (the corridor start). The beams are low enough to jump. `start`/`finish` are the ends of the sweep (floor points).
function TrapSystem.laserGrid(folder: Instance, start: Vector3, finish: Vector3, width: number, beams: number, backTo: Vector3)
	local travel = finish - start
	local lasers: { Part } = {}
	for index = 1, beams do
		local beam = neonPart(folder, "RgbLaser", Vector3.new(width, 0.7, 0.7), CFrame.new(start), Color3.new(1, 0, 0))
		beam.CFrame = CFrame.lookAt(start, start + travel) * CFrame.Angles(0, math.rad(90), 0)
		local light = Instance.new("PointLight")
		light.Range = 10
		light.Parent = beam
		table.insert(lasers, beam)
	end
	local axis = travel.Unit
	local sideAxis = axis:Cross(Vector3.yAxis).Unit
	RunService.Heartbeat:Connect(function()
		if not folder.Parent then
			return
		end
		local t = Workspace:GetServerTimeNow()
		local positions: { Vector3 } = {}
		for index, beam in lasers do
			local fraction = 0.5 + 0.5 * math.sin(t * 0.7 + index * 2 * math.pi / beams)
			local position = start + travel * fraction + Vector3.new(0, 0.9, 0)
			positions[index] = position
			beam.CFrame = CFrame.fromMatrix(position, sideAxis, Vector3.yAxis, -axis) -- the beam lies across the corridor
			local colour = Color3.fromHSV((t * 0.4 + index / beams) % 1, 1, 1)
			beam.Color = colour
			local light = beam:FindFirstChildOfClass("PointLight")
			if light then
				light.Color = colour
			end
		end
		for _, actor in actors() do
			local feet = actor.root.Position - Vector3.new(0, 3, 0)
			for _, position in positions do
				local offset = feet - position
				local along = offset:Dot(axis)
				local across = offset:Dot(sideAxis)
				if math.abs(along) < 1.1 and math.abs(across) < width / 2 + 0.5 and math.abs(offset.Y) < 1.2 and ready(actor, 3) then
					playSound(position, Pace.traps.sounds.zap)
					TrapSystem.trapped(actor, backTo)
					break
				end
			end
		end
	end)
end

-- 6. MIMIC MINI-FRIDGE: looks like any fridge. Get close and it glares red for a second, then CHOMPS and spits you out
-- along `spitDir` (back where you came from).
function TrapSystem.mimic(folder: Instance, position: Vector3, spitDir: Vector3)
	local body = Instance.new("Part")
	body.Name = "MimicFridge"
	body.Size = Vector3.new(4, 7, 4)
	body.Position = position + Vector3.new(0, 3.5, 0)
	body.Anchored = true
	body.Color = Color3.fromRGB(235, 235, 240)
	body.Material = Enum.Material.Metal
	body.Parent = folder
	local door = Instance.new("Part")
	door.Name = "MimicDoor"
	door.Size = Vector3.new(0.4, 6.4, 3.6)
	door.CFrame = CFrame.new(position + Vector3.new(0, 3.5, 0) + spitDir.Unit * 2.2)
	door.Anchored = true
	door.CanCollide = false
	door.Color = Color3.fromRGB(245, 245, 250)
	door.Material = Enum.Material.Metal
	door.Parent = folder
	local eyes: { Part } = {}
	for _, side in { -1, 1 } do
		local eye = neonPart(folder, "MimicEye", Vector3.new(0.8, 0.8, 0.8), CFrame.new(position + Vector3.new(0, 5, 0) + spitDir.Unit * 2.5 + spitDir.Unit:Cross(Vector3.yAxis) * side), Color3.fromRGB(255, 40, 40), Enum.PartType.Ball)
		eye.Transparency = 1
		table.insert(eyes, eye)
	end
	local teeth: { Part } = {}
	for index = -2, 2 do
		local tooth = neonPart(folder, "MimicTooth", Vector3.new(0.5, 1.2, 0.5), CFrame.new(position + Vector3.new(0, 1.5, 0) + spitDir.Unit * 2.6 + spitDir.Unit:Cross(Vector3.yAxis) * index * 0.7), Color3.new(1, 1, 1))
		tooth.Transparency = 1
		table.insert(teeth, tooth)
	end
	local busy = false
	task.spawn(function()
		while folder.Parent do
			task.wait(0.15)
			if not busy then
				for _, actor in actors() do
					local offset = actor.root.Position - body.Position
					if math.sqrt(offset.X ^ 2 + offset.Z ^ 2) < 6 and math.abs(offset.Y) < 6 then
						busy = true
						for _, eye in eyes do
							eye.Transparency = 0
						end
						playSound(position, Pace.traps.sounds.warn)
						shake({ body }, Pace.traps.warnSeconds)
						for _, tooth in teeth do
							tooth.Transparency = 0
						end
						door.CFrame *= CFrame.Angles(0, math.rad(70), 0) -- the door swings open: CHOMP
						playSound(position, Pace.traps.sounds.chomp)
						for _, victim in actors() do
							local d = victim.root.Position - body.Position
							if math.sqrt(d.X ^ 2 + d.Z ^ 2) < 7 and ready(victim, 3) then
								TrapSystem.knock(victim, spitDir, 48)
							end
						end
						task.wait(1.5)
						door.CFrame *= CFrame.Angles(0, math.rad(-70), 0)
						for _, tooth in teeth do
							tooth.Transparency = 1
						end
						for _, eye in eyes do
							eye.Transparency = 1
						end
						task.wait(6)
						busy = false
						break
					end
				end
			end
		end
	end)
end

-- Fart-gas style vent is not part of Chud Chambers (only the six traps above and the treasure room).

local claimed: { [number]: number } = {}

-- The hidden treasure chest: a big aura burst, once per war per player.
function TrapSystem.treasure(folder: Instance, position: Vector3)
	local chest = Instance.new("Part")
	chest.Name = "TreasureChest"
	chest.Size = Vector3.new(5, 3.4, 3.4)
	chest.Position = position + Vector3.new(0, 1.7, 0)
	chest.Anchored = true
	chest.Color = Color3.fromRGB(255, 200, 40)
	chest.Material = Enum.Material.Neon
	chest.Parent = folder
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 220, 100)
	light.Range = 22
	light.Parent = chest
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open Treasure"
	prompt.ObjectText = "Chud Hoard"
	prompt.HoldDuration = 0.8
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = chest
	prompt.Triggered:Connect(function(player: Player)
		local war = Workspace:GetAttribute("WarNumber")
		local current = if type(war) == "number" then war else 0
		if claimed[player.UserId] == current or Workspace:GetAttribute("WarPhase") ~= "War" then
			return
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") or (root.Position - chest.Position).Magnitude > 16 then
			return
		end
		claimed[player.UserId] = current
		local shown = DataService.addAura(player, Pace.traps.treasureSeconds * Pace.levels.nominalIncome)
		if shown > 0 then
			PopupSystem.send(player, "aura", shown, "")
		end
		PopupSystem.send(player, "announce", 1, "TREASURE ROOM FOUND!")
	end)
end

return TrapSystem
