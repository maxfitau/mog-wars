--!strict
-- Shows the player's Mog Points, top left (the top right belongs to Roblox's player list). Display only: the
-- server owns the number and mirrors it to the player's "Points" attribute; nothing the client does can change it.

local Players = game:GetService("Players")

local UiTheme = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("UiTheme"))

local PointsHud = {}

function PointsHud.init()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "PointsHud"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local label = Instance.new("TextLabel")
	label.Position = UDim2.new(0, 16, 0, 16)
	label.Size = UDim2.new(0, 250, 0, 52)
	label.BackgroundColor3 = UiTheme.panel
	label.TextColor3 = UiTheme.colors.yellow
	label.Font = UiTheme.font
	label.TextScaled = true
	label.Text = "Mog Points: 0"
	label.Parent = gui
	UiTheme.round(label)
	UiTheme.outlineBox(label)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.12, 0)
	padding.PaddingBottom = UDim.new(0.12, 0)
	padding.PaddingLeft = UDim.new(0.06, 0)
	padding.PaddingRight = UDim.new(0.06, 0)
	padding.Parent = label

	local function refresh()
		local points = player:GetAttribute("Points")
		label.Text = ("Mog Points: %d"):format(if type(points) == "number" then points else 0)
	end
	player:GetAttributeChangedSignal("Points"):Connect(refresh)
	refresh()
end

function PointsHud.start() end

return PointsHud
