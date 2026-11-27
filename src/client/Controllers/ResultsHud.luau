--!strict
-- The 5-second results screen at the end of every war: your aura, mogs, assists and flags, and the MVP of each
-- faction. The server works it all out and sends it (WarResults); this only draws it. The next war starts straight
-- after, so it goes away by itself.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FactionRules = require(Shared:WaitForChild("FactionRules"))
local NumberFormat = require(Shared:WaitForChild("NumberFormat"))
local UiTheme = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("UiTheme"))

local ResultsHud = {}

local panel: Frame
local title: TextLabel
local mineLabel: TextLabel
local rows: { TextLabel } = {}
local token = 0

local function label(parent: Instance, size: UDim2, position: UDim2, text: string, color: Color3): TextLabel
	local item = Instance.new("TextLabel")
	item.Size = size
	item.Position = position
	item.BackgroundTransparency = 1
	item.Font = UiTheme.font
	item.TextScaled = true
	item.TextColor3 = color
	item.TextStrokeColor3 = UiTheme.outline
	item.TextStrokeTransparency = 0
	item.Text = text
	item.Parent = parent
	return item
end

function ResultsHud.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "ResultsHud"
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.new(0.5, 0, 0.45, 0)
	panel.Size = UDim2.new(0, 460, 0, 290)
	panel.BackgroundColor3 = UiTheme.panel
	panel.Visible = false
	panel.Parent = gui
	UiTheme.round(panel, UDim.new(0, 26))
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Thickness = 4
	stroke.Parent = panel

	title = label(panel, UDim2.new(1, -20, 0, 44), UDim2.new(0, 10, 0, 8), "WAR OVER", Color3.fromRGB(255, 215, 60))
	mineLabel = label(panel, UDim2.new(1, -20, 0, 34), UDim2.new(0, 10, 0, 56), "", Color3.new(1, 1, 1))
	for id = 1, FactionRules.count() do
		local faction = FactionRules.factions[id]
		rows[id] = label(panel, UDim2.new(1, -20, 0, 36), UDim2.new(0, 10, 0, 100 + (id - 1) * 44), "", FactionRules.color(faction))
		rows[id].TextXAlignment = Enum.TextXAlignment.Left
	end
end

function ResultsHud.start()
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("WarResults") :: RemoteEvent
	remote.OnClientEvent:Connect(function(factions: any, mine: any, winner: any, seconds: any)
		if type(factions) ~= "table" or type(mine) ~= "table" or type(seconds) ~= "number" then
			return
		end
		token += 1
		local current = token
		local winnerFaction = if type(winner) == "number" then FactionRules.byId(winner) else nil
		title.Text = if winnerFaction then string.upper(winnerFaction.name) .. " WIN!" else "DRAW!"
		mineLabel.Text = ("You: +%s aura   %d mogs   %d flags"):format(NumberFormat.format(tonumber(mine.aura) or 0), tonumber(mine.mogs) or 0, tonumber(mine.flags) or 0)
		for id, row in rows do
			local entry = factions[id]
			if type(entry) == "table" then
				row.Text = ("%s  MVP: %s  (%d mogs, %d flags)"):format(string.sub(FactionRules.factions[id].name, 1, 14), tostring(entry.mvp), tonumber(entry.mogs) or 0, tonumber(entry.flags) or 0)
			end
		end
		panel.Visible = true
		task.delay(seconds, function()
			if token == current then
				panel.Visible = false
			end
		end)
	end)
end

return ResultsHud
