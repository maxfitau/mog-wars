--!strict
-- THE WEEKLY EVENT PILL: a small button in the right column, between the top-centre tiles and the minimap (docs/HUD_LAYOUT.md:
-- right edge, y 64-104; the minimap starts at y 112). It shows the event name and its countdown ("Meteor Storm Saturday 2d 4h") and
-- pulses gold while the event is LIVE ("LIVE 1h 40m"). A small ribbon on its corner shows the season name. Tapping it opens one
-- small card (HudSlots.card) with what the event is, its reward and the Team League standings. Display only: it reads the
-- Workspace attributes WeeklyEventName / WeeklyEventLive / WeeklyEventEndsAt / WeeklyEventNextAt, SeasonName, SeasonId,
-- League1..League4 and LeagueWeek that the server publishes. ASCII text only, every picture is a drawn shape.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EventSchedule = require(Shared:WaitForChild("EventSchedule"))
local FactionRules = require(Shared:WaitForChild("FactionRules"))
local SeasonConfig = require(Shared:WaitForChild("SeasonConfig"))
local HudSlots = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("HudSlots"))
local UiTheme = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("UiTheme"))

local EventCountdown = {}

local player = Players.LocalPlayer

local NAVY = Color3.fromRGB(18, 22, 58)
local GOLD = Color3.fromRGB(255, 205, 60)
local GOLD_BRIGHT = Color3.fromRGB(255, 240, 150)
local WHITE = Color3.new(1, 1, 1)
local PILL_WIDTH, PILL_HEIGHT = 176, 40
local CARD_TOP = HudSlots.cardY -- the shared card slot

local nameLabel: TextLabel
local timeLabel: TextLabel
local seasonTag: TextLabel
local pillStroke: UIStroke
local pill: TextButton
local card: TextButton
local cardLines: { TextLabel } = {}
local cardOpen = false
local closeCard: (() -> ())? = nil

local function isLive(): boolean
	return Workspace:GetAttribute("WeeklyEventLive") == true
end

local function eventName(): string
	local name = Workspace:GetAttribute("WeeklyEventName")
	if type(name) == "string" and name ~= "" then
		return name
	end
	return EventSchedule.settings.name
end

-- "2d 4h" until the start, or "LIVE 1h 40m" while it runs (server time is unix seconds).
local function countdown(): string
	local now = Workspace:GetServerTimeNow()
	if isLive() then
		local endsAt = Workspace:GetAttribute("WeeklyEventEndsAt")
		local left = if type(endsAt) == "number" then endsAt - now else EventSchedule.secondsLeft(now)
		return "LIVE " .. EventSchedule.spanText(left)
	end
	local nextAt = Workspace:GetAttribute("WeeklyEventNextAt")
	local seconds = if type(nextAt) == "number" and nextAt > now then nextAt - now else EventSchedule.secondsUntil(now)
	return EventSchedule.spanText(seconds)
end

local function seasonName(): string
	local name = Workspace:GetAttribute("SeasonName")
	if type(name) == "string" and name ~= "" then
		return name
	end
	return ""
end

local function seasonColour(): Color3
	local id = Workspace:GetAttribute("SeasonId")
	local season = SeasonConfig.byId(id)
	if season then
		return Color3.fromRGB(season.accent[1], season.accent[2], season.accent[3])
	end
	return Color3.fromRGB(200, 200, 220)
end

local function refresh()
	nameLabel.Text = eventName()
	timeLabel.Text = countdown()
	timeLabel.TextColor3 = if isLive() then GOLD_BRIGHT else WHITE
	local season = seasonName()
	seasonTag.Visible = season ~= ""
	seasonTag.Text = string.upper(season)
	seasonTag.BackgroundColor3 = seasonColour()
	if not isLive() then
		pillStroke.Color = Color3.fromRGB(150, 140, 200)
		pillStroke.Transparency = 0.25
	end
end

-- "Jawline 2  Mewing 0  Sigma 1  Aura 0": the first word of each team and its wars won this week.
local function leagueText(): string
	local parts = {}
	for _, faction in FactionRules.factions do
		local wins = Workspace:GetAttribute("League" .. faction.id)
		local word = string.match(faction.name, "^(%S+)") or faction.name
		table.insert(parts, ("%s %d"):format(word, if type(wins) == "number" then wins else 0))
	end
	return "League: " .. table.concat(parts, "  ")
