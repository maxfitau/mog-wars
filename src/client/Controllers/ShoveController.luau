--!strict
-- THE shove: one big button bottom right (touch), or press E or click (PC). The client only sends a bare request; the
-- server decides everything (who, how far, the 1.5 second cooldown). The cooldown shading is display only (it reads
-- the server's ShoveReadyAt). Knockback and launch pads arrive from the server and are applied to this player's own
-- character.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local UiTheme = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("UiTheme"))

local ShoveController = {}

local button: TextButton
local shade: Frame
local request: RemoteEvent

local KNOCKBACK_SPEED_PER_STUD = 3.5 -- tune in playtest
local KNOCKBACK_LIFT = 25

local function refresh()
	local readyAt = Players.LocalPlayer:GetAttribute("ShoveReadyAt")
	local remaining = if type(readyAt) == "number" then readyAt - Workspace:GetServerTimeNow() else 0
	if remaining > 0 then
		button.Text = ("%.1f"):format(remaining)
		shade.Visible = true
	else
		button.Text = "SHOVE!"
		shade.Visible = false
	end
end

local function shove()
	request:FireServer() -- no data: the server decides
end

function ShoveController.init()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	request = remotes:WaitForChild("ShoveRequest") :: RemoteEvent
	local knockback = remotes:WaitForChild("ShoveKnockback") :: RemoteEvent

	local gui = Instance.new("ScreenGui")
	gui.Name = "ShoveHud"
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	-- the one big round button, bottom right
	button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(1, 1)
	button.Position = UDim2.new(1, -24, 1, -28)
	button.Size = UDim2.new(0, 132, 0, 132)
	button.BackgroundColor3 = UiTheme.colors.orange
	button.Font = UiTheme.font
	button.TextScaled = true
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextStrokeColor3 = UiTheme.outline
	button.TextStrokeTransparency = 0
	button.Text = "SHOVE!"
	button.Parent = gui
	UiTheme.round(button, UDim.new(1, 0))
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Thickness = 5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border -- the ring round the button (the default would outline the LETTERS, which made the label a white blob)
	stroke.Parent = button
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.12, 0)
	pad.PaddingRight = UDim.new(0.12, 0)
	pad.PaddingTop = UDim.new(0.28, 0)
	pad.PaddingBottom = UDim.new(0.28, 0)
	pad.Parent = button
	shade = Instance.new("Frame") -- greys the button out while it recharges
	shade.Size = UDim2.new(1, 0, 1, 0)
	shade.BackgroundColor3 = Color3.fromRGB(40, 30, 70)
	shade.BackgroundTransparency = 0.45
	shade.Visible = false
	shade.ZIndex = 2
	shade.Parent = button
	UiTheme.round(shade, UDim.new(1, 0))
	button.Activated:Connect(shove)

	-- E or a click anywhere also shoves (PC)
	ContextActionService:BindAction("MogWarsShove", function(_, state)
		if state == Enum.UserInputState.Begin then
			shove()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.E)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.UserInputType == Enum.UserInputType.MouseButton1 then
			shove()
		end
	end)

	knockback.OnClientEvent:Connect(function(dx: any, dz: any, studs: any)
		if type(dx) ~= "number" or type(dz) ~= "number" or type(studs) ~= "number" then
			return
		end
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and math.abs(dx) <= 1.01 and math.abs(dz) <= 1.01 then
			local speed = math.clamp(studs, 0, 30) * KNOCKBACK_SPEED_PER_STUD
			root.AssemblyLinearVelocity = Vector3.new(dx * speed, KNOCKBACK_LIFT, dz * speed)
		end
	end)

	-- jump pads and launch pads throw you (the server sends the throw)
	local launch = remotes:WaitForChild("WorldLaunch") :: RemoteEvent
	launch.OnClientEvent:Connect(function(velocity: any)
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and typeof(velocity) == "Vector3" and velocity.Magnitude < 400 then
			root.AssemblyLinearVelocity = velocity
		end
	end)
end

function ShoveController.start()
	RunService.RenderStepped:Connect(refresh)
end

return ShoveController
