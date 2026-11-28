--!strict
-- CHARACTER REACTIONS (client). There are no animation assets, so a pose is made by nudging the C0 offsets of the R15 Motor6D
-- joints (Waist, Neck, shoulders, elbows) for a short time and then putting every joint back EXACTLY as it was. The server only
-- says who reacts and how (Remotes.Reaction: userId, kind); this plays it on that player's character:
--   "smug" : hand on both hips, chin up, a pair of black sunglasses (two parts welded to the head) with a sparkle, 2.5 s
--   "fall" : crying and flailing, blue tears from the head and a floating "NOOO" for 1.5 s
-- Works for any player, but only when they are within 150 studs of the camera (your own character always plays). One Heartbeat
-- connection runs only while a reaction is active. A reaction ends early (joints restored, parts destroyed) if the character
-- leaves the world; a smug pose also ends if the character dies. A joint that has been destroyed is skipped, never errors.
-- The pose maths is a best guess without Studio: tune the angles in `smugPose` and `fallPose` after a playtest.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local SoundController = require(script.Parent:WaitForChild("SoundController"))

local ReactionController = {}

local MAX_DISTANCE = 150
local DURATION = { smug = 2.5, fall = 1.5 } :: { [string]: number }
local BLEND_IN = 0.2
local BLEND_OUT = 0.25
local JOINT_PARTS = {
	Waist = "UpperTorso",
	Neck = "Head",
	RightShoulder = "RightUpperArm",
	RightElbow = "RightLowerArm",
	LeftShoulder = "LeftUpperArm",
	LeftElbow = "LeftLowerArm",
}

type Joint = { motor: Motor6D, base: CFrame }
type Reaction = {
	kind: string,
	character: Model,
	startedAt: number,
	duration: number,
	joints: { [string]: Joint },
	extras: { Instance },
	nextSparkle: number,
	sparkle: ParticleEmitter?,
	nameLabel: TextLabel?,
	stroke: UIStroke?,
}

local localPlayer = Players.LocalPlayer
local active: { [Model]: Reaction } = {}
local connection: RBXScriptConnection? = nil

-- Find the joints of an R15 character (missing ones are simply left out).
local function findJoints(character: Model): { [string]: Joint }
	local joints: { [string]: Joint } = {}
	for name, partName in JOINT_PARTS do
		local part = character:FindFirstChild(partName)
		local motor = part and part:FindFirstChild(name)
		if motor and motor:IsA("Motor6D") then
			joints[name] = { motor = motor, base = motor.C0 }
		end
	end
	return joints
end

-- Put every joint back exactly as it was and remove everything the reaction made.
local function finish(reaction: Reaction)
	for _, joint in reaction.joints do
		if joint.motor.Parent then
			joint.motor.C0 = joint.base
		end
	end
	for _, extra in reaction.extras do
		extra:Destroy()
	end
	if active[reaction.character] == reaction then
		active[reaction.character] = nil
	end
end

-- The offsets (rotations added to each joint's C0) for a moment `t` seconds into a pose. All angles are in radians.
local function smugPose(t: number): { [string]: CFrame }
	local sway = math.sin(t * 3)
	return {
		Waist = CFrame.Angles(0.08, 0, sway * 0.03),
		Neck = CFrame.Angles(0.32, sway * 0.12, 0), -- chin up
		RightShoulder = CFrame.Angles(0, 0, 0.55), -- elbow out
		RightElbow = CFrame.Angles(0.4, 0, -1.6), -- hand to the hip
		LeftShoulder = CFrame.Angles(0, 0, -0.55),
		LeftElbow = CFrame.Angles(0.4, 0, 1.6),
	}
end

local function fallPose(t: number): { [string]: CFrame }
	return {
		Waist = CFrame.Angles(0.1, 0, math.sin(t * 13) * 0.12),
		Neck = CFrame.Angles(0.2, 0, math.sin(t * 15) * 0.25),
		RightShoulder = CFrame.Angles(math.sin(t * 17) * 0.5, 0, 2.5 + math.sin(t * 19) * 0.6), -- arms up and flapping
		RightElbow = CFrame.Angles(math.sin(t * 21) * 0.6, 0, 0),
		LeftShoulder = CFrame.Angles(math.sin(t * 17 + 2) * 0.5, 0, -(2.5 + math.sin(t * 19 + 2) * 0.6)),
		LeftElbow = CFrame.Angles(math.sin(t * 21 + 2) * 0.6, 0, 0),
	}
end

local function addExtra(reaction: Reaction, instance: Instance)
	table.insert(reaction.extras, instance)
end

-- Two black lenses welded to the head, plus a sparkle emitter on one of them.
local function addGlasses(reaction: Reaction, head: BasePart)
	local first: BasePart? = nil
	for _, side in { -1, 1 } do
		local lens = Instance.new("Part")
		lens.Name = "SmugLens"
		lens.Size = Vector3.new(0.5, 0.28, 0.1)
		lens.Color = Color3.fromRGB(10, 10, 14)
		lens.Material = Enum.Material.SmoothPlastic
		lens.CanCollide = false
		lens.CanTouch = false
		lens.CanQuery = false
		lens.Massless = true
		lens.CFrame = head.CFrame * CFrame.new(side * 0.27, 0.1, -(head.Size.Z / 2) - 0.03)
		lens.Parent = head
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = lens
		weld.Parent = lens
		addExtra(reaction, lens)
		if first == nil then
			first = lens
		end
	end
	if first then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Rate = 0
		emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		emitter.Color = ColorSequence.new(Color3.fromRGB(255, 250, 200))
		emitter.LightEmission = 1
		emitter.Lifetime = NumberRange.new(0.4, 0.7)
		emitter.Speed = NumberRange.new(1, 2)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) })
		emitter.Parent = first
		reaction.sparkle = emitter
		reaction.nextSparkle = 0.3
	end
