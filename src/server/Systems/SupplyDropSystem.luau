--!strict
-- SUPPLY DROPS: about every 45s during a war a crate floats down on a balloon trailing coloured smoke. Hold E (or hold the
-- button on a phone) for 1.5s to open it; being shoved interrupts the hold. Rewards are free and random: a big aura burst,
-- Main Character Mode (2x aura, golden glow), a Protein Shake (speed), or a rare free cosmetic (a trail or a title).
-- 1 in 8 drops is a GOLD crate with better rewards, announced to the whole server. NEVER SOLD. Server only; numbers in
-- Pace.drops. Rewards are "seconds of income" (DataService scales them by level).

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Sounds = require(Shared:WaitForChild("Sounds"))
local Pace = require(Shared:WaitForChild("Pace"))
local Territories = require(Shared:WaitForChild("Territories"))
local CosmeticCatalog = require(Shared:WaitForChild("CosmeticCatalog"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local PopupSystem = require(script.Parent:WaitForChild("PopupSystem"))
local MovementSystem = require(script.Parent:WaitForChild("MovementSystem"))

local SupplyDropSystem = {}

local active = 0

local function announce(text: string)
	for _, player in Players:GetPlayers() do
		PopupSystem.send(player, "announce", 1, text)
	end
end

local function ground(x: number, z: number): Vector3
	local result = Workspace:Raycast(Vector3.new(x, 600, z), Vector3.new(0, -1200, 0))
	return if result then result.Position else Vector3.new(x, 100, z)
end

local function pick(weights: { [string]: number }): string
	local total = 0
	for _, weight in weights do
		total += weight
	end
	local roll = math.random() * total
	for id, weight in weights do
		roll -= weight
		if roll <= 0 then
			return id
		end
	end
	return "aura"
end

local function confetti(position: Vector3)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Transparency = 1
	part.Size = Vector3.one
	part.Position = position
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 90)), ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 220, 70)),
		ColorSequenceKeypoint.new(0.66, Color3.fromRGB(90, 220, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 110, 255)),
	})
	emitter.Size = NumberSequence.new(0.6)
	emitter.Speed = NumberRange.new(18, 34)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Lifetime = NumberRange.new(1, 1.8)
	emitter.Acceleration = Vector3.new(0, -30, 0)
	emitter.Rate = 0
	emitter.Parent = part
	part.Parent = Workspace
	emitter:Emit(70)
	Debris:AddItem(part, 3)
	Sounds.playAt(part, "drop_open")
end

local function giveMainCharacter(player: Player, seconds: number)
	player:SetAttribute("MainCharacterUntil", Workspace:GetServerTimeNow() + seconds)
	local character = player.Character
	if character then
		local glow = Instance.new("Highlight")
		glow.Name = "MainCharacterGlow"
		glow.FillColor = Color3.fromRGB(255, 215, 80)
		glow.OutlineColor = Color3.new(1, 1, 1)
		glow.FillTransparency = 0.55
		glow.Parent = character
		Debris:AddItem(glow, seconds)
	end
end

-- Open a crate for a player: roll the reward (free) and give it.
local function reward(player: Player, gold: boolean)
	local roll = pick(if gold then Pace.drops.goldWeights else Pace.drops.weights)
	if roll == "cosmetic" then
		local options = {}
		for _, item in CosmeticCatalog.items do
			if item.source == "box" and (item.slot == "trail" or item.slot == "title") then
				table.insert(options, item)
			end
		end
		for i = #options, 2, -1 do
			local j = math.random(1, i)
			options[i], options[j] = options[j], options[i]
		end
		for _, item in options do
			if DataService.grantCosmetic(player, item.id) then
				PopupSystem.send(player, "pickup", 1, "New: " .. item.name)
				return
			end
		end
		roll = "aura" -- owns them all: a big aura burst instead
	end
	if roll == "main" then
		local seconds = if gold then Pace.drops.goldMainCharacterSeconds else Pace.drops.mainCharacterSeconds
		giveMainCharacter(player, seconds)
		PopupSystem.send(player, "pickup", 1, "Main Character Mode")
	elseif roll == "shake" then
		MovementSystem.boost(player, "shake", Pace.speed.shake.boost, Pace.drops.shakeSeconds)
		PopupSystem.send(player, "pickup", 1, "Protein Shake")
	else
		local seconds = if gold then Pace.drops.goldAuraSeconds else Pace.drops.auraSeconds
		local shown = DataService.addAura(player, seconds * Pace.levels.nominalIncome)
		if shown > 0 then
			PopupSystem.send(player, "aura", shown, "")
		end
	end
end

