--!strict
-- Shows the player's Mog Points, top left (the top right belongs to Roblox's player list), with a gold coin icon
-- and a little bounce whenever the number goes up. Display only: the server owns the number and mirrors it to
-- the player's "Points" attribute; nothing the client does can change it.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local UiTheme = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("UiTheme"))

local PointsHud = {}

local function stroke(parent: Instance, color: Color3, thickness: number)
	local line = Instance.new("UIStroke")
	line.Color = color
	line.Thickness = thickness
	line.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	line.Parent = parent
end

function PointsHud.init()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "PointsHud"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.Position = UDim2.new(0, 16, 0, 16)
	panel.Size = UDim2.new(0, 250, 0, 52)
	panel.BackgroundColor3 = UiTheme.panel
	panel.Parent = gui
	UiTheme.round(panel, UDim.new(0, 26))
	stroke(panel, Color3.new(1, 1, 1), 3) -- white outline
	local scale = Instance.new("UIScale")
	scale.Parent = panel

	local coin = Instance.new("TextLabel")
	coin.Size = UDim2.new(0, 40, 0, 40)
	coin.Position = UDim2.new(0, 6, 0.5, -20)
	coin.BackgroundColor3 = UiTheme.colors.yellow
	coin.Font = UiTheme.font
	coin.TextScaled = true
	coin.Text = "M"
	coin.TextColor3 = Color3.fromRGB(150, 90, 0)
	coin.Parent = panel
	UiTheme.round(coin, UDim.new(1, 0))
	stroke(coin, Color3.fromRGB(190, 120, 10), 3)

	local label = Instance.new("TextLabel")
	label.Position = UDim2.new(0, 54, 0, 4)
	label.Size = UDim2.new(1, -62, 1, -8)
	label.BackgroundTransparency = 1
	label.TextColor3 = UiTheme.colors.yellow
	label.TextStrokeColor3 = UiTheme.outline
	label.TextStrokeTransparency = 0
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Font = UiTheme.font
	label.TextScaled = true
	label.Text = "0"
	label.Parent = panel

	local last = -1
	local function refresh()
		local points = player:GetAttribute("Points")
		local value = if type(points) == "number" then points else 0
		label.Text = tostring(value):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
		if last >= 0 and value > last then
			scale.Scale = 1.18 -- bounce
			TweenService:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
		last = value
	end
	player:GetAttributeChangedSignal("Points"):Connect(refresh)
	refresh()
end

function PointsHud.start() end

return PointsHud
