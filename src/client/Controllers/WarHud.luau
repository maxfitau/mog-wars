--!strict
-- The top HUD, chunky and bright. Centre: a round timer ("WAR 1" small, the time big) inside a ring that drains as the war runs
-- out; the ring and the numbers pulse red in the last 60 seconds. Either side: the four team tiles (team colour gradient, white
-- border, a dark drop shadow, a white round letter badge, the territories held as "3/7", a row of pips, a gold crown over the
-- leading team). A tile pulses when its team captures something. It never covers Roblox's own top-left buttons (it scales down on
-- narrow screens). Display only: it reads Workspace attributes and the flags' attributes the server publishes.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("EconomyConfig"))
local FactionRules = require(Shared:WaitForChild("FactionRules"))
local Pace = require(Shared:WaitForChild("Pace"))
local UiTheme = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("UiTheme"))

local WarHud = {}

local NAVY = Color3.fromRGB(18, 22, 58)
local RING_TICKS = 40
local TILE_W, TILE_H = 100, 68
local WIDTH = 520

type Tile = { frame: Frame, count: TextLabel, pips: { Frame }, crown: TextLabel, scale: UIScale, held: number }

local tiles: { Tile } = {}
local ticks: { Frame } = {}
local timeLabel: TextLabel
local warLabel: TextLabel
local circle: Frame
local circleScale: UIScale
local rootScale: UIScale
local totalTerritories = 7

