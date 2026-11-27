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

type AbilityButton = { button: TextButton, shade: Frame, rank: number, readyAttr: string, cooldown: number, label: string, key: string }
local buttons: { AbilityButton } = {}

local function makeButton(gui: ScreenGui, label: string, key: string, color: Color3, offsetX: number, rank: number, readyAttr: string, cooldown: number, action: () -> ()): AbilityButton
	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(1, 1)
	button.Position = UDim2.new(1, offsetX, 1, -28)
	button.Size = UDim2.new(0, 88, 0, 88)
	button.BackgroundColor3 = color
	button.Font = UiTheme.font
	button.TextScaled = true
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextStrokeColor3 = UiTheme.outline
	button.TextStrokeTransparency = 0
	button.Text = label
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
	local shade = Instance.new("Frame")
	shade.Size = UDim2.new(1, 0, 1, 0)
	shade.BackgroundColor3 = Color3.fromRGB(40, 30, 70)
	shade.BackgroundTransparency = 0.45
	shade.Visible = false
	shade.ZIndex = 2
	shade.Parent = button
	UiTheme.round(shade, UDim.new(1, 0))
	button.Activated:Connect(action)
	local entry: AbilityButton = { button = button, shade = shade, rank = rank, readyAttr = readyAttr, cooldown = cooldown, label = label, key = key }
	table.insert(buttons, entry)
	return entry
end

function AbilityController.init()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local dashRequest = remotes:WaitForChild("DashRequest") :: RemoteEvent
	local dashGo = remotes:WaitForChild("DashGo") :: RemoteEvent
	local stareRequest = remotes:WaitForChild("StareRequest") :: RemoteEvent
	local stareFx = remotes:WaitForChild("StareFx") :: RemoteEvent

	local gui = Instance.new("ScreenGui")
	gui.Name = "AbilityHud"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local function dash()
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
		end
	end
	local function stare()
		stareRequest:FireServer()
	end
	makeButton(gui, "DASH", "Q", UiTheme.colors.green, -176, Pace.abilities.dash.rank, "DashReadyAt", Pace.speed.dash.cooldownSeconds, dash)
	makeButton(gui, "STARE", "F", UiTheme.colors.blue, -274, Pace.abilities.stare.rank, "StareReadyAt", Pace.abilities.stare.cooldownSeconds, stare)
	ContextActionService:BindAction("MogWarsDash", function(_, state)
		if state == Enum.UserInputState.Begin then
			dash()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.Q)
	ContextActionService:BindAction("MogWarsStare", function(_, state)
		if state == Enum.UserInputState.Begin then
			stare()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.F)

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

	-- the Mog Stare beam: a quick glowing line from the starer to the frozen enemy
	stareFx.OnClientEvent:Connect(function(from: any, to: any)
		if typeof(from) ~= "Vector3" or typeof(to) ~= "Vector3" then
			return
		end
		local length = (to - from).Magnitude
		if length < 1 then
			return
		end
		local beam = Instance.new("Part")
		beam.Anchored = true
		beam.CanCollide = false
		beam.CanQuery = false
		beam.CanTouch = false
		beam.Material = Enum.Material.Neon
		beam.Color = Color3.fromRGB(150, 230, 255)
		beam.Size = Vector3.new(0.5, 0.5, length)
		beam.CFrame = CFrame.lookAt((from + to) / 2, to)
		beam.Parent = Workspace
		TweenService:Create(beam, TweenInfo.new(0.35), { Transparency = 1, Size = Vector3.new(0.1, 0.1, length) }):Play()
		Debris:AddItem(beam, 0.5)
	end)
end

function AbilityController.start()
	RunService.RenderStepped:Connect(function()
		local rankValue = player:GetAttribute("Rank")
		local rank = if type(rankValue) == "number" then rankValue else 1
		for _, entry in buttons do
			entry.button.Visible = rank >= entry.rank
			local readyAt = player:GetAttribute(entry.readyAttr)
			local remaining = if type(readyAt) == "number" then readyAt - Workspace:GetServerTimeNow() else 0
			entry.shade.Visible = remaining > 0
			entry.button.Text = if remaining > 0 then ("%.0f"):format(math.ceil(remaining)) else entry.label
		end
	end)
end

return AbilityController
