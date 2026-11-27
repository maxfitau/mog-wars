--!strict
-- Mog combat on the client: input, crosshair, aura charge, ego, hit feedback and aura blast effects. The client only
-- ASKS ("I fired toward this direction") and DISPLAYS; the server owns health, ammo, hits and rewards.
--  PC: over-the-shoulder camera while armed, click to shoot, 1/2/3 to switch weapon, R to reload.
--  Mobile: big FIRE button bottom-right, a weapon button, and a light aim assist toward enemies near the crosshair.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatRules = require(Shared:WaitForChild("CombatRules"))
local HintRules = require(Shared:WaitForChild("HintRules"))
local Weapons = require(Shared:WaitForChild("Weapons"))
local UiTheme = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("UiTheme"))

local CombatController = {}

local player = Players.LocalPlayer
local combat = Weapons.combat
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local MAX_TRACERS = 24
local MAX_MARKS = 30

local gui: ScreenGui
local crosshair: Frame
local hitmarker: Frame
local flash: Frame
local arrow: TextLabel
local ammoLabel: TextLabel
local healthFill: Frame
local respawnLabel: TextLabel
local hotbar: { [string]: TextButton } = {}
local fireButton: TextButton? = nil
local shakeUntil = 0
local remotes: Folder
local tracers = 0
local marks = 0
local lastTap: { [Enum.KeyCode]: number } = {}
local cursorFree = false -- press Q (or hold Left Alt) to get the mouse back for buttons

local function attr(name: string, default: any): any
	local value = player:GetAttribute(name)
	if value == nil then
		return default
	end
	return value
end

local function armed(): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0 and attr("Island", "war") ~= "training" and attr("Faction", 0) ~= 0
		and Workspace:GetAttribute("WarPhase") == "War"
end

local function owned(id: string): boolean
	for _, value in string.split(attr("WeaponsOwned", "aurablaster"), ",") do
		if value == id then
			return true
		end
	end
	return false
end

local function playSound(id: string, volume: number)
	if id == "" then
		return -- no licensed sound ids yet; the hitmarker and shake carry the feedback
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.Parent = gui
	sound:Play()
	Debris:AddItem(sound, 3)
end

-- Where the crosshair is pointing, from the camera. Returns the unit direction from the player's head.
local function aimDirection(): Vector3?
	local camera = Workspace.CurrentCamera
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not camera or not head or not head:IsA("BasePart") then
		return nil
	end
	local viewport = camera.ViewportSize
	local ray = camera:ViewportPointToRay(viewport.X / 2, viewport.Y / 2)
	local direction = ray.Direction
	if isMobile then
		-- light aim assist: nudge toward the nearest enemy within a few degrees of the crosshair
		local enemies: { { number } } = {}
		local myFaction = attr("Faction", 0)
		for _, other in Workspace:GetChildren() do
			if other:IsA("Model") and other ~= character and other:GetAttribute("IsBot") == true and other:GetAttribute("Faction") ~= myFaction then
				local root = other:FindFirstChild("HumanoidRootPart")
				if root and root:IsA("BasePart") then
					local offset = root.Position - ray.Origin
					table.insert(enemies, { offset.X, offset.Y, offset.Z })
				end
			end
		end
		for _, other in Players:GetPlayers() do
			local otherCharacter = other.Character
			local root = otherCharacter and otherCharacter:FindFirstChild("HumanoidRootPart")
			if other ~= player and root and root:IsA("BasePart") and other:GetAttribute("Faction") ~= myFaction then
				local offset = root.Position - ray.Origin
				table.insert(enemies, { offset.X, offset.Y, offset.Z })
			end
		end
		local ax, ay, az = CombatRules.aimAssist(direction.X, direction.Y, direction.Z, enemies, combat.aimAssistDegrees)
		direction = Vector3.new(ax, ay, az)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character :: Instance }
	local weapon = Weapons.list[attr("Weapon", "aurablaster")] or Weapons.list.aurablaster
	local result = Workspace:Raycast(ray.Origin, direction * 400, params)
	local target = if result then result.Position else ray.Origin + direction * math.max(weapon.range, 60)
	local toTarget = target - head.Position
	if toTarget.Magnitude < 1 then
		return direction.Unit
	end
	return toTarget.Unit
end

