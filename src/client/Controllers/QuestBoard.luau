--!strict
-- THE QUEST BOARD: the 3 daily and 5 weekly quests, with progress bars and reward lines. It opens from the Daily and Weekly
-- buttons on the war quest list (under the small "Quests n/3" pill) or with the J key, in the LEFT COLUMN under the pill (never
-- the middle of the screen), and is invisible while closed. Display only: it reads the DailyQuests and WeeklyQuests attributes
-- the server writes ("id|progress|goal|claimed" entries joined by ";") and the DailyResetAt and WeeklyResetAt times. The server
-- pays finished quests by itself, so there is no claim button. ASCII text only; the tick is drawn from shapes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Pace = require(Shared:WaitForChild("Pace"))
local Levels = require(Shared:WaitForChild("Levels"))
local NumberFormat = require(Shared:WaitForChild("NumberFormat"))
local QuestCatalog = require(Shared:WaitForChild("QuestCatalog"))
local HudSlots = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("HudSlots"))
local UiTheme = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("UiTheme"))

local QuestBoard = {}

-- QuestPanel sets these so the two lists never show together.
QuestBoard.ready = false
QuestBoard.onOpen = nil :: (() -> ())?
QuestBoard.onWar = nil :: (() -> ())?

type Row = {
	frame: Frame,
	text: TextLabel,
	count: TextLabel,
	fill: Frame,
	reward: TextLabel,
	ring: Frame,
	tick: Frame,
}

local player = Players.LocalPlayer
local panel: Frame
local resetLabel: TextLabel
local tabButtons: { [string]: TextButton } = {}
local rows: { Row } = {}
local currentTab = "daily"
local isOpen = false

local MAX_ROWS = 5
local ROW_HEIGHT = 34
local GREEN = Color3.fromRGB(70, 210, 100)
local GOLD = Color3.fromRGB(255, 215, 60)
local TRACK = Color3.fromRGB(25, 20, 50)

local function label(parent: Instance, position: UDim2, size: UDim2, align: Enum.TextXAlignment, colour: Color3): TextLabel
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.Position = position
	item.Size = size
	item.Font = UiTheme.font
	item.TextScaled = true
	item.TextXAlignment = align
	item.TextColor3 = colour
	item.TextStrokeColor3 = UiTheme.outline
	item.TextStrokeTransparency = 0.2
	item.Text = ""
	item.Parent = parent
	return item
end

local function box(parent: Instance, position: UDim2, size: UDim2, colour: Color3, round: boolean): Frame
	local frame = Instance.new("Frame")
	frame.Position = position
	frame.Size = size
	frame.BackgroundColor3 = colour
	frame.BorderSizePixel = 0
	frame.Parent = parent
	if round then
		UiTheme.round(frame, UDim.new(1, 0))
	end
	return frame
end

-- A bar of the check mark: a thin frame turned 45 degrees.
local function stroke(parent: Instance, x: number, y: number, length: number, rotation: number)
	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(0.5, 0.5)
	bar.Position = UDim2.new(0, x, 0, y)
	bar.Size = UDim2.new(0, 3, 0, length)
	bar.Rotation = rotation
	bar.BackgroundColor3 = Color3.new(1, 1, 1)
	bar.BorderSizePixel = 0
	bar.Parent = parent
end

local function makeRow(index: number): Row
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.Position = UDim2.new(0, 8, 0, 48 + (index - 1) * ROW_HEIGHT)
	frame.Size = UDim2.new(1, -16, 0, ROW_HEIGHT - 2)
	frame.Parent = panel
	-- the left marker: an empty ring, or a green disc with a tick drawn from two bars
	local ring = box(frame, UDim2.new(0, 0, 0, 6), UDim2.new(0, 20, 0, 20), Color3.fromRGB(110, 100, 150), true)
	local hole = box(ring, UDim2.new(0, 3, 0, 3), UDim2.new(1, -6, 1, -6), UiTheme.panel, true)
	hole.Name = "Hole"
	local tick = box(frame, UDim2.new(0, 0, 0, 6), UDim2.new(0, 20, 0, 20), GREEN, true)
	tick.Visible = false
	stroke(tick, 7, 12, 7, -45)
	stroke(tick, 12, 10, 12, 45)
	local text = label(frame, UDim2.new(0, 26, 0, 0), UDim2.new(1, -70, 0, 16), Enum.TextXAlignment.Left, Color3.new(1, 1, 1))
	local count = label(frame, UDim2.new(1, -42, 0, 0), UDim2.new(0, 42, 0, 16), Enum.TextXAlignment.Right, GOLD)
	local track = box(frame, UDim2.new(0, 26, 0, 19), UDim2.new(1, -140, 0, 8), TRACK, false)
	UiTheme.round(track, UDim.new(0, 4))
	local fill = box(track, UDim2.new(0, 0, 0, 0), UDim2.new(0, 0, 1, 0), GOLD, false)
	UiTheme.round(fill, UDim.new(0, 4))
	local reward = label(frame, UDim2.new(1, -108, 0, 17), UDim2.new(0, 108, 0, 13), Enum.TextXAlignment.Right, Color3.fromRGB(150, 220, 255))
	return { frame = frame, text = text, count = count, fill = fill, reward = reward, ring = ring, tick = tick }
end