end

local function fillCard()
	local live = isLive()
	local texts = {
		string.upper(eventName()) .. (if live then " - LIVE!" else ""),
		EventSchedule.windowText(),
		"2x aura + a meteor every 90 seconds",
		"Capture a flag or claim a meteor: free weapon chest + aura burst (once)",
		leagueText(),
		if seasonName() ~= "" then "Season: " .. seasonName() else "",
	}
	for index, label in cardLines do
		label.Text = texts[index] or ""
		label.Visible = label.Text ~= ""
	end
	cardLines[1].TextColor3 = GOLD
	cardLines[6].TextColor3 = seasonColour()
end

local function showCard()
	if cardOpen then
		return
	end
	cardOpen = true
	HudSlots.card(function(done)
		fillCard()
		card.Visible = true
		card.Position = UDim2.new(0.5, 0, 0, -220)
		TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0, CARD_TOP) }):Play()
		local closed = false
		local function close()
			if closed then
				return
			end
			closed = true
			closeCard = nil
			TweenService:Create(card, TweenInfo.new(0.25), { Position = UDim2.new(0.5, 0, 0, -220) }):Play()
			task.wait(0.3)
			card.Visible = false
			cardOpen = false
			done()
		end
		closeCard = close
		task.delay(7, close)
	end)
end

local function addText(parent: Instance, size: UDim2, position: UDim2, font: Enum.Font, textSize: number, alignment: Enum.TextXAlignment): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = size
	label.Position = position
	label.Font = font
	label.TextSize = textSize
	label.TextColor3 = WHITE
	label.TextXAlignment = alignment
	label.TextWrapped = true
	label.Text = ""
	label.Parent = parent
	return label
end

local function buildPill(gui: ScreenGui)
	pill = Instance.new("TextButton")
	pill.Name = "EventPill"
	pill.AnchorPoint = Vector2.new(1, 0)
	pill.Position = UDim2.new(1, -12, 0, 64) -- right column, above the minimap (which starts at y 112)
	pill.Size = UDim2.fromOffset(PILL_WIDTH, PILL_HEIGHT)
	pill.BackgroundColor3 = NAVY
	pill.BackgroundTransparency = 0.15
	pill.AutoButtonColor = true
	pill.Text = ""
	pill.Parent = gui
	UiTheme.round(pill, UDim.new(0, 12))
	pillStroke = Instance.new("UIStroke")
	pillStroke.Thickness = 2
	pillStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	pillStroke.Color = Color3.fromRGB(150, 140, 200)
	pillStroke.Parent = pill
	local fit = Instance.new("UIScale") -- a touch smaller on narrow phone screens so it never reaches the top-centre tiles
	fit.Parent = pill
	local function rescale()
		local camera = Workspace.CurrentCamera
		fit.Scale = if camera then math.clamp(camera.ViewportSize.X / 900, 0.75, 1) else 1
	end
	rescale()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end

	-- the picture: a gold meteor with a tail, drawn from shapes
	local tail = Instance.new("Frame")
	tail.AnchorPoint = Vector2.new(0.5, 0.5)
	tail.Position = UDim2.fromOffset(13, 25)
	tail.Size = UDim2.fromOffset(20, 6)
	tail.Rotation = -35
	tail.BackgroundColor3 = Color3.fromRGB(255, 140, 60)
	tail.BackgroundTransparency = 0.35
	tail.BorderSizePixel = 0
	tail.Parent = pill
	UiTheme.round(tail, UDim.new(1, 0))
	local rock = Instance.new("Frame")
	rock.AnchorPoint = Vector2.new(0.5, 0.5)
	rock.Position = UDim2.fromOffset(22, 17)
	rock.Size = UDim2.fromOffset(16, 16)
	rock.BackgroundColor3 = GOLD
	rock.BorderSizePixel = 0
	rock.Parent = pill
	UiTheme.round(rock, UDim.new(1, 0))

	nameLabel = addText(pill, UDim2.new(1, -46, 0, 15), UDim2.fromOffset(40, 4), Enum.Font.GothamBold, 11, Enum.TextXAlignment.Left)
	nameLabel.TextWrapped = false
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	timeLabel = addText(pill, UDim2.new(1, -46, 0, 20), UDim2.fromOffset(40, 18), UiTheme.font, 17, Enum.TextXAlignment.Left)
	timeLabel.TextWrapped = false

	-- the season ribbon on the pill's top-left corner
	seasonTag = addText(pill, UDim2.fromOffset(58, 13), UDim2.fromOffset(8, -8), Enum.Font.GothamBlack, 9, Enum.TextXAlignment.Center)
	seasonTag.BackgroundTransparency = 0
	seasonTag.BackgroundColor3 = Color3.fromRGB(170, 215, 255)
	seasonTag.TextColor3 = Color3.fromRGB(25, 25, 55)
	seasonTag.TextWrapped = false
	seasonTag.Visible = false
	UiTheme.round(seasonTag, UDim.new(1, 0))

	pill.Activated:Connect(function()
		if cardOpen then
			local close = closeCard
			if close then
				task.spawn(close)
			end
			return
		end
		showCard()
	end)