-- Drop one crate. `gold` forces the kind (nil = roll 1 in 8). `position` is optional (nil = a random island).
function SupplyDropSystem.drop(gold: boolean?, position: Vector3?): boolean
	if active >= 4 then
		return false
	end
	local isGold = if gold ~= nil then gold else math.random(1, Pace.drops.goldOneIn) == 1
	local landing = position
	if not landing then
		local islands = {}
		for _, territory in Territories.list do
			if territory.radius > 40 then
				table.insert(islands, territory)
			end
		end
		local island = islands[math.random(1, #islands)]
		local angle, distance = math.random() * math.pi * 2, math.random() * island.radius * 0.6
		landing = ground(island.x + math.cos(angle) * distance, island.z + math.sin(angle) * distance)
	end
	local land: Vector3 = landing :: Vector3
	active += 1
	local smoke = if isGold then Color3.fromRGB(255, 200, 40) else Color3.fromRGB(80, 220, 230)

	local model = Instance.new("Model")
	model.Name = if isGold then "GoldSupplyCrate" else "SupplyCrate"
	local crate = Instance.new("Part")
	crate.Name = "Crate"
	crate.Size = Vector3.new(4.5, 4, 4.5)
	crate.Material = Enum.Material.Wood
	crate.Color = if isGold then Color3.fromRGB(255, 200, 40) else Color3.fromRGB(70, 130, 210)
	crate.Anchored = true
	crate.CanCollide = true
	crate.Parent = model
	local balloon = Instance.new("Part")
	balloon.Name = "Balloon"
	balloon.Shape = Enum.PartType.Ball
	balloon.Size = Vector3.new(9, 10, 9)
	balloon.Material = Enum.Material.SmoothPlastic
	balloon.Color = if isGold then Color3.fromRGB(255, 225, 90) else Color3.fromRGB(235, 80, 100)
	balloon.Anchored = true
	balloon.CanCollide = false
	balloon.CanQuery = false
	balloon.Parent = model
	local emitter = Instance.new("ParticleEmitter") -- the coloured smoke trail
	emitter.Color = ColorSequence.new(smoke)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 7) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(3, 5)
	emitter.Rate = 30
	emitter.Speed = NumberRange.new(0, 2)
	emitter.LightEmission = 0.3
	emitter.Parent = crate
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 44)
	gui.StudsOffset = Vector3.new(0, 9, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 5000
	gui.Parent = crate
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = if isGold then "GOLD SUPPLY DROP" else "SUPPLY DROP"
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = smoke
	label.TextStrokeTransparency = 0
	label.Parent = gui
	model.PrimaryPart = crate
	model.Parent = Workspace
	Workspace:SetAttribute("SupplyDropCount", (Workspace:GetAttribute("SupplyDropCount") or 0) + 1)
	if isGold then
		announce("GOLD SUPPLY DROP! Go go go!")
	end

	local landY = land.Y + crate.Size.Y / 2
	local startY = landY + 180
	crate.Position = Vector3.new(land.X, startY, land.Z)
	balloon.Position = crate.Position + Vector3.new(0, 11, 0)
	local rope = Instance.new("Part") -- a thin rope between the crate and the balloon
	rope.Size = Vector3.new(0.2, 8, 0.2)
	rope.Anchored = true
	rope.CanCollide = false
	rope.CanQuery = false
	rope.Position = crate.Position + Vector3.new(0, 6, 0)
	rope.Parent = model
	local fall = TweenService:Create(crate, TweenInfo.new(Pace.drops.fallSeconds, Enum.EasingStyle.Sine), { Position = Vector3.new(land.X, landY, land.Z) })
	local fallBalloon = TweenService:Create(balloon, TweenInfo.new(Pace.drops.fallSeconds, Enum.EasingStyle.Sine), { Position = Vector3.new(land.X, landY + 11, land.Z) })
	local fallRope = TweenService:Create(rope, TweenInfo.new(Pace.drops.fallSeconds, Enum.EasingStyle.Sine), { Position = Vector3.new(land.X, landY + 6, land.Z) })
	fall:Play()
	fallBalloon:Play()
	fallRope:Play()

	task.spawn(function()
		fall.Completed:Wait()
		Sounds.playAt(crate, if isGold then "drop_gold" else "drop_land")
		-- the balloon floats away
		TweenService:Create(balloon, TweenInfo.new(4), { Position = balloon.Position + Vector3.new(0, 80, 0), Transparency = 1 }):Play()
		rope:Destroy()
		Debris:AddItem(balloon, 4)
		local opened = false
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Open"
		prompt.ObjectText = if isGold then "GOLD Supply Drop" else "Supply Drop"
		prompt.HoldDuration = Pace.drops.holdSeconds
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = crate
		local holders: { [Player]: Vector3 } = {}
		prompt.PromptButtonHoldBegan:Connect(function(player)
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				holders[player] = root.Position
			end
		end)
		prompt.PromptButtonHoldEnded:Connect(function(player)
			holders[player] = nil
		end)
		local watch = RunService.Heartbeat:Connect(function()
			for player, startPosition in holders do
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				-- a shove (frozen, or knocked away) interrupts the hold: toggling the prompt cancels it
				if MovementSystem.isFrozen(player) or not root or not root:IsA("BasePart") or (root.Position - startPosition).Magnitude > 6 then
					holders[player] = nil
					prompt.Enabled = false
					task.delay(0.3, function()
						if prompt.Parent then
							prompt.Enabled = true
						end
					end)
				end
			end
		end)
		prompt.Triggered:Connect(function(player)
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if opened or not root or not root:IsA("BasePart") or MovementSystem.isFrozen(player) or (root.Position - crate.Position).Magnitude > 20 then
				return
			end
			opened = true
			watch:Disconnect()
			confetti(crate.Position + Vector3.new(0, 3, 0))
			reward(player, isGold)
			model:Destroy()
			active -= 1
		end)
		task.delay(Pace.drops.lifetimeSeconds, function()
			if not opened then
				opened = true
				watch:Disconnect()
				model:Destroy()
				active -= 1
			end
		end)
	end)
	return true
end

function SupplyDropSystem.init() end

function SupplyDropSystem.start()
	task.spawn(function()
		while true do
			task.wait(Pace.drops.everySeconds)
			if Workspace:GetAttribute("WarPhase") == "War" then
				SupplyDropSystem.drop(nil, nil)
			end
		end
	end)
end

return SupplyDropSystem