local function fire()
	if not armed() then
		return
	end
	local direction = aimDirection()
	if not direction then
		return
	end
	local remote = remotes:FindFirstChild("FireWeapon") :: RemoteEvent?
	if remote then
		remote:FireServer(direction.X, direction.Y, direction.Z)
	end
	shakeUntil = os.clock() + 0.08 -- a small kick for the shooter
end

local function equip(id: string)
	if owned(id) then
		local remote = remotes:FindFirstChild("EquipWeapon") :: RemoteEvent?
		if remote then
			remote:FireServer(id)
		end
	end
end

local function cycleWeapon()
	local current = attr("Weapon", "aurablaster")
	local index = table.find(Weapons.order, current) or 1
	for step = 1, #Weapons.order do
		local id = Weapons.order[(index - 1 + step) % #Weapons.order + 1]
		if owned(id) then
			equip(id)
			return
		end
	end
end

local function makeLabel(parent: Instance, text: string, size: UDim2, position: UDim2, anchor: Vector2): TextLabel
	local label = Instance.new("TextLabel")
	label.AnchorPoint = anchor
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Font = UiTheme.font
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeColor3 = UiTheme.outline
	label.TextStrokeTransparency = 0
	label.Parent = parent
	return label
end

local function buildHud()
	gui = Instance.new("ScreenGui")
	gui.Name = "CombatHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")

	flash = Instance.new("Frame")
	flash.Size = UDim2.new(1, 0, 1, 0)
	flash.BackgroundColor3 = Color3.fromRGB(255, 40, 40)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Parent = gui

	crosshair = Instance.new("Frame")
	crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
	crosshair.Position = UDim2.new(0.5, 0, 0.5, 0)
	crosshair.Size = UDim2.new(0, 28, 0, 28)
	crosshair.BackgroundTransparency = 1
	crosshair.Visible = false
	crosshair.Parent = gui
	local ring = Instance.new("UIStroke")
	ring.Color = Color3.new(1, 1, 1)
	ring.Thickness = 3
	ring.Parent = crosshair
	UiTheme.round(crosshair, UDim.new(1, 0))
	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.new(0.5, 0, 0.5, 0)
	dot.Size = UDim2.new(0, 4, 0, 4)
	dot.BackgroundColor3 = Color3.new(1, 1, 1)
	dot.BorderSizePixel = 0
	dot.Parent = crosshair

	hitmarker = Instance.new("Frame")
	hitmarker.AnchorPoint = Vector2.new(0.5, 0.5)
	hitmarker.Position = UDim2.new(0.5, 0, 0.5, 0)
	hitmarker.Size = UDim2.new(0, 36, 0, 36)
	hitmarker.BackgroundTransparency = 1
	hitmarker.Visible = false
	hitmarker.Parent = gui
	for _, rotation in { 45, -45 } do
		local bar = Instance.new("Frame")
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.new(0.5, 0, 0.5, 0)
		bar.Size = UDim2.new(0, 5, 1, 0)
		bar.Rotation = rotation
		bar.BackgroundColor3 = Color3.new(1, 1, 1)
		bar.BorderSizePixel = 0
		bar.Parent = hitmarker
	end

	arrow = makeLabel(gui, "▲", UDim2.new(0, 60, 0, 60), UDim2.new(0.5, 0, 0.5, 0), Vector2.new(0.5, 0.5))
	arrow.TextColor3 = Color3.fromRGB(255, 70, 70)
	arrow.Visible = false

	-- health bar, bottom centre
	local barBack = Instance.new("Frame")
	barBack.AnchorPoint = Vector2.new(0.5, 1)
	barBack.Position = UDim2.new(0.5, 0, 1, -16)
	barBack.Size = UDim2.new(0, 260, 0, 22)
	barBack.BackgroundColor3 = UiTheme.panel
	barBack.Parent = gui
	UiTheme.round(barBack, UDim.new(0, 11))
	UiTheme.outlineBox(barBack)
	healthFill = Instance.new("Frame")
	healthFill.Size = UDim2.new(1, 0, 1, 0)
	healthFill.BackgroundColor3 = UiTheme.colors.green
	healthFill.BorderSizePixel = 0
	healthFill.Parent = barBack
	UiTheme.round(healthFill, UDim.new(0, 11))
	local egoLabel = makeLabel(barBack, "EGO", UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), Vector2.new(0, 0))
	egoLabel.ZIndex = 3

	-- ammo near the fire button (bottom-right)
	ammoLabel = makeLabel(gui, "", UDim2.new(0, 150, 0, 34), UDim2.new(1, -20, 1, if isMobile then -170 else -70), Vector2.new(1, 1))
	ammoLabel.TextXAlignment = Enum.TextXAlignment.Right

	respawnLabel = makeLabel(gui, "", UDim2.new(0, 420, 0, 60), UDim2.new(0.5, 0, 0.4, 0), Vector2.new(0.5, 0.5))
	respawnLabel.Visible = false

	-- hotbar: 1 / 2 / 3 on PC, one cycle button on mobile
	if not isMobile then
		for index, id in Weapons.order do
			local weapon = Weapons.list[id]
			local button = Instance.new("TextButton")
			button.Size = UDim2.new(0, 110, 0, 46)
			button.Position = UDim2.new(0.5, (index - 2) * 118, 1, -50)
			button.AnchorPoint = Vector2.new(0.5, 1)
			button.Font = UiTheme.font
			button.TextScaled = true
			button.TextColor3 = Color3.new(1, 1, 1)
			button.Text = ("       %d  %s"):format(index, weapon.name)
			button.Parent = gui
			local badge = Instance.new("TextLabel") -- the weapon icon: a round badge with its letter
			badge.Size = UDim2.new(0, 30, 0, 30)
			badge.Position = UDim2.new(0, 6, 0.5, -15)
			badge.BackgroundColor3 = Color3.new(1, 1, 1)
			badge.TextColor3 = Color3.fromRGB(35, 25, 60)
			badge.Font = UiTheme.font
			badge.TextScaled = true
			badge.Text = weapon.icon
			badge.Parent = button
			UiTheme.round(badge, UDim.new(1, 0))
			UiTheme.round(button, UDim.new(0, 14))
			UiTheme.outlineBox(button)
			button.Activated:Connect(function()
				equip(id)
			end)
			hotbar[id] = button
		end
	else
		local fireBtn = Instance.new("TextButton")
		fireBtn.AnchorPoint = Vector2.new(1, 1)
		fireBtn.Size = UDim2.new(0, 120, 0, 120)
		fireBtn.Position = UDim2.new(1, -24, 1, -34)
		fireBtn.BackgroundColor3 = UiTheme.colors.red
		fireBtn.Font = UiTheme.font
		fireBtn.TextScaled = true
		fireBtn.TextColor3 = Color3.new(1, 1, 1)
		fireBtn.Text = "FIRE"
		fireBtn.Parent = gui
		UiTheme.round(fireBtn, UDim.new(1, 0))
		UiTheme.outlineBox(fireBtn)
		fireBtn.Activated:Connect(function()
			fire()
		end)
		fireButton = fireBtn

		local swap = Instance.new("TextButton")
		swap.AnchorPoint = Vector2.new(1, 1)
		swap.Size = UDim2.new(0, 76, 0, 76)
		swap.Position = UDim2.new(1, -160, 1, -34)
		swap.BackgroundColor3 = UiTheme.colors.blue
		swap.Font = UiTheme.font
		swap.TextScaled = true
		swap.TextColor3 = Color3.new(1, 1, 1)
		swap.Text = "SWAP"
		swap.Parent = gui
		UiTheme.round(swap, UDim.new(1, 0))
		UiTheme.outlineBox(swap)
		swap.Activated:Connect(cycleWeapon)

		local dashBtn = Instance.new("TextButton")
		dashBtn.AnchorPoint = Vector2.new(1, 1)
		dashBtn.Size = UDim2.new(0, 76, 0, 76)
		dashBtn.Position = UDim2.new(1, -248, 1, -34)
		dashBtn.BackgroundColor3 = UiTheme.colors.green
		dashBtn.Font = UiTheme.font
		dashBtn.TextScaled = true
		dashBtn.TextColor3 = Color3.new(1, 1, 1)
		dashBtn.Text = "DASH"
		dashBtn.Parent = gui
		UiTheme.round(dashBtn, UDim.new(1, 0))
		UiTheme.outlineBox(dashBtn)
		dashBtn.Activated:Connect(function()
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			local look = Workspace.CurrentCamera and Workspace.CurrentCamera.CFrame.LookVector or Vector3.zAxis
			local move = if humanoid and humanoid.MoveDirection.Magnitude > 0.1 then humanoid.MoveDirection else Vector3.new(look.X, 0, look.Z)
			local flat = Vector3.new(move.X, 0, move.Z)
			if flat.Magnitude > 0.1 then
				local unit = flat.Unit
				local dash = remotes:FindFirstChild("DashRequest") :: RemoteEvent?
				if dash then
					dash:FireServer(unit.X, unit.Z)
				end
			end
		end)
	end
