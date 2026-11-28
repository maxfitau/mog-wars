--!strict
-- TEAM MASCOTS: on each team's spawn island a giant statue of the mascot (the island's centrepiece, with banners in the team
-- colour) and a small animated mascot NPC that idles, waves when a player walks near, and cheers (hops, spins, confetti)
-- whenever its team captures a territory. Server only; the mascots themselves are built by Lib/Mascots.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FactionRules = require(Shared:WaitForChild("FactionRules"))
local MapLayout = require(Shared:WaitForChild("MapLayout"))
local Mascots = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("Mascots"))
local CaptureSystem = require(script.Parent:WaitForChild("CaptureSystem"))

local MascotSystem = {}

type Npc = { built: Mascots.Built, origin: CFrame, rootLocal: CFrame, cheerUntil: number, faction: number, scale: number }

local npcs: { [number]: Npc } = {}

local function confetti(position: Vector3, colour: Color3)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = position
	anchor.Parent = Workspace
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, colour), ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 215, 80)) })
	emitter.Size = NumberSequence.new(0.6)
	emitter.Speed = NumberRange.new(14, 28)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Lifetime = NumberRange.new(1, 2)
	emitter.Acceleration = Vector3.new(0, -24, 0)
	emitter.Rate = 0
	emitter.Parent = anchor
	emitter:Emit(40)
	Debris:AddItem(anchor, 3)
end

function MascotSystem.init() end

function MascotSystem.start()
	local height = MapLayout.baseIslandHeight
	for index, faction in FactionRules.factions do
		local base = MapLayout.bases[index]
		local centre = Vector3.new(base.x, height, base.z)
		local toMiddle = Vector3.new(-base.x, 0, -base.z).Unit
		local side = toMiddle:Cross(Vector3.yAxis)
		local colour = FactionRules.color(faction)
		-- the giant statue, beside the spawn pad, facing it
		local statuePosition = centre + side * 30 - toMiddle * 6
		local statueFacing = (centre - statuePosition) * Vector3.new(1, 0, 1)
		Mascots.build(faction.id, CFrame.lookAt(statuePosition, statuePosition + statueFacing), 2.2, true, colour)
		-- the little mascot NPC near the pad, facing the middle of the map
		local npcPosition = centre + toMiddle * 15 - side * 8
		local origin = CFrame.lookAt(npcPosition, npcPosition + toMiddle)
		local built = Mascots.build(faction.id, origin, 0.55, false, colour)
		npcs[faction.id] = { built = built, origin = origin, rootLocal = origin:ToObjectSpace(built.root.CFrame), cheerUntil = 0, faction = faction.id, scale = 0.55 }
	end
	CaptureSystem.captureListeners[#CaptureSystem.captureListeners + 1] = function(_name: string, owner: number)
		local npc = npcs[owner]
		if npc then
			npc.cheerUntil = os.clock() + 5
			confetti(npc.origin.Position + Vector3.new(0, 6, 0), FactionRules.color(FactionRules.factions[owner]))
		end
	end
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.066 then
			return
		end
		accumulator = 0
		local t = os.clock()
		for _, npc in npcs do
			local cheering = t < npc.cheerUntil
			local near = false
			for _, player in Players:GetPlayers() do
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if root and root:IsA("BasePart") and (root.Position - npc.origin.Position).Magnitude < 32 then
					near = true
					break
				end
			end
			local bob = math.sin(t * 2 + npc.faction) * 0.12 * npc.scale * 4
			local hop, spin = 0, 0
			if cheering then
				hop = math.abs(math.sin(t * 7)) * 3.2 * npc.scale * 3
				spin = t * 6
			end
			local base = npc.origin * CFrame.new(0, bob + hop, 0) * CFrame.Angles(0, spin, 0)
			npc.built.model:PivotTo(base * npc.rootLocal)
			local arm = npc.built.arm
			local pivot, armLocal = npc.built.armPivot, npc.built.armLocal
			if arm and pivot and armLocal then
				local angle = if cheering then math.rad(110 + math.sin(t * 12) * 25) elseif near then math.rad(60 + math.sin(t * 8) * 28) else math.rad(8)
				arm.CFrame = base * pivot * CFrame.Angles(0, 0, -angle) * pivot:Inverse() * armLocal
			end
		end
	end)
end

return MascotSystem
