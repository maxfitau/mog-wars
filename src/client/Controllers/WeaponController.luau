--!strict
-- THE WEAPONS (client). Display only: the server decides every hit. This sends Remotes.UseWeapon (an aim direction from the
-- camera and, for the gauntlet, how long the button was held) and draws what the server announces on Remotes.WeaponFx
-- (kind, weaponId, stars, a, b, n, owner). Rarity only changes the look and sound: Rare and Epic sparkle, Legendary and Mythic are
-- bigger and flashier. Screen shake is for the Gigachad Gauntlet only. Per-player effects from the server (only sent to the victim):
-- "pull" (the Rizz Rose makes you walk toward the thrower), "slip" (Glow-Up Mist: you slide) and "stare" (Main Character Mic: you
-- turn to look). The ShoveController owns the button and calls WeaponController.use.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Sounds = require(Shared:WaitForChild("Sounds"))
local WeaponCatalog = require(Shared:WaitForChild("WeaponCatalog"))
local WeaponRules = require(Shared:WaitForChild("WeaponRules"))

local WeaponController = {}

local player = Players.LocalPlayer
local useRemote: RemoteEvent? = nil
local folder: Folder? = nil
local active = 0 -- effect parts alive right now (capped)

local MAX_ACTIVE = 70
local MAX_DISTANCE = 220 -- effects farther than this from the camera are skipped

-- per-player states applied to our own character
local pullUntil = 0
local pullOwner: Instance? = nil
local pullStop = 3
local stareUntil = 0
local stareTarget = Vector3.zero
local slipUntil = 0
local slipTarget = Vector3.zero
local slipVelocity = Vector3.zero
local sliding = false
local shakeUntil = 0
local shakeStrength = 0
local shakeStart = 0

local function clock(): number
	return os.clock()
end

-- ---------- sending ----------

-- The equipped weapon (from the Weapon attribute the server mirrors), or nil for plain Shove.
function WeaponController.equipped(): WeaponCatalog.Weapon?
	local id = player:GetAttribute("Weapon")
	if type(id) == "string" and id ~= "" then
		return WeaponCatalog.byId[id]
	end
	return nil
end

-- Ask the server to use the equipped weapon. `charge` is how long the button was held (gauntlet only).
function WeaponController.use(charge: number?)
	local remote = useRemote
	if not remote or not WeaponController.equipped() then
		return
	end
	local camera = Workspace.CurrentCamera
	local aim: Vector3? = if camera then camera.CFrame.LookVector else nil
	remote:FireServer(aim, charge)
end

-- ---------- drawing helpers ----------

local function effectsFolder(): Folder
	if folder and folder.Parent then
		return folder
	end
	local made = Instance.new("Folder")
	made.Name = "WeaponEffects"
	made.Parent = Workspace
	folder = made
	return made
end

local function newPart(shape: Enum.PartType, size: Vector3, cframe: CFrame, color: Color3, transparency: number, seconds: number): Part?
	if active >= MAX_ACTIVE then
		return nil
	end
	local part = Instance.new("Part")
	part.Shape = shape
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.Neon -- glow only (ART.md)
	part.Transparency = transparency
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = effectsFolder()
	active += 1
	part.Destroying:Once(function()
		active -= 1
	end)
	Debris:AddItem(part, seconds + 0.2)
	return part
end

local function tween(instance: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?)
	TweenService:Create(instance, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
end

local function colorOf(weapon: WeaponCatalog.Weapon): Color3
	return Color3.fromRGB(weapon.rgb[1], weapon.rgb[2], weapon.rgb[3])
end

-- A burst of sparkles at a point. More for flashier rarities.
local function sparkle(position: Vector3, color: Color3, count: number, speed: number)
	local anchor = newPart(Enum.PartType.Ball, Vector3.new(0.3, 0.3, 0.3), CFrame.new(position), color, 1, 1.4)
	if not anchor then
		return
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.5, 0.9)
	emitter.Speed = NumberRange.new(speed * 0.5, speed)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new(0.7, 0)
	emitter.LightEmission = 0.8
	emitter.Color = ColorSequence.new(color)
	emitter.Parent = anchor
	emitter:Emit(math.clamp(count, 1, 40))
