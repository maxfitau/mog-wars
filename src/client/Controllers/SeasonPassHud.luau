--!strict
-- THE FREE SEASON PASS SCREEN. THE PASS IS OFF UNTIL UPDATE 1: this controller is only loaded when Features.seasonPass is true.
-- A small "PASS" button (right column, under the minimap) opens a panel with a progress bar and 20 tier tiles. A tile shows its
-- reward and a CLAIM button once you reach it. Display only: the server owns xp and claims; this reads the player attributes
-- PassXp, PassTier and PassClaimed and asks with Remotes.ClaimPassTier (one tier number). Drawn shapes and ASCII text only.

local HudSlots = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("HudSlots"))
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SeasonPassConfig = require(Shared:WaitForChild("SeasonPassConfig"))
local UiTheme = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("UiTheme"))

local SeasonPassHud = {}

local player = Players.LocalPlayer

type Tile = { frame: Frame, label: TextLabel, button: TextButton, number: TextLabel }

local panel: Frame
local barFill: Frame
local barText: TextLabel
local tiles: { Tile } = {}
local request: RemoteEvent

local function claimedSet(): { [number]: boolean }
	local set: { [number]: boolean } = {}
	local text = player:GetAttribute("PassClaimed")
	if type(text) == "string" then
		for digits in string.gmatch(text, "%d+") do
			local tier = tonumber(digits)
			if tier then
				set[tier] = true
			end
		end
	end
	return set
end

local function refresh()
	local xpValue = player:GetAttribute("PassXp")
	local xp = if type(xpValue) == "number" then xpValue else 0
	local tier = SeasonPassConfig.tierForXp(xp)
	local into, need = SeasonPassConfig.progress(xp)
	barFill.Size = UDim2.new(math.clamp(into / math.max(1, need), 0, 1), 0, 1, 0)
	if tier >= SeasonPassConfig.tierCount then
		barText.Text = "Tier 20: pass complete!"
	else
		barText.Text = ("Tier %d   %d / %d xp"):format(tier, math.floor(into), need)
	end
	local claimed = claimedSet()
	for index, tile in tiles do
		local reached = tier >= index
		local done = claimed[index] == true
		tile.frame.BackgroundColor3 = if done then Color3.fromRGB(40, 110, 70) elseif reached then UiTheme.colors.orange else UiTheme.panel
		tile.button.Visible = reached and not done
		tile.number.TextTransparency = if reached then 0 else 0.45
		tile.label.Text = if done then "CLAIMED" else SeasonPassConfig.describe(SeasonPassConfig.rewards[index])
	end
end

local function label(parent: Instance, text: string, size: UDim2, position: UDim2): TextLabel
	local made = Instance.new("TextLabel")
	made.Text = text
	made.BackgroundTransparency = 1
	made.Size = size
	made.Position = position
	made.Font = UiTheme.font
	made.TextScaled = true
	made.TextColor3 = Color3.new(1, 1, 1)
	made.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.Color = UiTheme.outline
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = made
	return made
end

function SeasonPassHud.init()
	request = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ClaimPassTier") :: RemoteEvent

	local gui = Instance.new("ScreenGui")
	gui.Name = "SeasonPassHud"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	-- the small button: right column, under the minimap (move it if the layout changes, see docs/HUD_LAYOUT.md)
	local open = Instance.new("TextButton")
	open.Text = "PASS"
	open.AnchorPoint = Vector2.new(0, 0)
	open.Position = UDim2.new(0, 16 + 230 * HudSlots.leftScale(), 0, 172) -- the Quests row, right of the Weapons pill (the pass is off)
	open.Size = UDim2.new(0, 64, 0, 30)
	open.BackgroundColor3 = UiTheme.colors.blue
	open.Font = UiTheme.font
	open.TextScaled = true
	open.TextColor3 = Color3.new(1, 1, 1)
	open.Parent = gui
	UiTheme.round(open, UDim.new(0, 10))

	panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.new(0.5, 0, 0.5, 0)
	panel.Size = UDim2.new(0.8, 0, 0.82, 0)
	panel.BackgroundColor3 = Color3.fromRGB(30, 24, 60)
	panel.Visible = false
	panel.Parent = gui
	UiTheme.round(panel, UDim.new(0, 16))
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(640, 340)
	limit.Parent = panel

	label(panel, "FREE SEASON PASS", UDim2.new(0.6, 0, 0, 24), UDim2.new(0, 12, 0, 6))

	local close = Instance.new("TextButton")
	close.Text = "X"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -8, 0, 6)
	close.Size = UDim2.new(0, 28, 0, 24)
	close.BackgroundColor3 = UiTheme.colors.red
	close.Font = UiTheme.font
	close.TextScaled = true
	close.TextColor3 = Color3.new(1, 1, 1)
	close.Parent = panel
	UiTheme.round(close, UDim.new(0, 8))

	-- the progress bar
	local bar = Instance.new("Frame")
	bar.Position = UDim2.new(0, 12, 0, 36)
	bar.Size = UDim2.new(1, -24, 0, 20)
	bar.BackgroundColor3 = Color3.fromRGB(15, 12, 35)
	bar.Parent = panel
	UiTheme.round(bar, UDim.new(0, 10))
	barFill = Instance.new("Frame")
	barFill.Size = UDim2.new(0, 0, 1, 0)
	barFill.BackgroundColor3 = UiTheme.colors.green
	barFill.Parent = bar
	UiTheme.round(barFill, UDim.new(0, 10))
	barText = label(bar, "", UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0))

	-- 20 tiles, 5 across and 4 down
	local grid = Instance.new("Frame")
	grid.BackgroundTransparency = 1
	grid.Position = UDim2.new(0, 12, 0, 64)
	grid.Size = UDim2.new(1, -24, 1, -76)
	grid.Parent = panel
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0.19, 0, 0.225, 0)
	layout.CellPadding = UDim2.new(0.0125, 0, 0.03, 0)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	for index = 1, SeasonPassConfig.tierCount do
		local frame = Instance.new("Frame")
		frame.LayoutOrder = index
		frame.BackgroundColor3 = UiTheme.panel
		frame.Parent = grid
		UiTheme.round(frame, UDim.new(0, 8))
		local number = label(frame, tostring(index), UDim2.new(0.4, 0, 0.3, 0), UDim2.new(0, 4, 0, 2))
		local text = label(frame, "", UDim2.new(1, -8, 0.36, 0), UDim2.new(0, 4, 0.3, 0))
		local button = Instance.new("TextButton")
		button.Text = "CLAIM"
		button.AnchorPoint = Vector2.new(0.5, 1)
		button.Position = UDim2.new(0.5, 0, 1, -3)
		button.Size = UDim2.new(0.85, 0, 0.3, 0)
		button.BackgroundColor3 = UiTheme.colors.green
		button.Font = UiTheme.font
		button.TextScaled = true
		button.TextColor3 = Color3.new(1, 1, 1)
		button.Visible = false
		button.Parent = frame
		UiTheme.round(button, UDim.new(0, 6))
		button.Activated:Connect(function()
			request:FireServer(index) -- the server checks everything
		end)
		tiles[index] = { frame = frame, label = text, button = button, number = number }
	end

	open.Activated:Connect(function()
		panel.Visible = not panel.Visible
		refresh()
	end)
	close.Activated:Connect(function()
		panel.Visible = false
	end)
	for _, name in { "PassXp", "PassTier", "PassClaimed" } do
		player:GetAttributeChangedSignal(name):Connect(refresh)
	end
	refresh()
end

function SeasonPassHud.start() end

return SeasonPassHud