local function clock(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return ("%d:%02d"):format(seconds // 60, seconds % 60)
end

local function lighten(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(1, 1, 1), amount)
end

local function makeTile(parent: Frame, id: number, x: number): Tile
	local faction = FactionRules.factions[id]
	local color = FactionRules.color(faction)
	local shadow = Instance.new("Frame") -- the dark drop shadow: a chunky 3D look
	shadow.Position = UDim2.new(0, x, 0, 8)
	shadow.Size = UDim2.new(0, TILE_W, 0, TILE_H)
	shadow.BackgroundColor3 = Color3.fromRGB(15, 10, 35)
	shadow.BackgroundTransparency = 0.25
	shadow.Parent = parent
	UiTheme.round(shadow, UDim.new(0, 16))
	local frame = Instance.new("Frame")
	frame.Position = UDim2.new(0, x, 0, 2)
	frame.Size = UDim2.new(0, TILE_W, 0, TILE_H)
	frame.BackgroundColor3 = color
	frame.Parent = parent
	UiTheme.round(frame, UDim.new(0, 16))
	local gradient = Instance.new("UIGradient") -- team colour gradient, lighter at the top
	gradient.Color = ColorSequence.new(lighten(color, 0.35), color:Lerp(Color3.new(0, 0, 0), 0.25))
	gradient.Rotation = 90
	gradient.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Thickness = 3
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame
	local scale = Instance.new("UIScale")
	scale.Parent = frame

	local badge = Instance.new("TextLabel") -- white circle with the team's letter
	badge.Size = UDim2.new(0, 28, 0, 28)
	badge.Position = UDim2.new(0, 7, 0, 7)
	badge.BackgroundColor3 = Color3.new(1, 1, 1)
	badge.Font = UiTheme.font
	badge.TextScaled = true
	badge.TextColor3 = color:Lerp(Color3.new(0, 0, 0), 0.2)
	badge.Text = string.sub(faction.name, 1, 1)
	badge.Parent = frame
	UiTheme.round(badge, UDim.new(1, 0))

	local count = Instance.new("TextLabel") -- big "3/7"
	count.Position = UDim2.new(0, 40, 0, 3)
	count.Size = UDim2.new(1, -46, 0, 36)
	count.BackgroundTransparency = 1
	count.Font = UiTheme.font
	count.TextScaled = true
	count.TextColor3 = Color3.new(1, 1, 1)
	count.TextStrokeColor3 = UiTheme.outline
	count.TextStrokeTransparency = 0
	count.Text = ("0/%d"):format(totalTerritories)
	count.Parent = frame

	local pips: { Frame } = {}
	for index = 1, totalTerritories do -- one pip per territory, filled for each one the team holds
		local pip = Instance.new("Frame")
		pip.Size = UDim2.new(0, 9, 0, 9)
		pip.Position = UDim2.new(0, 8 + (index - 1) * 12, 1, -17)
		pip.BackgroundColor3 = Color3.new(1, 1, 1)
		pip.BackgroundTransparency = 0.75
		pip.Parent = frame
		UiTheme.round(pip, UDim.new(1, 0))
		table.insert(pips, pip)
	end

	local crown = Instance.new("TextLabel") -- a gold crown over the leading team
	crown.Size = UDim2.new(0, 30, 0, 24)
	crown.Position = UDim2.new(0.5, -15, 0, -16)
	crown.BackgroundTransparency = 1
	crown.Font = UiTheme.font
	crown.TextScaled = true
	crown.Text = "👑"
	crown.Visible = false
	crown.ZIndex = 5
	crown.Parent = frame
	return { frame = frame, count = count, pips = pips, crown = crown, scale = scale, held = 0 }
end

function WarHud.init()
	local zones = {}
	for _, zone in CollectionService:GetTagged("Zone") do
		local territory = zone:GetAttribute("Territory")
		if type(territory) == "string" then
			zones[territory] = true
		end
	end
	local counted = 0
	for _ in zones do
		counted += 1
	end
	if counted > 0 then
		totalTerritories = counted
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "WarHud"
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local root = Instance.new("Frame")
	root.AnchorPoint = Vector2.new(0.5, 0)
	root.Position = UDim2.new(0.5, 0, 0, 10)
	root.Size = UDim2.new(0, WIDTH, 0, 96)
	root.BackgroundTransparency = 1
	root.Parent = gui
	rootScale = Instance.new("UIScale")
	rootScale.Parent = root

	-- team tiles: two each side of the timer
	local middle = WIDTH / 2
	local xs = { middle - 42 - 8 - TILE_W - 8 - TILE_W, middle - 42 - 8 - TILE_W, middle + 42 + 8, middle + 42 + 8 + TILE_W + 8 }
	for id = 1, FactionRules.count() do
		table.insert(tiles, makeTile(root, id, xs[id]))
	end

	-- the round timer, with a ring that drains
	circle = Instance.new("Frame")
	circle.AnchorPoint = Vector2.new(0.5, 0.5)
	circle.Position = UDim2.new(0, middle, 0, 46)
	circle.Size = UDim2.new(0, 84, 0, 84)
	circle.BackgroundColor3 = NAVY
	circle.Parent = root
	UiTheme.round(circle, UDim.new(1, 0))
	local circleStroke = Instance.new("UIStroke")
	circleStroke.Color = Color3.new(1, 1, 1)
	circleStroke.Thickness = 3
	circleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	circleStroke.Parent = circle
	circleScale = Instance.new("UIScale")
	circleScale.Parent = circle
	for index = 0, RING_TICKS - 1 do
		local angle = index / RING_TICKS * math.pi * 2
		local tick = Instance.new("Frame")
		tick.AnchorPoint = Vector2.new(0.5, 0.5)
		tick.Size = UDim2.new(0, 4, 0, 11)
		tick.Position = UDim2.new(0.5, math.sin(angle) * 47, 0.5, -math.cos(angle) * 47)
		tick.Rotation = math.deg(angle)
		tick.BackgroundColor3 = Color3.new(1, 1, 1)
		tick.BorderSizePixel = 0
		tick.Parent = circle
		table.insert(ticks, tick)
	end
	warLabel = Instance.new("TextLabel")
	warLabel.BackgroundTransparency = 1
	warLabel.Position = UDim2.new(0, 10, 0, 14)
	warLabel.Size = UDim2.new(1, -20, 0, 14)
	warLabel.Font = UiTheme.font
	warLabel.TextScaled = true
	warLabel.TextColor3 = Color3.fromRGB(190, 200, 255)
	warLabel.Text = "WAR"
	warLabel.Parent = circle
	timeLabel = Instance.new("TextLabel")
	timeLabel.BackgroundTransparency = 1
	timeLabel.Position = UDim2.new(0, 6, 0, 28)
	timeLabel.Size = UDim2.new(1, -12, 0, 32)
	timeLabel.Font = UiTheme.font
	timeLabel.TextScaled = true
	timeLabel.TextColor3 = Color3.new(1, 1, 1)
	timeLabel.TextStrokeColor3 = UiTheme.outline
	timeLabel.TextStrokeTransparency = 0
	timeLabel.Text = "0:00"
	timeLabel.Parent = circle
end

-- how many territories each team holds: a team holds one only when it owns ALL of its flags
local function territoriesHeld(): { [number]: number }
	local flags: { [string]: { number } } = {}
	for _, zone in CollectionService:GetTagged("Zone") do
		local territory = zone:GetAttribute("Territory")
		local owner = zone:GetAttribute("OwnerFaction")
		if type(territory) == "string" then
			local list = flags[territory] or {}
			flags[territory] = list
			table.insert(list, if type(owner) == "number" then owner else 0)
		end
	end
	local held: { [number]: number } = {}
	for _, owners in flags do
		local first = owners[1]
		if first ~= nil and first ~= 0 then
			local all = true
			for _, owner in owners do
				if owner ~= first then
					all = false
				end
			end
			if all then
				held[first] = (held[first] or 0) + 1
			end
		end
	end
	return held
end

local function updateTiles()
	local held = territoriesHeld()
	local best, bestCount, tied = 0, 0, false
	for id = 1, #tiles do
		local count = held[id] or 0
		if count > bestCount then
			best, bestCount, tied = id, count, false
		elseif count == bestCount and count > 0 then
			tied = true
		end
	end
	for id, tile in tiles do
		local count = held[id] or 0
		tile.count.Text = ("%d/%d"):format(count, totalTerritories)
		for index, pip in tile.pips do
			pip.BackgroundTransparency = if index <= count then 0 else 0.75
		end
		tile.crown.Visible = id == best and not tied and bestCount > 0 -- a crown for the leader; none if tied
		if count > tile.held then
			tile.scale.Scale = 1.18 -- this team just captured something: a quick pulse
			TweenService:Create(tile.scale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
		tile.held = count
	end
end

local function updateTimer()
	local phase = Workspace:GetAttribute("WarPhase")
	local endsAt = Workspace:GetAttribute("WarPhaseEndsAt")
	if type(phase) ~= "string" or type(endsAt) ~= "number" then
		timeLabel.Text = "..."
		return
	end
	local remaining = math.max(0, endsAt - Workspace:GetServerTimeNow())
	timeLabel.Text = clock(remaining)
	local fraction = 1
	local red = false
	if phase == "War" then
		warLabel.Text = ("WAR %s"):format(tostring(Workspace:GetAttribute("WarNumber")))
		fraction = math.clamp(remaining / Config.war.durationSeconds, 0, 1)
		red = remaining <= Pace.overtime.seconds
	else
		warLabel.Text = "NEXT WAR"
		fraction = 1
	end
	local pulse = if red then 0.5 + 0.5 * math.sin(os.clock() * 8) else 0
	local color = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(255, 70, 70), if red then 0.5 + pulse * 0.5 else 0)
	timeLabel.TextColor3 = color
	circleScale.Scale = 1 + pulse * 0.06
	for index, tick in ticks do
		tick.Visible = (index - 1) / RING_TICKS >= 1 - fraction -- the ring drains clockwise as time runs out
		tick.BackgroundColor3 = color
	end
end

function WarHud.start()
	local clockSince = 0
	RunService.RenderStepped:Connect(function(dt)
		local camera = Workspace.CurrentCamera
		if camera then
			-- never overlap Roblox's top-left buttons: shrink on narrow screens
			rootScale.Scale = math.clamp((camera.ViewportSize.X - 380) / WIDTH, 0.55, 1)
		end
		updateTimer()
		clockSince += dt
		if clockSince >= 0.25 then
			clockSince = 0
			updateTiles()
		end
	end)
end

return WarHud