end

-- A flat ring on the ground that grows and fades.
local function ring(position: Vector3, color: Color3, radius: number, seconds: number)
	local part = newPart(Enum.PartType.Cylinder, Vector3.new(0.4, 2, 2), CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)), color, 0.3, seconds)
	if part then
		tween(part, seconds, { Size = Vector3.new(0.4, radius * 2, radius * 2), Transparency = 1 })
	end
end

local function flash(position: Vector3, color: Color3, size: number, seconds: number)
	local part = newPart(Enum.PartType.Ball, Vector3.new(1, 1, 1), CFrame.new(position), color, 0.2, seconds)
	if part then
		tween(part, seconds, { Size = Vector3.new(size, size, size), Transparency = 1 })
	end
end

local function playSound(position: Vector3, key: string)
	if Sounds.get(key) == "" then
		return
	end
	local anchor = newPart(Enum.PartType.Ball, Vector3.new(0.2, 0.2, 0.2), CFrame.new(position), Color3.new(1, 1, 1), 1, 6)
	if anchor then
		Sounds.playAt(anchor, key, 1)
	end
end

-- The swing sound, plus the rarity sound for Rare and up.
local function useSounds(position: Vector3, weapon: WeaponCatalog.Weapon)
	playSound(position, "weapon_swing")
	local key = WeaponRules.soundKey(weapon.rarity)
	if key ~= "weapon_swing" then
		playSound(position, key)
	end
end

-- Rarity dressing for any effect: sparkles (tier 2) and a bigger flash (tier 3).
local function dress(position: Vector3, weapon: WeaponCatalog.Weapon, stars: number, scale: number)
	local tier = WeaponRules.visualTier(weapon.rarity)
	local color = colorOf(weapon)
	if tier >= 2 then
		sparkle(position, color, 8 * tier, 10 * scale)
	end
	if tier >= 3 then
		flash(position, color, 6 * scale, 0.5)
		ring(position - Vector3.new(0, 2.8, 0), Color3.new(1, 1, 1), 7 * scale, 0.5)
	end
	if WeaponRules.glowSkin(stars) then
		sparkle(position, Color3.fromRGB(255, 200, 60), 8, 8)
	end
end

local function rootOf(model: Instance?): BasePart?
	local root = model and model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function groundOf(position: Vector3): Vector3
	return position - Vector3.new(0, 2.8, 0)
end

-- ---------- one drawing function per kind ----------

local draw: { [string]: (weapon: WeaponCatalog.Weapon, stars: number, a: Vector3, b: Vector3, n: number, owner: Instance?) -> () } = {}

draw.hammer = function(weapon, stars, a, b, _n, _owner)
	local colour = colorOf(weapon)
	local spot = a + b * 0.6
	ring(groundOf(spot), colour, 5, 0.4)
	useSounds(a, weapon)
	dress(spot, weapon, stars, 1)
end

draw.gust = function(weapon, stars, a, b, n, _owner)
	local reach = b.Magnitude
	if reach < 1 then
		return
	end
	local forward = b.Unit
	local colour = Color3.new(1, 1, 1):Lerp(colorOf(weapon), 0.4)
	for index = 1, 5 do
		local angle = math.rad((index - 3) * (n / 5)) -- spread across the cone
		local direction = (CFrame.Angles(0, angle, 0) * CFrame.new(forward)).Position
		local puff = newPart(Enum.PartType.Ball, Vector3.new(1.5, 1.5, 1.5), CFrame.new(a + Vector3.new(0, 0.5, 0) + direction * 2), colour, 0.4, 0.6)
		if puff then
			tween(puff, 0.6, { Position = a + Vector3.new(0, 0.5, 0) + direction * reach, Size = Vector3.new(4, 4, 4), Transparency = 1 })
		end
	end
	useSounds(a, weapon)
	dress(a + forward * (reach * 0.5), weapon, stars, 1)
