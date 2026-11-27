--!strict
-- The rank-unlocked ability buttons, bottom right next to the big SHOVE button: DASH (Rookie, key Q) and STARE (Sigma,
-- key F). At most three ability buttons in all (with SHOVE). The server decides everything (rank, cooldown, who gets
-- frozen); this only asks and shows the cooldown. Never sold: you earn them by ranking up.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Pace = require(Shared:WaitForChild("Pace"))
local UiTheme = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("UiTheme"))

local AbilityController = {}

local player = Players.LocalPlayer

-- The six ranked abilities, oldest to newest. Only Shove (its own big button) plus the player's TWO NEWEST abilities are
-- ever shown: bottom right on a phone, Q and R on a PC (E is Shove).
type Ability = { id: string, label: string, rank: number, readyAttr: string, cooldown: number, color: Color3 }
local ABILITIES: { Ability } = {
	{ id = "dash", label = "DASH", rank = Pace.abilities.dash.rank, readyAttr = "DashReadyAt", cooldown = Pace.speed.dash.cooldownSeconds, color = Color3.fromRGB(70, 210, 100) },
	{ id = "stare", label = "STARE", rank = Pace.abilities.stare.rank, readyAttr = "StareReadyAt", cooldown = Pace.abilities.stare.cooldownSeconds, color = Color3.fromRGB(80, 170, 255) },
	{ id = "slam", label = "SLAM", rank = Pace.abilities.slam.rank, readyAttr = "SlamReadyAt", cooldown = Pace.abilities.slam.cooldownSeconds, color = Color3.fromRGB(255, 130, 60) },
	{ id = "flip", label = "FLIP", rank = Pace.abilities.flip.rank, readyAttr = "FlipReadyAt", cooldown = Pace.abilities.flip.cooldownSeconds, color = Color3.fromRGB(255, 110, 190) },
	{ id = "shield", label = "SHIELD", rank = Pace.abilities.shield.rank, readyAttr = "ShieldReadyAt", cooldown = Pace.abilities.shield.cooldownSeconds, color = Color3.fromRGB(255, 205, 60) },
	{ id = "total", label = "MOG!", rank = Pace.abilities.total.rank, readyAttr = "TotalReadyAt", cooldown = Pace.abilities.total.cooldownSeconds, color = Color3.fromRGB(190, 110, 255) },
}

type Slot = { button: TextButton, shade: Frame, key: string, ability: Ability? }
local slots: { Slot } = {}
local actions: { [string]: () -> () } = {}

local function makeSlot(gui: ScreenGui, offsetX: number, key: string): Slot
	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(1, 1)
	button.Position = UDim2.new(1, offsetX, 1, -28)
	button.Size = UDim2.new(0, 88, 0, 88)
	button.BackgroundColor3 = UiTheme.colors.grey
	button.Font = UiTheme.font
	button.TextScaled = true
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextStrokeColor3 = UiTheme.outline
	button.TextStrokeTransparency = 0
	button.Text = ""
	button.Visible = false
	button.Parent = gui
	UiTheme.round(button, UDim.new(1, 0))
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Thickness = 4
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = button
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.12, 0)
	pad.PaddingRight = UDim.new(0.12, 0)
	pad.PaddingTop = UDim.new(0.28, 0)
	pad.PaddingBottom = UDim.new(0.28, 0)
	pad.Parent = button
	local shade = Instance.new("Frame") -- the cooldown: a dark cover that shrinks away as the ability recharges
	shade.AnchorPoint = Vector2.new(0, 1)
	shade.Position = UDim2.new(0, 0, 1, 0)
	shade.Size = UDim2.new(1, 0, 0, 0)
	shade.BackgroundColor3 = Color3.fromRGB(40, 30, 70)
	shade.BackgroundTransparency = 0.35
	shade.ZIndex = 2
	shade.Parent = button
	UiTheme.round(shade, UDim.new(1, 0))
	local slot: Slot = { button = button, shade = shade, key = key, ability = nil }
	button.Activated:Connect(function()
		local ability = slot.ability
		if ability and actions[ability.id] then
			actions[ability.id]()
			-- a little bounce on press
			button.Size = UDim2.new(0, 100, 0, 100)
			TweenService:Create(button, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.new(0, 88, 0, 88) }):Play()
		end
	end)
	table.insert(slots, slot)
	return slot
end

local function ring(position: Vector3, radius: number, color: Color3)
	local disc = Instance.new("Part")
	disc.Shape = Enum.PartType.Cylinder
	disc.Size = Vector3.new(0.5, 2, 2)
	disc.CFrame = CFrame.new(position - Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
	disc.Anchored = true
	disc.CanCollide = false
	disc.CanQuery = false
	disc.CanTouch = false
	disc.Material = Enum.Material.Neon
	disc.Color = color
	disc.Transparency = 0.3
	disc.Parent = Workspace
	TweenService:Create(disc, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.5, radius * 2, radius * 2), Transparency = 1 }):Play()
	Debris:AddItem(disc, 0.6)
end

local function burst(position: Vector3, color: Color3, count: number)
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
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new(1.6, 0)
	emitter.Lifetime = NumberRange.new(0.5, 1)
	emitter.Speed = NumberRange.new(10, 24)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 0
	emitter.Parent = anchor
	emitter:Emit(count) -- small bursts only, so phones stay smooth
	Debris:AddItem(anchor, 1.4)
end