end

local function showHit(mogged: boolean)
	hitmarker.Visible = true
	hitmarker.Size = UDim2.new(0, if mogged then 54 else 36, 0, if mogged then 54 else 36)
	playSound(combat.sounds.hit, 0.6)
	task.delay(0.12, function()
		hitmarker.Visible = false
	end)
end

local function showDamage(from: Vector3)
	flash.BackgroundTransparency = 0.6
	TweenService:Create(flash, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
	local camera = Workspace.CurrentCamera
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if camera and root and root:IsA("BasePart") then
		local toAttacker = from - root.Position
		local look = camera.CFrame.LookVector
		arrow.Rotation = HintRules.arrowAngle(toAttacker.X, toAttacker.Z, look.X, look.Z)
		-- put the arrow on a ring around the crosshair, pointing at the attacker
		local radians = math.rad(arrow.Rotation)
		arrow.Position = UDim2.new(0.5, math.sin(radians) * 110, 0.5, -math.cos(radians) * 110)
		arrow.Visible = true
		task.delay(0.8, function()
			arrow.Visible = false
		end)
	end
end

local function newGlow(shape: Enum.PartType, size: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Shape = shape
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.Neon -- a glowing aura blast
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	return part
end

-- One aura blast in the shooter's faction colour. "blast" is a glowing ball, "cone" a smaller ball (the flex shockwave
-- is drawn separately), "beam" a thin stare line that fades.
local function drawShot(origin: Vector3, endPoint: Vector3, color: Color3, style: string)
	if tracers >= MAX_TRACERS then
		return
	end
	local length = (endPoint - origin).Magnitude
	if length < 1 then
		return
	end
	tracers += 1
	if style == "beam" then
		local beam = newGlow(Enum.PartType.Block, Vector3.new(0.35, 0.35, length), color)
		beam.CFrame = CFrame.lookAt((origin + endPoint) / 2, endPoint)
		beam.Parent = Workspace
		local tween = TweenService:Create(beam, TweenInfo.new(0.2), { Transparency = 1, Size = Vector3.new(0.05, 0.05, length) })
		tween.Completed:Connect(function()
			tracers -= 1
			beam:Destroy()
		end)
		tween:Play()
		return
	end
	local diameter = if style == "cone" then 0.7 else 1.1
	local ball = newGlow(Enum.PartType.Ball, Vector3.new(diameter, diameter, diameter), color)
	ball.CFrame = CFrame.new(origin)
	ball.Parent = Workspace
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 8
	light.Parent = ball
	local travel = math.clamp(length / 220, 0.05, 0.6)
	local tween = TweenService:Create(ball, TweenInfo.new(travel, Enum.EasingStyle.Linear), { Position = endPoint })
	tween.Completed:Connect(function()
		tracers -= 1
		ball:Destroy()
	end)
	tween:Play()
end

-- The Flex Blast shockwave: a glowing dome that rushes out in a cone and fades.
local function drawFlex(origin: Vector3, direction: Vector3, color: Color3, range: number)
	local wave = newGlow(Enum.PartType.Ball, Vector3.new(3, 3, 3), color)
	wave.Transparency = 0.35
	wave.CFrame = CFrame.lookAt(origin + direction * 2, origin + direction * 10)
	wave.Parent = Workspace
	local reach = math.min(range, 40)
	local tween = TweenService:Create(wave, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(reach * 0.5, reach * 0.35, reach * 0.2),
		Transparency = 1,
		CFrame = CFrame.lookAt(origin + direction * (reach * 0.5), origin + direction * (reach * 0.5 + 10)),
	})
	tween.Completed:Connect(function()
		wave:Destroy()
	end)
	tween:Play()
