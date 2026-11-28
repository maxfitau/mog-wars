--!strict
-- SERVER EVENT screen (the Aura Meteor today): a banner with a countdown or the flag's progress, a purple sky tint and an
-- alarm during the warning, and screen shake plus a white flash when the meteor lands. Display only: the server owns the
-- event and publishes Workspace attributes (EventName, EventPhase, EventEndsAt, EventText) and the "EventFx" remote.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Pace = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Pace"))

local EventController = {}

local player = Players.LocalPlayer
local shakeUntil, shakeStrength = 0, 0

function EventController.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "EventHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	gui.Parent = player:WaitForChild("PlayerGui")

	local bannerFrame = Instance.new("Frame")
	bannerFrame.AnchorPoint = Vector2.new(0.5, 0)
	bannerFrame.Position = UDim2.new(0.5, 0, 0, 120)
	bannerFrame.Size = UDim2.fromOffset(420, 44)
	bannerFrame.BackgroundColor3 = Color3.fromRGB(60, 20, 100)
	bannerFrame.BackgroundTransparency = 0.1
	bannerFrame.Visible = false
	bannerFrame.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = bannerFrame
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(215, 140, 255)
	stroke.Thickness = 2
	stroke.Parent = bannerFrame
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Parent = bannerFrame
	local padding = Instance.new("UIPadding")
	padding.PaddingTop, padding.PaddingBottom = UDim.new(0, 6), UDim.new(0, 6)
	padding.Parent = label

	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Parent = gui

	local tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "EventTint"
	tint.Enabled = true
	tint.Parent = Lighting

	local function playSound(id: string)
		if type(id) ~= "string" or id == "" then
			return -- no sound set: stay silent (a nil or empty id would error)
		end
		local sound = Instance.new("Sound")
		sound.SoundId = id
		sound.Parent = gui
		sound:Play()
		game:GetService("Debris"):AddItem(sound, 6)
	end

	RunService.RenderStepped:Connect(function()
		local name = Workspace:GetAttribute("EventName")
		if type(name) == "string" and name ~= "" then
			local endsAt = Workspace:GetAttribute("EventEndsAt")
			local text = Workspace:GetAttribute("EventText")
			local remaining = if type(endsAt) == "number" then math.max(0, math.ceil(endsAt - Workspace:GetServerTimeNow())) else 0
			bannerFrame.Visible = true
			if Workspace:GetAttribute("EventPhase") == "incoming" then
				label.Text = ("AURA METEOR INCOMING - %ds"):format(remaining)
			else
				label.Text = if type(text) == "string" then string.upper(text) else ""
			end
		else
			bannerFrame.Visible = false
		end
		local camera = Workspace.CurrentCamera
		if camera and os.clock() < shakeUntil then
			local strength = shakeStrength * (shakeUntil - os.clock())
			camera.CFrame = camera.CFrame * CFrame.new((math.random() - 0.5) * strength, (math.random() - 0.5) * strength, 0)
		end
	end)

	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("EventFx") :: RemoteEvent
	remote.OnClientEvent:Connect(function(kind: any, position: any)
		if kind == "warn" then
			TweenService:Create(tint, TweenInfo.new(2), { TintColor = Color3.fromRGB(205, 150, 255), Saturation = 0.15 }):Play()
			playSound(Pace.sounds.alarm)
		elseif kind == "boom" then
			local camera = Workspace.CurrentCamera
			local distance = if camera and typeof(position) == "Vector3" then (camera.CFrame.Position - position).Magnitude else 0
			shakeStrength = math.clamp(2.2 - distance / 400, 0.3, 2.2)
			shakeUntil = os.clock() + 1.2
			flash.BackgroundTransparency = 0.15
			TweenService:Create(flash, TweenInfo.new(0.9), { BackgroundTransparency = 1 }):Play()
			playSound(Pace.sounds.boom)
		elseif kind == "claim" then
			playSound(Pace.sounds.gold)
		elseif kind == "clear" then
			TweenService:Create(tint, TweenInfo.new(2), { TintColor = Color3.new(1, 1, 1), Saturation = 0 }):Play()
		end
	end)
end

function EventController.start() end

return EventController
