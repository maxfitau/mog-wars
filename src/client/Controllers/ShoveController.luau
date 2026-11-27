--!strict
-- Press E (or the on-screen button on touch devices) to shove. The client only sends a bare request; the
-- server decides everything. The cooldown label is display only (it reads the server's ShoveReadyAt).
-- Knockback arrives from the server and is applied to this player's own character.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ShoveController = {}

local label: TextLabel
local request: RemoteEvent

local KNOCKBACK_SPEED_PER_STUD = 3.5 -- tune in playtest
local KNOCKBACK_LIFT = 25

local function refresh()
	local readyAt = Players.LocalPlayer:GetAttribute("ShoveReadyAt")
	local remaining = if type(readyAt) == "number" then readyAt - Workspace:GetServerTimeNow() else 0
	label.Text = if remaining > 0 then ("Shove %.1fs"):format(remaining) else "Shove ready (E)"
	label.TextColor3 = if remaining > 0 then Color3.fromRGB(200, 120, 120) else Color3.fromRGB(120, 220, 140)
end

function ShoveController.init()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	request = remotes:WaitForChild("ShoveRequest") :: RemoteEvent
	local knockback = remotes:WaitForChild("ShoveKnockback") :: RemoteEvent

	local gui = Instance.new("ScreenGui")
	gui.Name = "ShoveHud"
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 1, -24)
	label.Size = UDim2.new(0, 190, 0, 34)
	label.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	label.BackgroundTransparency = 0.25
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Parent = gui
	local corner = Instance.new("UICorner")
	corner.Parent = label

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
end

function ShoveController.start()
	ContextActionService:BindAction("Shove", function(_name, state)
		if state == Enum.UserInputState.Begin then
			request:FireServer()
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.E)
	ContextActionService:SetTitle("Shove", "Shove")
	RunService.RenderStepped:Connect(refresh)
end

return ShoveController