end

-- Where a blast landed: a short-lived aura sparkle (nothing stays on the walls).
local function drawMark(position: Vector3, normal: Vector3, color: Color3)
	if marks >= MAX_MARKS then
		return
	end
	marks += 1
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.CFrame = CFrame.lookAt(position + normal * 0.2, position + normal)
	anchor.Parent = Workspace
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	sparkle.LightEmission = 1
	sparkle.Size = NumberSequence.new(0.9, 0)
	sparkle.Lifetime = NumberRange.new(0.4, 0.8)
	sparkle.Speed = NumberRange.new(4, 9)
	sparkle.SpreadAngle = Vector2.new(70, 70)
	sparkle.Rate = 0
	sparkle.Parent = anchor
	sparkle:Emit(6)
	Debris:AddItem(anchor, 1.2)
	task.delay(1.2, function()
		marks -= 1
	end)
end

local function drawPoof(position: Vector3, color: Color3)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = position
	anchor.Parent = Workspace
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.Size = NumberSequence.new(2.5, 0)
	emitter.Lifetime = NumberRange.new(0.5, 0.9)
	emitter.Speed = NumberRange.new(8, 16)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 0
	emitter.Parent = anchor
	emitter:Emit(18) -- a small burst only (phone-friendly)
	Debris:AddItem(anchor, 1.5)
