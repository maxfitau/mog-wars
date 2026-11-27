--!strict
-- After a rift throws you into the sky, you glide down: a small glider over your head, a slow fall, and you steer with your normal
-- movement. You land anywhere; the glider vanishes when your feet touch something. Your own character only; the server decided that
-- you were thrown. Display and movement of your own character, with a cap on how fast you can fall slowly (Pace.rift).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local Pace = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Pace"))

local GliderController = {}

local player = Players.LocalPlayer
local gliding = false

local function dust(position: Vector3)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = position
	anchor.Parent = Workspace
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(235, 225, 205))
	emitter.Size = NumberSequence.new(2, 5)
	emitter.Transparency = NumberSequence.new(0.4, 1)
	emitter.Lifetime = NumberRange.new(0.5, 0.9)
	emitter.Speed = NumberRange.new(4, 9)
	emitter.SpreadAngle = Vector2.new(80, 80)
	emitter.Rate = 0
	emitter.Parent = anchor
	emitter:Emit(8) -- a small dust puff when you land
	Debris:AddItem(anchor, 1.5)
end

function GliderController.init() end

function GliderController.start()
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RiftGlide") :: RemoteEvent
	remote.OnClientEvent:Connect(function()
		if gliding then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not root or not root:IsA("BasePart") or not humanoid then
			return
		end
		gliding = true
		local glider = Instance.new("Part") -- a little glider: a flat bright disc above your head
		glider.Name = "Glider"
		glider.Shape = Enum.PartType.Cylinder
		glider.Size = Vector3.new(0.5, 13, 13)
		glider.Material = Enum.Material.Neon
		glider.Color = Color3.fromRGB(255, 205, 60)
		glider.CanCollide = false
		glider.CanQuery = false
		glider.CanTouch = false
		glider.Massless = true
		glider.Transparency = 0.15
		glider.Parent = character
		local started = os.clock()
		local connection: RBXScriptConnection? = nil
		local function finish()
			if connection then
				connection:Disconnect()
			end
			glider:Destroy()
			gliding = false
			if root.Parent then
				dust(root.Position - Vector3.new(0, 2.5, 0))
			end
		end
		connection = RunService.Heartbeat:Connect(function()
			if not root.Parent or humanoid.Health <= 0 then
				finish()
				return
			end
			glider.CFrame = root.CFrame * CFrame.new(0, 6.5, 0) * CFrame.Angles(0, 0, math.rad(90))
			local velocity = root.AssemblyLinearVelocity
			local elapsed = os.clock() - started
			if elapsed > 1.0 and velocity.Y < 0 then -- over the top of the throw: now glide
				local move = humanoid.MoveDirection
				root.AssemblyLinearVelocity = Vector3.new(move.X * Pace.rift.glideSpeed, math.max(velocity.Y, -Pace.rift.glideFall), move.Z * Pace.rift.glideSpeed)
				if humanoid.FloorMaterial ~= Enum.Material.Air then
					finish()
				end
			elseif elapsed > 30 then
				finish()
			end
		end)
	end)
end

return GliderController
