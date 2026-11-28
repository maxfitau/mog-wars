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

local HudSlots = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("HudSlots"))
local SoundController = require(script.Parent:WaitForChild("SoundController"))

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

	RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		if camera and os.clock() < shakeUntil then
			local strength = shakeStrength * (shakeUntil - os.clock())
			camera.CFrame = camera.CFrame * CFrame.new((math.random() - 0.5) * strength, (math.random() - 0.5) * strength, 0)
		end
	end)

	-- event banners use the shared line slot: they REPLACE the mission text for 3 seconds, then the mission returns
	Workspace:GetAttributeChangedSignal("EventPhase"):Connect(function()
		local phase = Workspace:GetAttribute("EventPhase")
		if phase == "incoming" then
			HudSlots.line("AURA METEOR INCOMING - 15s", Color3.fromRGB(215, 140, 255), 3)
		elseif phase == "active" then
			HudSlots.line("METEOR FLAG x5 - HOLD IT 20s!", Color3.fromRGB(240, 190, 255), 3)
		end
	end)

	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("EventFx") :: RemoteEvent
	remote.OnClientEvent:Connect(function(kind: any, position: any)
		if kind == "warn" then
			TweenService:Create(tint, TweenInfo.new(2), { TintColor = Color3.fromRGB(205, 150, 255), Saturation = 0.15 }):Play()
			SoundController.play("meteor_alarm")
		elseif kind == "boom" then
			local camera = Workspace.CurrentCamera
			local distance = if camera and typeof(position) == "Vector3" then (camera.CFrame.Position - position).Magnitude else 0
			shakeStrength = math.clamp(2.2 - distance / 400, 0.3, 2.2)
			shakeUntil = os.clock() + 1.2
			flash.BackgroundTransparency = 0.15
			TweenService:Create(flash, TweenInfo.new(0.9), { BackgroundTransparency = 1 }):Play()
			SoundController.play("meteor_boom")
		elseif kind == "claim" then
			SoundController.play("meteor_claim")
		elseif kind == "clear" then
			TweenService:Create(tint, TweenInfo.new(2), { TintColor = Color3.new(1, 1, 1), Saturation = 0 }):Play()
		end
	end)
end

function EventController.start() end

return EventController