end

local function refresh()
	local on = armed()
	crosshair.Visible = on
	ammoLabel.Visible = on
	local weaponId = attr("Weapon", "aurablaster")
	local ammo = attr("Ammo", 0)
	local mag = attr("MagSize", 0)
	local reloadUntil = attr("ReloadUntil", 0)
	local serverNow = Workspace:GetServerTimeNow()
	local weaponName = (Weapons.list[weaponId] or Weapons.list.aurablaster).name
	ammoLabel.Text = if reloadUntil > serverNow then "Recharging..." else ("%s  Aura charge %d/%d"):format(weaponName, ammo, mag)
	local health = attr("CombatHealth", combat.health)
	healthFill.Size = UDim2.new(math.clamp(health / combat.health, 0, 1), 0, 1, 0)
	healthFill.BackgroundColor3 = if health > 50 then UiTheme.colors.green elseif health > 25 then UiTheme.colors.orange else UiTheme.colors.red
	for id, button in hotbar do
		local has = owned(id)
		button.BackgroundColor3 = if id == weaponId then UiTheme.colors.orange elseif has then UiTheme.colors.blue else UiTheme.colors.grey
		button.TextTransparency = if has then 0 else 0.5
	end
	local respawnAt = attr("RespawnAt", 0)
	if respawnAt > serverNow and health <= 0 then
		respawnLabel.Visible = true
		respawnLabel.Text = ("REDUCED TO NPC... back in %d"):format(math.ceil(respawnAt - serverNow))
	else
		respawnLabel.Visible = false
	end
	-- small zoom for the Side-Eye Sniper
	local camera = Workspace.CurrentCamera
	if camera then
		local weapon = Weapons.list[weaponId]
		local wanted = if on and weapon and weapon.zoom > 0 then 70 - weapon.zoom * 0.6 else 70
		camera.FieldOfView += (wanted - camera.FieldOfView) * 0.2
	end
end

-- Over-the-shoulder view while armed on PC: the camera sits a little to the right and the body turns to the aim.
local function shoulder()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local camera = Workspace.CurrentCamera
	if not humanoid or not root or not root:IsA("BasePart") or not camera then
		return
	end
	local free = cursorFree or UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt)
	if armed() and not isMobile and not free then
		humanoid.CameraOffset = humanoid.CameraOffset:Lerp(Vector3.new(2.2, 0.8, 0), 0.2)
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		humanoid.AutoRotate = false
		local look = camera.CFrame.LookVector
		root.CFrame = CFrame.lookAt(root.Position, root.Position + Vector3.new(look.X, 0, look.Z))
	else
		humanoid.CameraOffset = humanoid.CameraOffset:Lerp(Vector3.zero, 0.2)
		humanoid.AutoRotate = true
		if not isMobile and UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default -- the mouse is yours again
		end
	end
end

function CombatController.init() end

