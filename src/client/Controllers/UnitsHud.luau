--!strict
-- The units screen: how many tanks and horses you own, what each does, and Deploy and Sell buttons.
-- Display only. The server owns counts (mirrored as Units_<id> attributes), checks every request, and
-- answers with a message.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("EconomyConfig"))

local UnitsHud = {}

local player = Players.LocalPlayer
local panel: Frame
local toast: TextLabel
local toastUntil = 0
local counts: { [string]: TextLabel } = {}

local MESSAGES: { [string]: string } = {
	not_war = "Units can only be used during a war.",
	not_alive = "You need to be alive.",
	no_unit = "You do not have one.",
	not_in_zone = "Stand inside a zone to deploy a tank.",
	tank_exists = "Your faction already has a tank here.",
	already_riding = "You are already riding a horse.",
	unknown_unit = "Unknown unit.",
	bad_input = "Something went wrong. Try again.",
	not_loaded = "Still loading your data.",
}

local function number(name: string): number
	local value = player:GetAttribute(name)
	return if type(value) == "number" then value else 0
end

local function update()
	for unitId, label in counts do
		label.Text = ("x%d"):format(number("Units_" .. unitId))
	end
	toast.Visible = Workspace:GetServerTimeNow() < toastUntil
end

function UnitsHud.init()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local deployRemote = remotes:WaitForChild("DeployUnitRequest") :: RemoteEvent
	local sellRemote = remotes:WaitForChild("SellUnitRequest") :: RemoteEvent
	local resultRemote = remotes:WaitForChild("UnitResult") :: RemoteEvent

	local gui = Instance.new("ScreenGui")
	gui.Name = "UnitsHud"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local toggle = Instance.new("TextButton")
	toggle.AnchorPoint = Vector2.new(0, 0.5)
	toggle.Position = UDim2.new(0, 16, 0.5, 52)
	toggle.Size = UDim2.new(0, 90, 0, 40)
	toggle.BackgroundColor3 = Color3.fromRGB(60, 90, 200)
	toggle.TextColor3 = Color3.new(1, 1, 1)
	toggle.Font = Enum.Font.GothamBold
	toggle.TextScaled = true
	toggle.Text = "Units"
	toggle.Parent = gui
	local toggleCorner = Instance.new("UICorner")
	toggleCorner.Parent = toggle

	panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.new(0.5, 0, 0.5, 0)
	panel.Size = UDim2.new(0, 360, 0, 270)
	panel.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	panel.BackgroundTransparency = 0.05
	panel.Visible = false
	panel.Parent = gui
	local panelCorner = Instance.new("UICorner")
	panelCorner.Parent = panel
	toggle.Activated:Connect(function()
		panel.Visible = not panel.Visible
	end)

	local descriptions: { [string]: string } = {
		tank = ("Tank: your faction captures %d%% faster in the zone you deploy it in. One war."):format(
			math.floor((Config.units.tank.captureMultiplier - 1) * 100 + 0.5)
		),
		horse = ("Horse: you move %d%% faster. One war."):format(
			math.floor((Config.units.horse.speedMultiplier - 1) * 100 + 0.5)
		),
	}
	local sellValues: { [string]: number } = { tank = Config.units.tank.sellValue, horse = Config.units.horse.sellValue }

	for index, unitId in { "tank", "horse" } do
		local top = 10 + (index - 1) * 125
		local name = Instance.new("TextLabel")
		name.BackgroundTransparency = 1
		name.Position = UDim2.new(0, 10, 0, top)
		name.Size = UDim2.new(0.6, 0, 0, 26)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextColor3 = Color3.fromRGB(255, 220, 90)
		name.Font = Enum.Font.GothamBold
		name.TextScaled = true
		name.Text = unitId:sub(1, 1):upper() .. unitId:sub(2)
		name.Parent = panel

		local count = Instance.new("TextLabel")
		count.BackgroundTransparency = 1
		count.Position = UDim2.new(0.65, 0, 0, top)
		count.Size = UDim2.new(0.3, 0, 0, 26)
		count.TextColor3 = Color3.new(1, 1, 1)
		count.Font = Enum.Font.GothamBold
		count.TextScaled = true
		count.Parent = panel
		counts[unitId] = count

		local about = Instance.new("TextLabel")
		about.BackgroundTransparency = 1
		about.Position = UDim2.new(0, 10, 0, top + 30)
		about.Size = UDim2.new(1, -20, 0, 36)
		about.TextXAlignment = Enum.TextXAlignment.Left
		about.TextYAlignment = Enum.TextYAlignment.Top
		about.TextWrapped = true
		about.TextColor3 = Color3.fromRGB(210, 210, 225)
		about.Font = Enum.Font.Gotham
		about.TextSize = 14
		about.Text = descriptions[unitId]
		about.Parent = panel

		local deployButton = Instance.new("TextButton")
		deployButton.Position = UDim2.new(0, 10, 0, top + 72)
		deployButton.Size = UDim2.new(0.45, -10, 0, 34)
		deployButton.BackgroundColor3 = Color3.fromRGB(70, 180, 100)
		deployButton.TextColor3 = Color3.new(1, 1, 1)
		deployButton.Font = Enum.Font.GothamBold
		deployButton.TextScaled = true
		deployButton.Text = "Deploy"
		deployButton.Parent = panel
		deployButton.Activated:Connect(function()
			deployRemote:FireServer(unitId)
		end)

		local sellButton = Instance.new("TextButton")
		sellButton.Position = UDim2.new(0.5, 0, 0, top + 72)
		sellButton.Size = UDim2.new(0.5, -10, 0, 34)
		sellButton.BackgroundColor3 = Color3.fromRGB(190, 130, 50)
		sellButton.TextColor3 = Color3.new(1, 1, 1)
		sellButton.Font = Enum.Font.GothamBold
		sellButton.TextScaled = true
		sellButton.Text = ("Sell (%d)"):format(sellValues[unitId])
		sellButton.Parent = panel
		sellButton.Activated:Connect(function()
			sellRemote:FireServer(unitId)
		end)
	end

	toast = Instance.new("TextLabel")
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0.1, 0)
	toast.Size = UDim2.new(0, 340, 0, 50)
	toast.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	toast.BackgroundTransparency = 0.1
	toast.TextColor3 = Color3.new(1, 1, 1)
	toast.Font = Enum.Font.GothamBold
	toast.TextScaled = true
	toast.Visible = false
	toast.ZIndex = 5
	toast.Parent = gui
	local toastCorner = Instance.new("UICorner")
	toastCorner.Parent = toast

	resultRemote.OnClientEvent:Connect(function(ok: any, reason: any, action: any, unit: any, amount: any)
		if ok == true then
			if action == "sell" then
				toast.Text = ("Sold for %d Mog Points!"):format(if type(amount) == "number" then amount else 0)
			else
				toast.Text = ("%s deployed for this war!"):format(tostring(unit))
			end
		else
			toast.Text = MESSAGES[tostring(reason)] or "That did not work."
		end
		toastUntil = Workspace:GetServerTimeNow() + 3
	end)
end

function UnitsHud.start()
	RunService.RenderStepped:Connect(update)
end

return UnitsHud