end

local function buildCard(gui: ScreenGui)
	card = Instance.new("TextButton")
	card.Name = "EventCard"
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Size = UDim2.fromOffset(340, 156)
	card.Position = UDim2.new(0.5, 0, 0, -220)
	card.BackgroundColor3 = NAVY
	card.BackgroundTransparency = 0.08
	card.AutoButtonColor = false
	card.Text = ""
	card.Visible = false
	card.Parent = gui
	UiTheme.round(card, UDim.new(0, 14))
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = GOLD
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = card
	local padding = Instance.new("UIPadding")
	padding.PaddingTop, padding.PaddingBottom = UDim.new(0, 8), UDim.new(0, 6)
	padding.PaddingLeft, padding.PaddingRight = UDim.new(0, 12), UDim.new(0, 12)
	padding.Parent = card
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 3)
	layout.Parent = card
	for index = 1, 6 do
		local label = addText(card, UDim2.new(1, 0, 0, if index == 1 then 22 else 17), UDim2.new(), if index == 1 then UiTheme.font else Enum.Font.GothamBold, if index == 1 then 18 else 12, Enum.TextXAlignment.Left)
		label.LayoutOrder = index
		label.TextWrapped = index == 4
		label.TextTruncate = Enum.TextTruncate.AtEnd
		if index == 4 then
			label.Size = UDim2.new(1, 0, 0, 32) -- the reward line may need two rows
			label.TextYAlignment = Enum.TextYAlignment.Top
		end
		table.insert(cardLines, label)
	end
	local fit = Instance.new("UIScale")
	fit.Parent = card
	local function rescale()
		local camera = Workspace.CurrentCamera
		fit.Scale = if camera then math.clamp(camera.ViewportSize.X / 700, 0.7, 1) else 1
	end
	rescale()
	card.Activated:Connect(function()
		local close = closeCard
		if close then
			task.spawn(close)
		end
	end)
end

function EventCountdown.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "EventCountdown"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	gui.Parent = player:WaitForChild("PlayerGui")
	buildPill(gui)
	buildCard(gui)
	refresh()

	-- text twice a second, the gold pulse every frame while live
	local sinceText = 0
	local clock = 0
	RunService.Heartbeat:Connect(function(dt)
		sinceText += dt
		if sinceText >= 0.5 then
			sinceText = 0
			refresh()
		end
		if isLive() then
			clock += dt
			local wave = (math.sin(clock * 4) + 1) / 2
			pillStroke.Color = GOLD:Lerp(GOLD_BRIGHT, wave)
			pillStroke.Transparency = 0.45 * (1 - wave)
			pillStroke.Thickness = 2 + wave * 1.5
		else
			pillStroke.Thickness = 2
		end
	end)
	for _, name in { "WeeklyEventLive", "SeasonName", "WeeklyEventNextAt" } do
		Workspace:GetAttributeChangedSignal(name):Connect(refresh)
	end
	-- the event just went live: say so in the line slot (replaces the mission text for 3 seconds)
	Workspace:GetAttributeChangedSignal("WeeklyEventLive"):Connect(function()
		if isLive() then
			HudSlots.line("METEOR STORM IS LIVE - 2x AURA!", GOLD, 3)
		end
	end)
end

function EventCountdown.start() end

return EventCountdown