function CombatController.start()
	remotes = ReplicatedStorage:WaitForChild("Remotes")
	buildHud()

	local feedback = remotes:WaitForChild("CombatFeedback") :: RemoteEvent
	feedback.OnClientEvent:Connect(function(kind: any, a: any, b: any)
		if kind == "hit" and type(a) == "boolean" then
			showHit(a)
		elseif kind == "damage" and typeof(a) == "Vector3" then
			showDamage(a)
		end
	end)
	local fx = remotes:WaitForChild("CombatFx") :: RemoteEvent
	fx.OnClientEvent:Connect(function(kind: any, a: any, b: any, c: any, d: any)
		if kind == "shot" and typeof(a) == "Vector3" and typeof(b) == "Vector3" and typeof(c) == "Color3" then
			drawShot(a, b, c, if type(d) == "string" then d else "blast")
			playSound(combat.sounds.fire, 0.4)
		elseif kind == "flex" and typeof(a) == "Vector3" and typeof(b) == "Vector3" and typeof(c) == "Color3" and type(d) == "number" then
			drawFlex(a, b, c, d)
		elseif kind == "mark" and typeof(a) == "Vector3" and typeof(b) == "Vector3" and typeof(c) == "Color3" then
			drawMark(a, b, c)
		elseif kind == "poof" and typeof(a) == "Vector3" and typeof(b) == "Color3" then
			drawPoof(a, b)
			playSound(combat.sounds.mog, 0.7)
		end
	end)

	-- world launches (jump pads, launch pads) and the dash: the server decides, this client applies it
	local function rootPart(): BasePart?
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		return if root and root:IsA("BasePart") then root else nil
	end
	local launch = remotes:WaitForChild("WorldLaunch") :: RemoteEvent
	launch.OnClientEvent:Connect(function(velocity: any)
		local root = rootPart()
		if root and typeof(velocity) == "Vector3" and velocity.Magnitude < 400 then
			root.AssemblyLinearVelocity = velocity
		end
	end)
	local dashGo = remotes:WaitForChild("DashGo") :: RemoteEvent
	dashGo.OnClientEvent:Connect(function(dx: any, dz: any, speed: any, seconds: any)
		if type(dx) ~= "number" or type(dz) ~= "number" or type(speed) ~= "number" or type(seconds) ~= "number" then
			return
		end
		local untilTime = os.clock() + math.clamp(seconds, 0.05, 0.5)
		local connection: RBXScriptConnection? = nil
		connection = RunService.Heartbeat:Connect(function()
			local root = rootPart()
			if not root or os.clock() > untilTime then
				if connection then
					connection:Disconnect()
				end
				return
			end
			root.AssemblyLinearVelocity = Vector3.new(dx * speed, root.AssemblyLinearVelocity.Y, dz * speed)
		end)
	end)
	local tapKeys = { [Enum.KeyCode.W] = 1, [Enum.KeyCode.A] = 2, [Enum.KeyCode.S] = 3, [Enum.KeyCode.D] = 4 }

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local tap = tapKeys[input.KeyCode]
		if tap then
			-- double-tap a direction to dash that way
			local last = lastTap[input.KeyCode]
			lastTap[input.KeyCode] = os.clock()
			local camera = Workspace.CurrentCamera
			if last and os.clock() - last < 0.3 and camera and armed() then
				local look = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z).Unit
				local right = Vector3.new(camera.CFrame.RightVector.X, 0, camera.CFrame.RightVector.Z).Unit
				local direction = if tap == 1 then look elseif tap == 3 then -look elseif tap == 2 then -right else right
				local dash = remotes:FindFirstChild("DashRequest") :: RemoteEvent?
				if dash then
					dash:FireServer(direction.X, direction.Z)
				end
				lastTap[input.KeyCode] = nil
			end
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			fire()
		elseif input.KeyCode == Enum.KeyCode.One then
			equip(Weapons.order[1])
		elseif input.KeyCode == Enum.KeyCode.Two then
			equip(Weapons.order[2])
		elseif input.KeyCode == Enum.KeyCode.Three then
			equip(Weapons.order[3])
		elseif input.KeyCode == Enum.KeyCode.Q then
			cursorFree = not cursorFree -- toggle: free mouse for clicking buttons, or locked for aiming
		elseif input.KeyCode == Enum.KeyCode.T then
			local travel = remotes:FindFirstChild("TravelRequest") :: RemoteEvent?
			if travel then
				travel:FireServer(if attr("Island", "war") == "training" then "war" else "training") -- T: train / back to war
			end
		elseif input.KeyCode == Enum.KeyCode.R then
			local remote = remotes:FindFirstChild("ReloadRequest") :: RemoteEvent?
			if remote then
				remote:FireServer()
			end
		end
	end)

	RunService:BindToRenderStep("MogWarsCombat", Enum.RenderPriority.Camera.Value + 1, function()
		shoulder()
		local camera = Workspace.CurrentCamera
		if camera and os.clock() < shakeUntil then
			camera.CFrame *= CFrame.Angles(math.rad((math.random() - 0.5) * 0.8), math.rad((math.random() - 0.5) * 0.8), 0)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.1)
			refresh()
		end
	end)
end

return CombatController
