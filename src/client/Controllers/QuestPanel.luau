--!strict
-- The three mini-quests of the war, on a small panel under the aura box: "Shove 5 Moglings 0/5". Finishing one ticks it with a
-- little bounce and the server gives an aura burst and a fresh quest. Display only: it reads the Quest1..3 attributes.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local UiTheme = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("UiTheme"))

local QuestPanel = {}

local player = Players.LocalPlayer
local rows: { { frame: Frame, text: TextLabel, count: TextLabel, tick: TextLabel } } = {}
local lastFlash = ""

function QuestPanel.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "QuestPanel"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local panel = Instance.new("Frame")
	panel.Position = UDim2.new(0, 16, 0, 172) -- under the aura box, top left, away from the middle of the screen
	panel.Size = UDim2.new(0, 270, 0, 90)
	panel.BackgroundColor3 = UiTheme.panel
	panel.BackgroundTransparency = 0.25
	panel.Parent = gui
	UiTheme.round(panel, UDim.new(0, 14))
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = panel
	for index = 1, 3 do
		local frame = Instance.new("Frame")
		frame.BackgroundTransparency = 1
		frame.Position = UDim2.new(0, 8, 0, 4 + (index - 1) * 28)
		frame.Size = UDim2.new(1, -16, 0, 24)
		frame.Parent = panel
		local tick = Instance.new("TextLabel")
		tick.Size = UDim2.new(0, 22, 0, 22)
		tick.Position = UDim2.new(0, 0, 0, 1)
		tick.BackgroundColor3 = Color3.fromRGB(255, 205, 60)
		tick.Font = UiTheme.font
		tick.TextScaled = true
		tick.TextColor3 = Color3.fromRGB(60, 40, 0)
		tick.Text = ""
		tick.Parent = frame
		UiTheme.round(tick, UDim.new(1, 0))
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Position = UDim2.new(0, 28, 0, 0)
		text.Size = UDim2.new(1, -86, 1, 0)
		text.Font = UiTheme.font
		text.TextScaled = true
		text.TextXAlignment = Enum.TextXAlignment.Left
		text.TextColor3 = Color3.new(1, 1, 1)
		text.TextStrokeColor3 = UiTheme.outline
		text.TextStrokeTransparency = 0
		text.Text = ""
		text.Parent = frame
		local count = Instance.new("TextLabel")
		count.BackgroundTransparency = 1
		count.Position = UDim2.new(1, -56, 0, 0)
		count.Size = UDim2.new(0, 56, 1, 0)
		count.Font = UiTheme.font
		count.TextScaled = true
		count.TextXAlignment = Enum.TextXAlignment.Right
		count.TextColor3 = Color3.fromRGB(255, 220, 90)
		count.TextStrokeColor3 = UiTheme.outline
		count.TextStrokeTransparency = 0
		count.Text = ""
		count.Parent = frame
		table.insert(rows, { frame = frame, text = text, count = count, tick = tick })
	end
end

function QuestPanel.start()
	local function refresh()
		for index, row in rows do
			local value = player:GetAttribute("Quest" .. index)
			if type(value) == "string" and value ~= "" then
				local text, progress, goal = string.match(value, "^(.*)|(%d+)|(%d+)$")
				row.text.Text = text or value
				row.count.Text = if text then ("%s/%s"):format(progress :: string, goal :: string) else ""
			else
				row.text.Text = ""
				row.count.Text = ""
			end
		end
	end
	for index = 1, 3 do
		player:GetAttributeChangedSignal("Quest" .. index):Connect(refresh)
	end
	player:GetAttributeChangedSignal("QuestFlash"):Connect(function()
		local flash = player:GetAttribute("QuestFlash")
		if type(flash) ~= "string" or flash == lastFlash then
			return
		end
		lastFlash = flash
		local slot = tonumber(string.match(flash, "^(%d+):"))
		local row = if slot then rows[slot] else nil
		if row then
			row.tick.Text = "OK" -- the tick, with a bounce
			row.tick.Size = UDim2.new(0, 34, 0, 34)
			TweenService:Create(row.tick, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.new(0, 22, 0, 22) }):Play()
			task.delay(1.2, function()
				row.tick.Text = ""
			end)
		end
	end)
	refresh()
end

return QuestPanel
