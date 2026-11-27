--!strict
-- RIFTS: glowing purple-and-gold swirling portals (7 of them: near each team spawn, on two far islands, and under Gigachad Gate).
-- Touch one: whoosh and flash, and you are thrown high into the sky; then you glide down slowly with a little glider you can steer
-- with normal movement, and land anywhere. A used rift flickers out for 20 seconds, then returns. Moglings use them too (they
-- are thrown up and glide down the same way). Server only; the numbers are in Pace.rift. Players steer the glider on their own
-- screen (GliderController); the server only sends the throw and a "start gliding" message.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapLayout = require(Shared:WaitForChild("MapLayout"))
local Pace = require(Shared:WaitForChild("Pace"))
local Territories = require(Shared:WaitForChild("Territories"))
local BotService = require(script.Parent:WaitForChild("BotService"))
local MovementSystem = require(script.Parent:WaitForChild("MovementSystem"))
local PopupSystem = require(script.Parent:WaitForChild("PopupSystem"))
local Events = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("Events"))

local RiftSystem = {}

type Rift = { part: Part, ring: Part, emitter: ParticleEmitter, light: PointLight, online: boolean }

local rifts: { Rift } = {}
local glideRemote: RemoteEvent? = nil
local usedAt: { [Player]: number } = {}
local gliding: { [Model]: number } = {}

local PURPLE = Color3.fromRGB(165, 80, 255)
local GOLD = Color3.fromRGB(255, 205, 60)

local function build(position: Vector3)
	local part = Instance.new("Part")
	part.Name = "Rift"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(6, 6, 6)
	part.Position = position
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Material = Enum.Material.Neon
	part.Color = PURPLE
	part.Transparency = 0.25
	part.Parent = Workspace
	local ring = Instance.new("Part") -- a gold ring round the rift
	ring.Name = "RiftRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.6, 9, 9)
	ring.CFrame = CFrame.new(position) * CFrame.Angles(0, math.rad(90), 0)
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Material = Enum.Material.Neon
	ring.Color = GOLD
	ring.Transparency = 0.2
	ring.Parent = Workspace
	local emitter = Instance.new("ParticleEmitter") -- the swirl
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(PURPLE, GOLD)
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new(1.6, 0)
	emitter.Lifetime = NumberRange.new(0.8, 1.4)
	emitter.Speed = NumberRange.new(2, 6)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 22
	emitter.Parent = part
	local light = Instance.new("PointLight")
	light.Color = PURPLE
	light.Range = 22
	light.Brightness = 2
	light.Parent = part
	CollectionService:AddTag(part, "Rift")
	local rift: Rift = { part = part, ring = ring, emitter = emitter, light = light, online = true }
	table.insert(rifts, rift)
	return rift
end

local function setOnline(rift: Rift, on: boolean)
	rift.online = on
	rift.part.Transparency = if on then 0.25 else 1
	rift.ring.Transparency = if on then 0.2 else 1
	rift.emitter.Enabled = on
	rift.light.Enabled = on
end

local function use(rift: Rift)
	setOnline(rift, false) -- flickers out ...
	PopupSystem.fx("flagburst", rift.part.Position, PURPLE) -- (a flash of light)
	task.delay(Pace.rift.offlineSeconds, function()
		setOnline(rift, true) -- ... and returns
	end)
end

-- A Mogling's glide: it falls slowly until its feet touch something.
local function mogglingGlide(bot: BotService.Bot)
	gliding[bot.model] = os.clock()
	task.spawn(function()
		task.wait(1.2)
		while bot.model.Parent and os.clock() - (gliding[bot.model] or 0) < 25 do
			local velocity = bot.root.AssemblyLinearVelocity
			if velocity.Y < -Pace.rift.glideFall then
				bot.root.AssemblyLinearVelocity = Vector3.new(velocity.X, -Pace.rift.glideFall, velocity.Z)
			end
			local hit = Workspace:Raycast(bot.root.Position, Vector3.new(0, -5, 0))
			if hit and velocity.Y <= 0 then
				break
			end
			task.wait(0.1)
		end
		gliding[bot.model] = nil
	end)
end

function RiftSystem.init()
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	local created = Instance.new("RemoteEvent")
	created.Name = "RiftGlide"
	created.Parent = folder
	glideRemote = created
	Players.PlayerRemoving:Connect(function(player)
		usedAt[player] = nil
	end)
end

function RiftSystem.start()
	-- seven rifts: beside each team spawn, on two far islands, and by the rope-ladder walkway under Gigachad Gate
	local spots: { Vector3 } = {}
	for _, base in MapLayout.bases do
		local length = math.sqrt(base.x * base.x + base.z * base.z)
		table.insert(spots, Vector3.new(base.x - base.x / length * 18, MapLayout.baseIslandHeight + 4.5, base.z - base.z / length * 18))
	end
	local canyon, village, gate = Territories.byId.cooked_canyon, Territories.byId.npc_village, Territories.byId.gigachad_gate
	table.insert(spots, Vector3.new(canyon.x + 30, canyon.height + 4.5, canyon.z - 85))
	table.insert(spots, Vector3.new(village.x, village.height + 4.5, village.z + 92))
	table.insert(spots, Vector3.new(gate.x + 28, Territories.byId.chud_chambers.height + 4.5, gate.z - 112))
	for _, spot in spots do
		build(spot)
	end
	task.spawn(function()
		while true do
			task.wait(0.15)
			local now = Workspace:GetServerTimeNow()
			for _, rift in rifts do
				if rift.online then
					for _, player in Players:GetPlayers() do
						local character = player.Character
						local root = character and character:FindFirstChild("HumanoidRootPart")
						local humanoid = character and character:FindFirstChildOfClass("Humanoid")
						if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 and (root.Position - rift.part.Position).Magnitude < 6 and now - (usedAt[player] or -100) > 3 then
							usedAt[player] = now
							MovementSystem.launch(player, Vector3.new(0, Pace.rift.launch, 0))
							if glideRemote then
								glideRemote:FireClient(player)
							end
							Events.fire(player, "rift", 1)
							use(rift)
							break
						end
					end
					if rift.online then
						for _, bot in BotService.list() do
							if (bot.root.Position - rift.part.Position).Magnitude < 6 and not gliding[bot.model] then
								bot.root.AssemblyLinearVelocity = Vector3.new(0, Pace.rift.launch, 0)
								mogglingGlide(bot)
								use(rift)
								break
							end
						end
					end
				end
			end
		end
	end)
end

return RiftSystem