end

draw.boomerang = function(weapon, stars, a, b, n, owner)
	local range = b.Magnitude
	if range < 1 or n <= 0 then
		return
	end
	local forward = b.Unit
	local turn = a + b
	local colour = colorOf(weapon)
	local body = newPart(Enum.PartType.Block, Vector3.new(2.6, 0.9, 0.5), CFrame.new(a), Color3.fromRGB(35, 35, 50), 0, n)
	if not body then
		return
	end
	local glint = Instance.new("ParticleEmitter")
	glint.Rate = if WeaponRules.visualTier(weapon.rarity) >= 2 then 8 else 0
	glint.Lifetime = NumberRange.new(0.3, 0.5)
	glint.Speed = NumberRange.new(0, 1)
	glint.Size = NumberSequence.new(0.5, 0)
	glint.LightEmission = 0.8
	glint.Color = ColorSequence.new(colour)
	glint.Parent = body
	useSounds(a, weapon)
	local started = clock()
	local connection: RBXScriptConnection? = nil
	connection = RunService.Heartbeat:Connect(function()
		local t = clock() - started
		local leg, fraction = WeaponRules.boomerangState(t, n)
		if leg == 3 or not body.Parent then
			if connection then
				connection:Disconnect()
			end
			if body.Parent then
				dress(body.Position, weapon, stars, 0.6)
				body:Destroy()
			end
			return
		end
		local position: Vector3
		if leg == 1 then
			position = a + forward * WeaponRules.boomerangOut(range, fraction)
		else
			local home = rootOf(owner)
			position = turn:Lerp(if home then home.Position else a, fraction)
		end
		body.CFrame = CFrame.new(position) * CFrame.Angles(0, t * 18, 0)
	end)
end

draw.rose = function(weapon, stars, a, b, n, _owner)
	local colour = colorOf(weapon)
	local flight = math.max(n, 0.05)
	local start = a + Vector3.new(0, 1, 0)
	local rose = newPart(Enum.PartType.Ball, Vector3.new(1.2, 1.2, 1.2), CFrame.new(start), colour, 0, flight + 0.3)
	useSounds(a, weapon)
	if rose then
		tween(rose, flight, { Position = b + Vector3.new(0, 1, 0) }, Enum.EasingStyle.Linear)
		task.delay(flight, function()
			sparkle(b + Vector3.new(0, 2, 0), colour, 10 * WeaponRules.visualTier(weapon.rarity), 12)
			dress(b, weapon, stars, 0.8)
		end)
	end
end

draw.mist = function(weapon, stars, a, b, n, _owner)
	local radius, seconds = b.X, b.Y
	local colour = colorOf(weapon)
	local tier = WeaponRules.visualTier(weapon.rarity)
	local puddle = newPart(Enum.PartType.Cylinder, Vector3.new(0.3, radius * 2, radius * 2), CFrame.new(a + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), colour, 0.55, seconds)
	useSounds(a, weapon)
	if not puddle then
		return
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 6 * tier
	emitter.Lifetime = NumberRange.new(0.8, 1.4)
	emitter.Speed = NumberRange.new(1, 3)
	emitter.SpreadAngle = Vector2.new(25, 25)
	emitter.EmissionDirection = Enum.NormalId.Right -- a cylinder's flat face points along its X axis, which we turned to face up
	emitter.Size = NumberSequence.new(0.6, 0)
	emitter.LightEmission = 0.8
	emitter.Color = ColorSequence.new(colour)
	emitter.Parent = puddle
	task.delay(math.max(0, n - 1), function()
		if puddle.Parent then
			tween(puddle, 1, { Transparency = 1 })
			emitter.Enabled = false
		end
	end)
	dress(a + Vector3.new(0, 1, 0), weapon, stars, 1.2)