end

-- Blue tears and a floating NOOO over the head.
local function addCrying(reaction: Reaction, head: BasePart)
	local tears = Instance.new("ParticleEmitter")
	tears.Rate = 25
	tears.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	tears.Color = ColorSequence.new(Color3.fromRGB(90, 170, 255))
	tears.Lifetime = NumberRange.new(0.5, 0.9)
	tears.Speed = NumberRange.new(5, 9)
	tears.SpreadAngle = Vector2.new(60, 60)
	tears.Acceleration = Vector3.new(0, -30, 0)
	tears.Size = NumberSequence.new(0.25)
	tears.Parent = head
	addExtra(reaction, tears)

	local board = Instance.new("BillboardGui")
	board.Name = "NoooBillboard"
	board.Adornee = head
	board.Size = UDim2.fromOffset(150, 54)
	board.StudsOffset = Vector3.new(0, 2.6, 0)
	board.AlwaysOnTop = true
	board.MaxDistance = MAX_DISTANCE
	board.Parent = head
	addExtra(reaction, board)
	local text = Instance.new("TextLabel")
	text.Text = "NOOO"
	text.Size = UDim2.new(1, 0, 1, 0)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBlack
	text.TextScaled = true
	text.TextColor3 = Color3.new(1, 1, 1)
	text.Parent = board
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(20, 20, 40)
	stroke.Thickness = 3
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = text
	reaction.nameLabel = text
	reaction.stroke = stroke
end

-- One frame of one reaction. Returns false when it is over.
local function step(reaction: Reaction, now: number): boolean
	local character = reaction.character
	if not character:IsDescendantOf(Workspace) then
		return false
	end
	local t = now - reaction.startedAt
	if t >= reaction.duration then
		return false
	end
	if reaction.kind == "smug" then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health <= 0 then
			return false
		end
	end
	-- ease in, hold, ease out: the weight is 0 at the start and the end, so the pose never pops
	local weight = math.clamp(math.min(t / BLEND_IN, (reaction.duration - t) / BLEND_OUT), 0, 1)
	local offsets = if reaction.kind == "smug" then smugPose(t) else fallPose(t)
	for name, joint in reaction.joints do
		local offset = offsets[name]
		if offset and joint.motor.Parent then
			joint.motor.C0 = joint.base * CFrame.identity:Lerp(offset, weight)
		end
	end
	if reaction.sparkle and t >= reaction.nextSparkle then
		reaction.sparkle:Emit(2)
		reaction.nextSparkle += 0.7
	end
	if reaction.nameLabel and reaction.stroke then
		local fade = math.clamp((t - (reaction.duration - 0.3)) / 0.3, 0, 1) -- fade the text out at the end
		reaction.nameLabel.TextTransparency = fade
		reaction.stroke.Transparency = fade
	end
	return true
end

local function onHeartbeat()
	local now = os.clock()
	for _, reaction in active do
		local ok, running = pcall(step, reaction, now)
		if not ok or not running then
			finish(reaction)
		end
	end
	if next(active) == nil and connection then
		connection:Disconnect()
		connection = nil
	end
end

local function play(target: Player, kind: string)
	local character = target.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local head = character and character:FindFirstChild("Head")
	if not character or not root or not root:IsA("BasePart") or not head or not head:IsA("BasePart") then
		return
	end
	local isLocal = target == localPlayer
	local camera = Workspace.CurrentCamera
	if not isLocal and camera and (root.Position - camera.CFrame.Position).Magnitude > MAX_DISTANCE then
		return -- too far away to see: save the work
	end
	if isLocal then
		SoundController.play(if kind == "fall" then "noooo" else "smug")
	end
	local old = active[character]
	if old then
		finish(old) -- put the joints back first, so the new pose starts from the true rest pose
	end
	local reaction: Reaction = {
		kind = kind,
		character = character,
		startedAt = os.clock(),
		duration = DURATION[kind],
		joints = findJoints(character),
		extras = {},
		nextSparkle = math.huge,
		sparkle = nil,
		nameLabel = nil,
		stroke = nil,
	}
	if kind == "smug" then
		addGlasses(reaction, head)
	else
		addCrying(reaction, head)
	end
	active[character] = reaction
	if not connection then
		connection = RunService.Heartbeat:Connect(onHeartbeat)
	end
end

function ReactionController.init()
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Reaction") :: RemoteEvent
	remote.OnClientEvent:Connect(function(userId: any, kind: any)
		if type(userId) ~= "number" or (kind ~= "smug" and kind ~= "fall") then
			return -- never trust the payload, even from the server's own remote
		end
		local target = Players:GetPlayerByUserId(userId)
		if target then
			local ok, err = pcall(play, target, kind)
			if not ok then
				warn("[mog-wars] reaction failed: " .. tostring(err))
			end
		end
	end)
	-- a player who leaves mid-pose: their character is destroyed, so the loop ends the reaction on its own
end

function ReactionController.start() end

return ReactionController
