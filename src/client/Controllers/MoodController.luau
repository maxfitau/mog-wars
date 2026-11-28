--!strict
-- MOOD LIGHTING. Each place has its own mood, blended over two seconds as you cross into it: a green glow in Brainrot Bog, orange
-- lava light in Cooked Canyon, pink sparkle at Rizz Ravine, cool sea light at the Lighthouse, dim torchlight in Chud Chambers. It
-- only changes YOUR lighting (ambient, a colour tint, brightness and haze colour). On phones the sun rays are switched off and
-- bloom is lighter, so it stays smooth. Display only.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Territories = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Territories"))

local MoodController = {}

local player = Players.LocalPlayer

type Mood = { ambient: Color3?, outdoor: Color3?, tint: Color3?, brightness: number?, haze: Color3?, saturation: number? }

local MOODS: { [string]: Mood } = {
	brainrot_bog = { ambient = Color3.fromRGB(100, 150, 110), outdoor = Color3.fromRGB(110, 170, 120), tint = Color3.fromRGB(215, 255, 210), haze = Color3.fromRGB(190, 255, 170), saturation = 0.25 },
	cooked_canyon = { ambient = Color3.fromRGB(170, 105, 80), outdoor = Color3.fromRGB(200, 130, 90), tint = Color3.fromRGB(255, 218, 175), haze = Color3.fromRGB(255, 170, 110), saturation = 0.3 },
	rizz_ravine = { ambient = Color3.fromRGB(170, 125, 165), outdoor = Color3.fromRGB(190, 140, 180), tint = Color3.fromRGB(255, 220, 240), haze = Color3.fromRGB(255, 190, 225), saturation = 0.3 },
	locked_in_lighthouse = { ambient = Color3.fromRGB(125, 140, 175), outdoor = Color3.fromRGB(135, 155, 195), tint = Color3.fromRGB(235, 245, 255), haze = Color3.fromRGB(200, 225, 255) },
	chud_chambers = { ambient = Color3.fromRGB(58, 52, 70), outdoor = Color3.fromRGB(62, 56, 74), tint = Color3.fromRGB(255, 225, 195), brightness = 1.2, haze = Color3.fromRGB(120, 90, 80), saturation = 0.15 },
}

local function whereIs(position: Vector3): string?
	for _, territory in Territories.list do
		if territory.radius == 0 and math.abs(position.X - territory.x) < 90 and position.Z - territory.z > -60 and position.Z - territory.z < 52 and position.Y > territory.height - 4 and position.Y < territory.height + 34 then
			return territory.id
		end
	end
	for _, territory in Territories.list do
		if territory.radius > 0 then
			local dx, dz = position.X - territory.x, position.Z - territory.z
			if math.sqrt(dx * dx + dz * dz) < territory.radius + 6 and position.Y > territory.height - 6 and position.Y < territory.height + 60 then
				return territory.id
			end
		end
	end
	return nil
end

function MoodController.init()
	local touch = UserInputService.TouchEnabled
	if touch then -- phones: no sun rays, lighter bloom
		for _, child in Lighting:GetChildren() do
			if child:IsA("SunRaysEffect") then
				child.Enabled = false
			elseif child:IsA("BloomEffect") then
				child.Size = 16
				child.Intensity = 0.4
			end
		end
	end
	local base = { ambient = Lighting.Ambient, outdoor = Lighting.OutdoorAmbient, brightness = Lighting.Brightness }
	local tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "MoodTint"
	tint.Parent = Lighting
	local atmosphere = Lighting:WaitForChild("Atmosphere", 5) :: Atmosphere?
	local baseHaze = if atmosphere then atmosphere.Color else Color3.new(1, 1, 1)
	local current: string? = "?"
	local since = 0
	RunService.Heartbeat:Connect(function(dt)
		since += dt
		if since < 0.4 then
			return
		end
		since = 0
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			return
		end
		local id = whereIs(root.Position)
		if id == current then
			return
		end
		current = id
		local mood: Mood = (if id then MOODS[id] else nil) or {}
		local info = TweenInfo.new(2, Enum.EasingStyle.Sine)
		TweenService:Create(Lighting, info, { Ambient = mood.ambient or base.ambient, OutdoorAmbient = mood.outdoor or base.outdoor, Brightness = mood.brightness or base.brightness }):Play()
		TweenService:Create(tint, info, { TintColor = mood.tint or Color3.new(1, 1, 1), Saturation = mood.saturation or 0 }):Play()
		if atmosphere then
			TweenService:Create(atmosphere, info, { Color = mood.haze or baseHaze }):Play()
		end
	end)
end

function MoodController.start() end

return MoodController