end

draw.mirror = function(weapon, stars, a, _b, n, owner)
	local colour = Color3.new(1, 1, 1):Lerp(colorOf(weapon), 0.5)
	local bubble = newPart(Enum.PartType.Ball, Vector3.new(7.5, 7.5, 7.5), CFrame.new(a), colour, 0.75, n)
	useSounds(a, weapon)
	if not bubble then
		return
	end
	local started = clock()
	local connection: RBXScriptConnection? = nil
	connection = RunService.Heartbeat:Connect(function()
		local home = rootOf(owner)
		if not bubble.Parent or not home or clock() - started >= n then
			if connection then
				connection:Disconnect()
			end
			if bubble.Parent then
				tween(bubble, 0.25, { Transparency = 1 })
			end
			return
		end
		bubble.CFrame = home.CFrame
	end)
	dress(a, weapon, stars, 1)
end

draw.shaker = function(weapon, stars, a, _b, n, _owner)
	local colour = colorOf(weapon)
	ring(groundOf(a), colour, n, 0.5)
	ring(groundOf(a), Color3.new(1, 1, 1), n * 0.6, 0.35)
	useSounds(a, weapon)
	dress(a, weapon, stars, 1.3)
end

draw.mic = function(weapon, stars, a, _b, n, _owner)
	local colour = colorOf(weapon)
	ring(groundOf(a), colour, n, 0.6)
	flash(a, colour, 5, 0.4)
	useSounds(a, weapon)
	dress(a, weapon, stars, 1.3)
end

draw.gauntlet = function(weapon, stars, a, b, n, _owner)
	local reach = b.Magnitude
	local forward = if reach > 0.1 then b.Unit else Vector3.new(0, 0, -1)
	local impact = a + forward * math.max(reach * 0.5, 3)
	local colour = colorOf(weapon)
	local big = 0.6 + 0.4 * math.clamp(n, 0, 1)
	flash(impact, colour, 9 * big, 0.45)
	ring(groundOf(impact), colour, 9 * big, 0.5)
	ring(groundOf(impact), Color3.new(1, 1, 1), 5 * big, 0.35)
	useSounds(a, weapon)
	dress(impact, weapon, stars, 1.5)
	-- screen shake is only for the gauntlet: stronger when charged and when close
	local camera = Workspace.CurrentCamera
	if camera and n > 0 then
		local distance = (camera.CFrame.Position - impact).Magnitude
		if distance < 70 then
			local strength = (0.4 + 1.1 * n) * (1 - distance / 70)
			if strength > shakeStrength * math.max(0, 1 - (clock() - shakeStart) / 0.5) then
				shakeStrength = strength
				shakeStart = clock()
				shakeUntil = clock() + 0.5
			end
		end
	end
end

draw.hit = function(weapon, _stars, a, _b, n, _owner)
	local tier = WeaponRules.visualTier(weapon.rarity)
	sparkle(a, Color3.new(1, 1, 1):Lerp(colorOf(weapon), 0.5), 6 + 4 * tier, 14)
	playSound(a, "weapon_hit")
	if n > 30 then
		flash(a, Color3.new(1, 1, 1), 5, 0.25)
	end
end

-- ---------- effects on our own character (only the server can start these) ----------

local function startPull(owner: Instance?, seconds: number)
	pullOwner = owner
	pullUntil = clock() + math.clamp(seconds, 0, 3)
end

local function startStare(at: Vector3, seconds: number)
	stareTarget = at
	stareUntil = clock() + math.clamp(seconds, 0, 3)
end

