--!strict
-- Zipline visuals. The SERVER carries you along the cable; this only adds the feel: speed lines racing past, a wider
-- field of view, and "jump to let go". Display only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local ZiplineController = {}

local player = Players.LocalPlayer
local gui: ScreenGui
local lines: { Frame } = {}
local riding = false
local letGo: RemoteEvent

local function setRiding(on: boolean)
	riding = on
	local camera = Workspace.CurrentCamera
	if camera then
		TweenService:Create(camera, TweenInfo.new(0.35), { FieldOfView = if on then 88 else 70 }):Play()
	end
	for _, line in lines do
		line.Visible = on
	end
end

function ZiplineController.init()
	gui = Instance.new("ScreenGui")
	gui.Name = "ZiplineFx"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")
	for index = 1, 14 do
		local line = Instance.new("Frame") -- a thin white speed line, drawn near the edges so it never covers the middle
		line.BackgroundColor3 = Color3.new(1, 1, 1)
		line.BackgroundTransparency = 0.5
		line.BorderSizePixel = 0
		line.Size = UDim2.new(0, 3, 0, 60 + (index * 13) % 50)
		line.Visible = false
		line.Parent = gui
		table.insert(lines, line)
	end
end

function ZiplineController.start()
	letGo = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ZiplineLetGo") :: RemoteEvent
	player:GetAttributeChangedSignal("Ziplining"):Connect(function()
		setRiding(player:GetAttribute("Ziplining") == true)
	end)
	UserInputService.JumpRequest:Connect(function()
		if riding then
			letGo:FireServer() -- jump to let go
		end
	end)
	local clock = 0
	RunService.RenderStepped:Connect(function(dt)
		if not riding then
			return
		end
		clock += dt
		for index, line in lines do
			local side = if index % 2 == 0 then 0.06 + (index % 5) * 0.03 else 0.94 - (index % 5) * 0.03
			local y = ((clock * (1.8 + (index % 4) * 0.4)) + index * 0.17) % 1.2 - 0.1
			line.Position = UDim2.new(side, 0, y, 0)
		end
	end)
end

return ZiplineController
