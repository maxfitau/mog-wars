--!strict
-- Shows the war phase, countdown and each faction's score. Display only: it reads Workspace attributes
-- the server publishes (WarPhase, WarPhaseEndsAt, WarWinner, Score1..4) and never decides anything.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CollectionService = game:GetService("CollectionService")
local FactionRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FactionRules"))
local Pace = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Pace"))
local UiTheme = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("UiTheme"))

local WarHud = {}

local label: TextLabel
local scoreLabels: { TextLabel } = {}
local heldLabels: { TextLabel } = {}
local music: Sound? = nil

local function clock(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return ("%d:%02d"):format(seconds // 60, seconds % 60)
end

local function update()
	local phase = Workspace:GetAttribute("WarPhase")
	local endsAt = Workspace:GetAttribute("WarPhaseEndsAt")
	if type(phase) ~= "string" or type(endsAt) ~= "number" then
		label.Text = "Waiting for the server..."
		return
	end
	local remaining = endsAt - Workspace:GetServerTimeNow()
	if phase == "War" then
		if Workspace:GetAttribute("Overtime") == true then
			-- OVERTIME: the timer pulses red and the music speeds up
			local pulse = 0.5 + 0.5 * math.sin(os.clock() * 8)
			label.TextColor3 = Color3.fromRGB(255, 255 - math.floor(pulse * 190), 255 - math.floor(pulse * 190))
			label.Text = ("OVERTIME x2  %s"):format(clock(remaining))
			if music then
				music.PlaybackSpeed = Pace.overtime.musicSpeed
				if not music.IsPlaying then
					music:Play()
				end
			end
		else
			label.TextColor3 = Color3.new(1, 1, 1)
			label.Text = ("War %s  %s"):format(tostring(Workspace:GetAttribute("WarNumber")), clock(remaining))
			if music and music.IsPlaying then
				music:Stop()
			end
		end
	else
		local winner = Workspace:GetAttribute("WarWinner")
		local faction = if type(winner) == "number" then FactionRules.byId(winner) else nil
		local note = if faction then faction.name .. " won! " elseif Workspace:GetAttribute("WarNumber") ~= 0 then "Draw. " else ""
		label.TextColor3 = Color3.new(1, 1, 1)
		if music and music.IsPlaying then
			music:Stop()
		end
		label.Text = ("%sNext war %s"):format(note, clock(remaining))
	end
	-- territories held: a territory counts for a faction only when it owns ALL of that territory's flags
	local flags: { [string]: { number } } = {}
	for _, zone in CollectionService:GetTagged("Zone") do
		local territory = zone:GetAttribute("Territory")
		if type(territory) == "string" then
			local list = flags[territory] or {}
			flags[territory] = list
			table.insert(list, zone:GetAttribute("OwnerFaction") :: number)
		end
	end
	local held: { [number]: number } = {}
	for _, owners in flags do
		local first = owners[1]
		if type(first) == "number" and first ~= 0 then
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
	for id, text in heldLabels do
		text.Text = ("%d terr."):format(held[id] or 0)
	end
	for id, text in scoreLabels do
		local score = Workspace:GetAttribute("Score" .. id)
		text.Text = ("%d"):format(if type(score) == "number" then score else 0)
	end
end

function WarHud.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "WarHud"
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	-- top left, to the right of Roblox's own buttons and above the chat: one slim row, so it never covers anything else
	local frame = Instance.new("Frame")
	frame.Position = UDim2.new(0, 190, 0, 4)
	frame.Size = UDim2.new(0, 480, 0, 54)
	frame.BackgroundColor3 = UiTheme.panel
	frame.BackgroundTransparency = 0.1
	frame.Parent = gui
	UiTheme.round(frame, UDim.new(0, 20))
	local frameStroke = Instance.new("UIStroke")
	frameStroke.Color = Color3.new(1, 1, 1)
	frameStroke.Thickness = 3
	frameStroke.Parent = frame

	label = Instance.new("TextLabel")
	label.Text = "War" -- replaced every frame; never leave the default placeholder text
	label.BackgroundTransparency = 1
	label.Position = UDim2.new(0, 8, 0, 4)
	label.Size = UDim2.new(0, 124, 1, -8)
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeColor3 = UiTheme.outline
	label.TextStrokeTransparency = 0
	label.TextScaled = true
	label.Font = UiTheme.font
	label.Parent = frame

	-- one box per faction: its badge, the territories it holds (big) and its war score (small)
	local count = FactionRules.count()
	for id = 1, count do
		local faction = FactionRules.factions[id]
		local color = FactionRules.color(faction)
		local box = Instance.new("Frame")
		box.Size = UDim2.new(0, 82, 1, -10)
		box.Position = UDim2.new(0, 136 + (id - 1) * 86, 0, 5)
		box.BackgroundColor3 = color
		box.Parent = frame
		UiTheme.round(box, UDim.new(0, 12))
		local boxStroke = Instance.new("UIStroke")
		boxStroke.Color = Color3.new(1, 1, 1)
		boxStroke.Thickness = 2
		boxStroke.Parent = box

		local icon = Instance.new("TextLabel") -- faction badge: a round white disc with the faction's first letter
		icon.Size = UDim2.new(0, 24, 0, 24)
		icon.Position = UDim2.new(0, 4, 0.5, -12)
		icon.BackgroundColor3 = Color3.new(1, 1, 1)
		icon.TextColor3 = color
		icon.Font = UiTheme.font
		icon.TextScaled = true
		icon.Text = string.sub(faction.name, 1, 1)
		icon.Parent = box
		UiTheme.round(icon, UDim.new(1, 0))

		local held = Instance.new("TextLabel")
		held.Size = UDim2.new(1, -32, 0, 24)
		held.Position = UDim2.new(0, 30, 0, 2)
		held.BackgroundTransparency = 1
		held.TextColor3 = Color3.new(1, 1, 1)
		held.TextStrokeColor3 = UiTheme.outline
		held.TextStrokeTransparency = 0
		held.TextScaled = true
		held.Font = UiTheme.font
		held.Text = "0"
		held.Parent = box
		heldLabels[id] = held

		local score = Instance.new("TextLabel")
		score.Size = UDim2.new(1, -32, 0, 12)
		score.Position = UDim2.new(0, 30, 1, -15)
		score.BackgroundTransparency = 1
		score.TextColor3 = Color3.new(1, 1, 1)
		score.TextScaled = true
		score.Font = UiTheme.font
		score.Text = "0"
		score.Parent = box
		scoreLabels[id] = score
	end

	-- overtime music: the same track, played faster (set the id in Pace.sounds.overtimeMusic)
	if Pace.sounds.overtimeMusic ~= "" then
		music = Instance.new("Sound")
		music.SoundId = Pace.sounds.overtimeMusic
		music.Looped = true
		music.Volume = 0.4
		music.Parent = gui
	end
end

function WarHud.start()
	local reported = false
	RunService.RenderStepped:Connect(function()
		local ok, err = pcall(update)
		if not ok and not reported then
			reported = true
			warn("[mog-wars] WarHud update error: " .. tostring(err))
		end
	end)
end

return WarHud
