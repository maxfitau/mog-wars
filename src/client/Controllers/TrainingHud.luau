--!strict
-- Training level panel (top left, under the war panel): level, aura strength, progress to the next level and
-- how much training time is left today. Display only: the server counts strides and mirrors
-- TrainingLevel, TrainingProgress, TrainingLeft and TrainingActive onto the player.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("EconomyConfig"))
local TrainingRules = require(Shared:WaitForChild("TrainingRules"))

local TrainingHud = {}

local player = Players.LocalPlayer
local title: TextLabel
local info: TextLabel
local fill: Frame

local function number(name: string, fallback: number): number
	local value = player:GetAttribute(name)
	return if type(value) == "number" then value else fallback
end

local function update()
	local level = number("TrainingLevel", 0)
	local aura = TrainingRules.auraMultiplier(level, Config.training)
	if level >= Config.training.maxLevel then
		title.Text = ("Aura level MAX  (x%.2f)"):format(aura)
	else
		title.Text = ("Aura level %d/%d  (x%.2f)"):format(level, Config.training.maxLevel, aura)
	end
	fill.Size = UDim2.new(math.clamp(number("TrainingProgress", 0), 0, 1), 0, 1, 0)
	local left = number("TrainingLeft", Config.training.dailyStrideCap)
	if level >= Config.training.maxLevel then
		info.Text = "Fully trained!"
	elseif player:GetAttribute("TrainingActive") == true then
		info.Text = ("Training! %d:%02d left today"):format(left // 60, left % 60)
	elseif left <= 0 then
		info.Text = "Done for today. Come back tomorrow!"
	else
		info.Text = ("Walk on a treadmill by your base. %d:%02d left today"):format(left // 60, left % 60)
	end
end

function TrainingHud.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "TrainingHud"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(1, 0)
	frame.Position = UDim2.new(1, -16, 0, 62) -- right side, under Mog Points
	frame.Size = UDim2.new(0, 230, 0, 70)
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	frame.BackgroundTransparency = 0.25
	frame.Parent = gui
	local corner = Instance.new("UICorner")
	corner.Parent = frame

	title = Instance.new("TextLabel")
	title.Text = "" -- never show Roblox's default placeholder text
	title.BackgroundTransparency = 1
	title.Position = UDim2.new(0, 8, 0, 4)
	title.Size = UDim2.new(1, -16, 0, 22)
	title.TextColor3 = Color3.fromRGB(255, 220, 90)
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.Parent = frame

	local track = Instance.new("Frame")
	track.Position = UDim2.new(0, 8, 0, 30)
	track.Size = UDim2.new(1, -16, 0, 10)
	track.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
	track.Parent = frame
	fill = Instance.new("Frame")
	fill.BackgroundColor3 = Color3.fromRGB(110, 200, 255)
	fill.BorderSizePixel = 0
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.Parent = track

	info = Instance.new("TextLabel")
	info.Text = "" -- never show Roblox's default placeholder text
	info.BackgroundTransparency = 1
	info.Position = UDim2.new(0, 8, 0, 44)
	info.Size = UDim2.new(1, -16, 0, 20)
	info.TextColor3 = Color3.fromRGB(220, 220, 230)
	info.Font = Enum.Font.Gotham
	info.TextScaled = true
	info.Parent = frame
end

function TrainingHud.start()
	RunService.RenderStepped:Connect(update)
end

return TrainingHud