function AbilityController.init()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local dashRequest = remotes:WaitForChild("DashRequest") :: RemoteEvent
	local dashGo = remotes:WaitForChild("DashGo") :: RemoteEvent
	local stareRequest = remotes:WaitForChild("StareRequest") :: RemoteEvent
	local abilityRequest = remotes:WaitForChild("AbilityRequest") :: RemoteEvent
	local worldFx = remotes:WaitForChild("WorldFx") :: RemoteEvent

	local gui = Instance.new("ScreenGui")
	gui.Name = "AbilityHud"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	actions.dash = function()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local camera = Workspace.CurrentCamera
		if not humanoid or not camera then
			return
		end
		local move = humanoid.MoveDirection
		local flat = if move.Magnitude > 0.1 then Vector3.new(move.X, 0, move.Z) else Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
		if flat.Magnitude > 0.1 then
			local unit = flat.Unit
			dashRequest:FireServer(unit.X, unit.Z)
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				burst(root.Position, Color3.fromRGB(255, 235, 150), 14) -- the sparkly Glow-Up
			end
		end
	end
	actions.stare = function()
		stareRequest:FireServer()
	end
	for _, id in { "slam", "flip", "shield", "total" } do
		actions[id] = function()
			abilityRequest:FireServer(id)
		end
	end

	-- two slots: the older of the two newest abilities (key Q) and the newest (key R)
	makeSlot(gui, -274, "Q")
	makeSlot(gui, -176, "R")
	local function press(index: number)
		local slot = slots[index]
		local ability = slot and slot.ability
		if ability and actions[ability.id] then
			actions[ability.id]()
		end
	end
	ContextActionService:BindAction("MogWarsAbilityQ", function(_, state)
		if state == Enum.UserInputState.Begin then
			press(1)
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.Q)
	ContextActionService:BindAction("MogWarsAbilityR", function(_, state)
		if state == Enum.UserInputState.Begin then
			press(2)
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.R)

	-- the dash itself: a short burst along the chosen direction, applied to your own character
	dashGo.OnClientEvent:Connect(function(dx: any, dz: any, speed: any, seconds: any)
		if type(dx) ~= "number" or type(dz) ~= "number" or type(speed) ~= "number" or type(seconds) ~= "number" then
			return
		end
		local untilTime = os.clock() + math.clamp(seconds, 0.05, 0.5)
		local connection: RBXScriptConnection? = nil
		connection = RunService.Heartbeat:Connect(function()
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not root or not root:IsA("BasePart") or os.clock() > untilTime then
				if connection then
					connection:Disconnect()
				end
				return
			end
			root.AssemblyLinearVelocity = Vector3.new(dx * speed, root.AssemblyLinearVelocity.Y, dz * speed)
		end)
	end)

	-- effects for everyone: kind, a position and one extra value (the server sends them; they never change anything)
	worldFx.OnClientEvent:Connect(function(kind: any, position: any, extra: any)
		if typeof(position) ~= "Vector3" then
			return
		end
		if kind == "stare" and typeof(extra) == "Vector3" then
			local length = (extra - position).Magnitude
			if length > 1 then
				local beam = Instance.new("Part")
				beam.Anchored = true
				beam.CanCollide = false
				beam.CanQuery = false
				beam.CanTouch = false
				beam.Material = Enum.Material.Neon
				beam.Color = Color3.fromRGB(150, 230, 255)
				beam.Size = Vector3.new(0.5, 0.5, length)
				beam.CFrame = CFrame.lookAt((position + extra) / 2, extra)
				beam.Parent = Workspace
				TweenService:Create(beam, TweenInfo.new(0.35), { Transparency = 1, Size = Vector3.new(0.1, 0.1, length) }):Play()
				Debris:AddItem(beam, 0.5)
			end
		elseif kind == "slam" and type(extra) == "number" then
			ring(position, extra, Color3.fromRGB(255, 150, 70))
			burst(position, Color3.fromRGB(255, 190, 120), 16)
		elseif kind == "gust" and typeof(extra) == "Vector3" then
			for step = 1, 3 do
				burst(position + extra * (6 * step) + Vector3.new(0, 2, 0), Color3.fromRGB(255, 170, 220), 8)
			end
		elseif kind == "shield" then
			burst(position, Color3.fromRGB(255, 220, 100), 14)
		elseif kind == "total" and type(extra) == "number" then
			ring(position, extra, Color3.fromRGB(200, 120, 255))
			burst(position, Color3.new(1, 1, 1), 20)
		elseif kind == "flagburst" then
			burst(position + Vector3.new(0, 4, 0), if typeof(extra) == "Color3" then extra else Color3.new(1, 1, 1), 22)
		end
	end)
end

function AbilityController.start()
	RunService.RenderStepped:Connect(function()
		local rankValue = player:GetAttribute("Rank")
		local rank = if type(rankValue) == "number" then rankValue else 1
		local unlocked: { Ability } = {}
		for _, ability in ABILITIES do
			if rank >= ability.rank then
				table.insert(unlocked, ability)
			end
		end
		-- Shove plus the two newest only
		local newest = unlocked[#unlocked]
		local older = unlocked[#unlocked - 1]
		slots[1].ability = if older then older else newest
		slots[2].ability = if older then newest else nil
		for _, slot in slots do
			local ability = slot.ability
			slot.button.Visible = ability ~= nil
			if ability then
				slot.button.BackgroundColor3 = ability.color
				local readyAt = player:GetAttribute(ability.readyAttr)
				local remaining = if type(readyAt) == "number" then readyAt - Workspace:GetServerTimeNow() else 0
				slot.shade.Size = UDim2.new(1, 0, math.clamp(remaining / ability.cooldown, 0, 1), 0)
				slot.button.Text = if remaining > 0 then ("%.0f"):format(math.ceil(remaining)) else ability.label
			end
		end
	end)
end

return AbilityController