local function startSlip(drift: Vector3, seconds: number)
	local character = player.Character
	local root = rootOf(character)
	if not root then
		return
	end
	if not sliding or clock() >= slipUntil then
		local velocity = root.AssemblyLinearVelocity
		slipVelocity = Vector3.new(velocity.X, 0, velocity.Z)
	end
	sliding = true
	slipTarget = Vector3.new(drift.X, 0, drift.Z)
	slipUntil = clock() + math.clamp(seconds, 0, 1)
end

local function step(dt: number)
	local t = clock()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = rootOf(character)

	if root and humanoid and humanoid.Health > 0 then
		if t < pullUntil then
			local home = rootOf(pullOwner)
			if home then
				local flat = Vector3.new(home.Position.X - root.Position.X, 0, home.Position.Z - root.Position.Z)
				if flat.Magnitude > WeaponRules.rosePullStop() then
					humanoid:Move(flat.Unit, false) -- the rose: you walk toward them
				else
					pullUntil = 0
				end
			end
		end
		if t < stareUntil then
			humanoid.AutoRotate = false
			local flat = Vector3.new(stareTarget.X, root.Position.Y, stareTarget.Z)
			if (flat - root.Position).Magnitude > 0.5 then
				root.CFrame = CFrame.lookAt(root.Position, flat)
			end
		elseif not humanoid.AutoRotate and stareUntil > 0 then
			humanoid.AutoRotate = true
			stareUntil = 0
		end
		if sliding then
			if t < slipUntil then
				-- low steering: the puddle carries you outward, your own walking only nudges
				slipVelocity = slipVelocity:Lerp(slipTarget, 1 - 0.5 ^ (dt * 2.5))
				local nudge = humanoid.MoveDirection * humanoid.WalkSpeed * 0.3
				local velocity = root.AssemblyLinearVelocity
				root.AssemblyLinearVelocity = Vector3.new(slipVelocity.X + nudge.X, velocity.Y, slipVelocity.Z + nudge.Z)
			else
				sliding = false
			end
		end
	end

	-- screen shake (gauntlet only)
	if t < shakeUntil then
		local camera = Workspace.CurrentCamera
		if camera then
			local left = (shakeUntil - t) / 0.5
			local amount = math.rad(shakeStrength * 2.2 * left)
			camera.CFrame *= CFrame.Angles((math.random() - 0.5) * amount, (math.random() - 0.5) * amount, (math.random() - 0.5) * amount * 0.5)
		end
	end
end

-- ---------- wiring ----------

local function onFx(kind: any, weaponId: any, stars: any, a: any, b: any, n: any, owner: any)
	if type(kind) ~= "string" or type(weaponId) ~= "string" or type(stars) ~= "number" or typeof(a) ~= "Vector3" or typeof(b) ~= "Vector3" or type(n) ~= "number" then
		return
	end
	local weapon = WeaponCatalog.byId[weaponId]
	if not weapon or n ~= n or math.abs(n) > 1000 then
		return
	end
	local origin = owner
	if origin ~= nil and typeof(origin) ~= "Instance" then
		return
	end
	if kind == "pull" then
		startPull(origin :: Instance?, n)
		return
	elseif kind == "stare" then
		startStare(a :: Vector3, n)
		return
	elseif kind == "slip" then
		startSlip(b :: Vector3, n)
		return
	end
	local camera = Workspace.CurrentCamera
	if camera and ((a :: Vector3) - camera.CFrame.Position).Magnitude > MAX_DISTANCE then
		return
	end
	local handler = draw[kind]
	if handler then
		handler(weapon, math.clamp(math.floor(stars), 1, 5), a :: Vector3, b :: Vector3, n, origin :: Instance?)
	end
end

function WeaponController.init()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	useRemote = remotes:WaitForChild("UseWeapon") :: RemoteEvent
	local fx = remotes:WaitForChild("WeaponFx") :: RemoteEvent
	fx.OnClientEvent:Connect(onFx)
end

function WeaponController.start()
	RunService:BindToRenderStep("MogWarsWeaponStep", Enum.RenderPriority.Camera.Value + 3, step)
end

return WeaponController