local function rewardText(template: QuestCatalog.Template): string
	local level = player:GetAttribute("Level")
	local multiplier = Levels.multiplier(if type(level) == "number" then level else 0)
	local aura = template.auraSeconds * Pace.levels.nominalIncome * multiplier
	return ("+%s aura%s"):format(NumberFormat.format(math.floor(aura + 0.5)), if template.chest then " + weapon" else "")
end

local function refresh()
	local daily = currentTab == "daily"
	local attribute = player:GetAttribute(if daily then "DailyQuests" else "WeeklyQuests")
	local entries = QuestCatalog.decode(if type(attribute) == "string" then attribute else "")
	for index, row in rows do
		local entry = entries[index]
		local template = if entry then QuestCatalog.byId(entry.id) else nil
		row.frame.Visible = entry ~= nil and template ~= nil
		if entry and template then
			local done = entry.claimed or entry.progress >= entry.goal
			row.text.Text = template.text
			row.count.Text = if done then "DONE" else ("%d/%d"):format(entry.progress, entry.goal)
			row.count.TextColor3 = if done then GREEN else GOLD
			row.fill.Size = UDim2.new(math.clamp(entry.progress / math.max(1, entry.goal), 0, 1), 0, 1, 0)
			row.fill.BackgroundColor3 = if done then GREEN else GOLD
			row.reward.Text = rewardText(template)
			row.tick.Visible = done
			row.ring.Visible = not done
		end
	end
	for name, button in tabButtons do
		button.BackgroundColor3 = if name == currentTab then GOLD else Color3.fromRGB(80, 70, 125)
		button.TextColor3 = if name == currentTab then Color3.fromRGB(60, 40, 0) else Color3.new(1, 1, 1)
	end
	local resetAt = player:GetAttribute(if daily then "DailyResetAt" else "WeeklyResetAt")
	local left = if type(resetAt) == "number" then resetAt - game:GetService("Workspace"):GetServerTimeNow() else 0
	resetLabel.Text = (if daily then "New daily quests in " else "New weekly quests in ") .. QuestCatalog.timeText(left)
	panel.Size = UDim2.new(0, 280, 0, 54 + (if daily then QuestCatalog.dailyCount else QuestCatalog.weeklyCount) * ROW_HEIGHT)
end

function QuestBoard.close()
	isOpen = false
	if QuestBoard.ready then
		panel.Visible = false
	end
end

function QuestBoard.open(tab: string?)
	if not QuestBoard.ready then
		return
	end
	if tab == "daily" or tab == "weekly" then
		currentTab = tab
	end
	if QuestBoard.onOpen then
		QuestBoard.onOpen()
	end
	isOpen = true
	panel.Visible = true
	refresh()
end

function QuestBoard.toggle()
	if isOpen then
		QuestBoard.close()
	else
		QuestBoard.open()
	end
end

function QuestBoard.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "QuestBoard"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	panel = Instance.new("Frame")
	panel.Name = "Board"
	panel.Position = UDim2.new(0, 16, 0, 206) -- the same spot as the war quest list, left column under the pill
	panel.Size = UDim2.new(0, 280, 0, 54 + QuestCatalog.dailyCount * ROW_HEIGHT)
	panel.BackgroundColor3 = UiTheme.panel
	panel.BackgroundTransparency = 0.12
	panel.Visible = false -- closed: nothing on screen
	panel.Parent = gui
	UiTheme.round(panel, UDim.new(0, 14))
	local outline = Instance.new("UIStroke")
	outline.Color = Color3.new(1, 1, 1)
	outline.Thickness = 2
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	outline.Parent = panel
	local fit = Instance.new("UIScale") -- the same shrink as the aura box on narrow screens
	fit.Scale = HudSlots.leftScale()
	fit.Parent = panel

	local tabs: { { id: string, text: string, slot: number } } = {
		{ id = "war", text = "War", slot = 0 },
		{ id = "daily", text = "Daily", slot = 1 },
		{ id = "weekly", text = "Weekly", slot = 2 },
	}
	for _, info in tabs do
		local button = Instance.new("TextButton")
		button.Position = UDim2.new(0, 8 + info.slot * 90, 0, 6)
		button.Size = UDim2.new(0, 84, 0, 22)
		button.BackgroundColor3 = Color3.fromRGB(80, 70, 125)
		button.Font = UiTheme.font
		button.TextScaled = true
		button.TextColor3 = Color3.new(1, 1, 1)
		button.Text = info.text
		button.Parent = panel
		UiTheme.round(button, UDim.new(1, 0))
		tabButtons[info.id] = button
		button.Activated:Connect(function()
			if info.id == "war" then
				QuestBoard.close()
				if QuestBoard.onWar then
					QuestBoard.onWar()
				end
			else
				currentTab = info.id
				refresh()
			end
		end)
	end
	resetLabel = label(panel, UDim2.new(0, 10, 0, 30), UDim2.new(1, -20, 0, 14), Enum.TextXAlignment.Left, Color3.fromRGB(200, 195, 230))
	for index = 1, MAX_ROWS do
		table.insert(rows, makeRow(index))
	end
	QuestBoard.ready = true
end

function QuestBoard.start()
	for _, name in { "DailyQuests", "WeeklyQuests", "DailyResetAt", "WeeklyResetAt" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			if isOpen then
				refresh()
			end
		end)
	end
	task.spawn(function()
		while true do -- keeps the "new quests in" countdown moving while the board is open
			task.wait(5)
			if isOpen then
				refresh()
			end
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.J then
			QuestBoard.toggle()
		end
	end)
end

return QuestBoard
