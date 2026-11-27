--!strict
-- The boxes screen: how many of each box you have, the exact odds for each tier BEFORE you open, and an
-- Open button. Odds come from the same shared table the server rolls with. Display only: the server owns
-- the counts (mirrored as Boxes_<tier> attributes) and does every roll.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BoxRoll = require(Shared:WaitForChild("BoxRoll"))
local Config = require(Shared:WaitForChild("EconomyConfig"))

local BoxHud = {}

local player = Players.LocalPlayer
local panel: Frame
local toast: TextLabel
local toastUntil = 0
local counters: { [string]: { count: TextLabel, button: TextButton } } = {}
local order = { "gold", "diamond", "ultra" }

local MESSAGES: { [string]: string } = {
	no_box = "You have no box of that tier.",
	not_loaded = "Still loading your data.",
	unknown_tier = "Unknown box.",
	bad_input = "Something went wrong. Try again.",
}

local function describe(drop: BoxRoll.Drop): string
	if drop.kind == "points" then
		return ("%d Mog Points"):format(drop.amount or 0)
	elseif drop.kind == "unit" then
		return ("%s unit"):format((drop.unit or "?"):sub(1, 1):upper() .. (drop.unit or "?"):sub(2))
	end
	return "Cosmetic: " .. (drop.cosmetic or "?")
end

local function oddsText(tier: BoxRoll.Tier): string
	local lines = {}
	for _, entry in BoxRoll.odds(tier) do
		table.insert(lines, ("%g%%  %s"):format(entry.percent, describe(entry.drop)))
	end
	return table.concat(lines, "\n")
end

local function update()
	for tierId, row in counters do
		local count = player:GetAttribute("Boxes_" .. tierId)
		local owned = if type(count) == "number" then count else 0
		row.count.Text = ("x%d"):format(owned)
		row.button.BackgroundColor3 = if owned > 0 then Color3.fromRGB(70, 180, 100) else Color3.fromRGB(90, 90, 100)
	end
	toast.Visible = Workspace:GetServerTimeNow() < toastUntil
end

function BoxHud.init()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local request = remotes:WaitForChild("OpenBoxRequest") :: RemoteEvent
	local result = remotes:WaitForChild("OpenBoxResult") :: RemoteEvent

	local gui = Instance.new("ScreenGui")
	gui.Name = "BoxHud"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local toggle = Instance.new("TextButton")
	toggle.AnchorPoint = Vector2.new(0, 0.5)
	toggle.Position = UDim2.new(0, 16, 0.5, 0)
	toggle.Size = UDim2.new(0, 90, 0, 40)
	toggle.BackgroundColor3 = Color3.fromRGB(60, 90, 200)
	toggle.TextColor3 = Color3.new(1, 1, 1)
	toggle.Font = Enum.Font.GothamBold
	toggle.TextScaled = true
	toggle.Text = "Boxes"
	toggle.Parent = gui
	local toggleCorner = Instance.new("UICorner")
	toggleCorner.Parent = toggle

	panel = Instance.new("ScrollingFrame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.new(0.5, 0, 0.5, 0)
	panel.Size = UDim2.new(0.8, 0, 0.8, 0)
	panel.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	panel.BackgroundTransparency = 0.05
	panel.Visible = false
	panel.CanvasSize = UDim2.new(0, 0, 0, 0)
	panel.AutomaticCanvasSize = Enum.AutomaticSize.Y
	panel.ScrollBarThickness = 8
	panel.Parent = gui
	local panelCorner = Instance.new("UICorner")
	panelCorner.Parent = panel
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(520, 560)
	sizeLimit.MinSize = Vector2.new(260, 240)
	sizeLimit.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = panel
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.Parent = panel

	toggle.Activated:Connect(function()
		panel.Visible = not panel.Visible
	end)

	for index, tierId in order do
		local tier = Config.boxes.tiers[tierId]
		if tier then
			local row = Instance.new("Frame")
			row.LayoutOrder = index
			row.Size = UDim2.new(1, 0, 0, 170)
			row.BackgroundColor3 = Color3.fromRGB(34, 36, 48)
			row.Parent = panel
			local rowCorner = Instance.new("UICorner")
			rowCorner.Parent = row

			local name = Instance.new("TextLabel")
			name.BackgroundTransparency = 1
			name.Position = UDim2.new(0, 8, 0, 6)
			name.Size = UDim2.new(0.5, -8, 0, 26)
			name.TextXAlignment = Enum.TextXAlignment.Left
			name.TextColor3 = Color3.fromRGB(255, 220, 90)
			name.Font = Enum.Font.GothamBold
			name.TextScaled = true
			name.Text = tier.displayName
			name.Parent = row

			local count = Instance.new("TextLabel")
			count.BackgroundTransparency = 1
			count.Position = UDim2.new(0.5, 0, 0, 6)
			count.Size = UDim2.new(0.2, 0, 0, 26)
			count.TextColor3 = Color3.new(1, 1, 1)
			count.Font = Enum.Font.GothamBold
			count.TextScaled = true
			count.Parent = row

			local button = Instance.new("TextButton")
			button.Position = UDim2.new(0.72, 0, 0, 6)
			button.Size = UDim2.new(0.26, 0, 0, 30)
			button.TextColor3 = Color3.new(1, 1, 1)
			button.Font = Enum.Font.GothamBold
			button.TextScaled = true
			button.Text = "Open"
			button.Parent = row
			local buttonCorner = Instance.new("UICorner")
			buttonCorner.Parent = button
			button.Activated:Connect(function()
				request:FireServer(tierId)
			end)

			local odds = Instance.new("TextLabel")
			odds.BackgroundTransparency = 1
			odds.Position = UDim2.new(0, 8, 0, 40)
			odds.Size = UDim2.new(1, -16, 1, -46)
			odds.TextXAlignment = Enum.TextXAlignment.Left
			odds.TextYAlignment = Enum.TextYAlignment.Top
			odds.TextColor3 = Color3.fromRGB(210, 210, 225)
			odds.Font = Enum.Font.Gotham
			odds.TextSize = 14
			odds.Text = "Odds (each box):\n" .. oddsText(tier)
			odds.Parent = row

			counters[tierId] = { count = count, button = button }
		end
	end

	toast = Instance.new("TextLabel")
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0.1, 0)
	toast.Size = UDim2.new(0, 340, 0, 54)
	toast.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	toast.BackgroundTransparency = 0.1
	toast.TextColor3 = Color3.fromRGB(255, 220, 90)
	toast.Font = Enum.Font.GothamBold
	toast.TextScaled = true
	toast.Visible = false
	toast.ZIndex = 5
	toast.Parent = gui
	local toastCorner = Instance.new("UICorner")
	toastCorner.Parent = toast

	result.OnClientEvent:Connect(function(ok: any, reason: any, _tier: any, kind: any, id: any, amount: any)
		if ok == true then
			if kind == "points" then
				toast.Text = ("You got %d Mog Points!"):format(if type(amount) == "number" then amount else 0)
			elseif kind == "unit" then
				toast.Text = ("You got a %s unit!"):format(tostring(id))
			else
				toast.Text = ("New cosmetic: %s!"):format(tostring(id))
			end
		else
			toast.Text = MESSAGES[tostring(reason)] or "Could not open the box."
		end
		toastUntil = Workspace:GetServerTimeNow() + 3
	end)
end

function BoxHud.start()
	RunService.RenderStepped:Connect(update)
end

return BoxHud
