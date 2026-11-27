--!strict
-- Shows the player's Mog Points. Display only: the server owns the number and mirrors it to the player's
-- "Points" attribute; nothing the client does can change it.

local Players = game:GetService("Players")

local PointsHud = {}

function PointsHud.init()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "PointsHud"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(1, 0)
	label.Position = UDim2.new(1, -16, 0, 16)
	label.Size = UDim2.new(0, 170, 0, 36)
	label.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	label.BackgroundTransparency = 0.25
	label.TextColor3 = Color3.fromRGB(255, 220, 90)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Parent = gui
	local corner = Instance.new("UICorner")
	corner.Parent = label

	local function refresh()
		local points = player:GetAttribute("Points")
		label.Text = ("Mog Points: %d"):format(if type(points) == "number" then points else 0)
	end
	player:GetAttributeChangedSignal("Points"):Connect(refresh)
	refresh()
end

function PointsHud.start() end

return PointsHud
