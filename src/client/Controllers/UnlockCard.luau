--!strict
-- "MOG POWER UNLOCKED: SHOVE!": a dramatic card with a flash, confetti, a 3-second demo of the power, then straight back
-- into the war. Shown once per ability, the first time you have it (NPC: Shove, Rookie: Dash, Sigma: Mog Stare).
-- The server saves that a card was seen (UnlockSeen), so it never repeats. Display only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Pace = require(Shared:WaitForChild("Pace"))
local UiTheme = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("UiTheme"))

local UnlockCard = {}

local player = Players.LocalPlayer
local gui: ScreenGui
local remote: RemoteEvent
local queue: { string } = {}
local showing = false

local ABILITIES: { [string]: { rank: number, title: string, hint: string, color: Color3 } } = {
	shove = { rank = Pace.abilities.shove.rank, title = "SHOVE!", hint = "Press E, click, or tap SHOVE to BONK enemies off flags", color = Color3.fromRGB(255, 160, 40) },
	dash = { rank = Pace.abilities.dash.rank, title = "GLOW-UP DASH!", hint = "A sparkly burst forward. Q or tap the button", color = Color3.fromRGB(70, 210, 100) },
	stare = { rank = Pace.abilities.stare.rank, title = "MOG STARE!", hint = "Freezes one enemy for 1 second", color = Color3.fromRGB(80, 170, 255) },
	slam = { rank = Pace.abilities.slam.rank, title = "JAWLINE SLAM!", hint = "Jump and pound: knocks back everyone close", color = Color3.fromRGB(255, 130, 60) },
	flip = { rank = Pace.abilities.flip.rank, title = "HAIR FLIP!", hint = "A big gust pushes enemies back and off flags", color = Color3.fromRGB(255, 110, 190) },
	shield = { rank = Pace.abilities.shield.rank, title = "MEWING SHIELD!", hint = "3 seconds immune to shoves and freezes", color = Color3.fromRGB(255, 205, 60) },
	total = { rank = Pace.abilities.total.rank, title = "TOTAL MOG!", hint = "Enemies nearby are REDUCED TO NPC for 2 seconds", color = Color3.fromRGB(190, 110, 255) },
}
local ORDER = { "shove", "dash", "stare", "slam", "flip", "shield", "total" }

local CONFETTI = { Color3.fromRGB(255, 205, 60), Color3.fromRGB(255, 100, 160), Color3.fromRGB(80, 220, 255), Color3.fromRGB(120, 230, 120), Color3.fromRGB(190, 110, 255) }

local function figure(parent: Instance, color: Color3, position: UDim2): Frame
	local body = Instance.new("Frame")
	body.Size = UDim2.new(0, 34, 0, 44)
	body.Position = position
	body.BackgroundColor3 = color
	body.Parent = parent
	UiTheme.round(body, UDim.new(0, 8))
	local head = Instance.new("Frame")
	head.Size = UDim2.new(0, 26, 0, 26)
	head.Position = UDim2.new(0.5, -13, 0, -22)
	head.BackgroundColor3 = Color3.fromRGB(245, 220, 180)
	head.Parent = body
	UiTheme.round(head, UDim.new(1, 0))
	return body
end

-- a 3-second demo of the power, drawn with two little blocky figures
local function demo(parent: Frame, id: string, color: Color3)
	local hero = figure(parent, color, UDim2.new(0.18, 0, 0.5, 0))
	local victim = figure(parent, Color3.fromRGB(150, 150, 170), UDim2.new(0.62, 0, 0.5, 0))
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.new(0, 160, 0, 40)
	text.Position = UDim2.new(0.62, -60, 0.1, 0)
	text.Font = UiTheme.font
	text.TextScaled = true
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeColor3 = UiTheme.outline
	text.TextStrokeTransparency = 0
	text.Text = ""
	text.Parent = parent
	task.spawn(function()
		task.wait(0.6)
		if id == "shove" then
			TweenService:Create(hero, TweenInfo.new(0.35), { Position = UDim2.new(0.5, 0, 0.5, 0) }):Play()
			task.wait(0.4)
			text.Text = "BONK!"
			TweenService:Create(victim, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { Position = UDim2.new(1.05, 0, 0.1, 0), Rotation = 540 }):Play()
		elseif id == "dash" then
			TweenService:Create(hero, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { Position = UDim2.new(0.55, 0, 0.5, 0) }):Play()
			text.Text = "ZOOM!"
		elseif id == "stare" then
			local beam = Instance.new("Frame")
			beam.BackgroundColor3 = Color3.fromRGB(150, 230, 255)
			beam.BorderSizePixel = 0
			beam.Size = UDim2.new(0, 0, 0, 6)
			beam.Position = UDim2.new(0.18, 34, 0.5, 6)
			beam.Parent = parent
			TweenService:Create(beam, TweenInfo.new(0.3), { Size = UDim2.new(0.4, 0, 0, 6) }):Play()
			task.wait(0.35)
			victim.BackgroundColor3 = Color3.fromRGB(160, 225, 255)
			text.Text = "FROZEN!"
		else
			-- slam, flip, shield and total: a burst that blows the other figure away (or a bubble that blocks)
			text.Text = if id == "shield" then "BLOCKED!" elseif id == "total" then "NPC..." else "WHOOSH!"
			if id == "total" then
				victim.BackgroundColor3 = Color3.fromRGB(120, 120, 130)
			elseif id ~= "shield" then
				TweenService:Create(victim, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { Position = UDim2.new(1.05, 0, 0.3, 0), Rotation = 360 }):Play()
			end
		end
	end)
end

local function confetti(parent: Instance)
	for _ = 1, 36 do
		local piece = Instance.new("Frame")
		piece.Size = UDim2.new(0, 10, 0, 14)
		piece.Position = UDim2.new(math.random(), 0, -0.08, 0)
		piece.BackgroundColor3 = CONFETTI[math.random(1, #CONFETTI)]
		piece.BorderSizePixel = 0
		piece.Rotation = math.random(0, 360)
		piece.Parent = parent
		TweenService:Create(piece, TweenInfo.new(1.6 + math.random() * 1.4, Enum.EasingStyle.Quad), {
			Position = UDim2.new(piece.Position.X.Scale + (math.random() - 0.5) * 0.3, 0, 1.1, 0),
			Rotation = piece.Rotation + math.random(-400, 400),
		}):Play()
		task.delay(3.2, function()
			piece:Destroy()
		end)
	end
end

local function show(id: string, done: () -> ())
	local ability = ABILITIES[id]
	remote:FireServer(id) -- the server saves that this card was shown
	local overlay = Instance.new("Frame")
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.fromRGB(20, 12, 45)
	overlay.BackgroundTransparency = 0.35
	overlay.BorderSizePixel = 0
	overlay.Parent = gui
	local flash = Instance.new("Frame") -- the white flash
	flash.Size = UDim2.new(1, 0, 1, 0)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BorderSizePixel = 0
	flash.ZIndex = 10
	flash.Parent = overlay
	TweenService:Create(flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
	confetti(overlay)

	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.new(0.5, 0, 0.5, 0)
	card.Size = UDim2.new(0, 120, 0, 60)
	card.BackgroundColor3 = UiTheme.panel
	card.Parent = overlay
	UiTheme.round(card, UDim.new(0, 28))
	local stroke = Instance.new("UIStroke")
	stroke.Color = ability.color
	stroke.Thickness = 6
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = card
	TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.new(0, 520, 0, 330) }):Play()

	local function label(text: string, height: number, y: number, color: Color3): TextLabel
		local item = Instance.new("TextLabel")
		item.BackgroundTransparency = 1
		item.Position = UDim2.new(0, 16, 0, y)
		item.Size = UDim2.new(1, -32, 0, height)
		item.Font = UiTheme.font
		item.TextScaled = true
		item.TextColor3 = color
		item.TextStrokeColor3 = UiTheme.outline
		item.TextStrokeTransparency = 0
		item.Text = text
		item.Parent = card
		return item
	end
	label("MOG POWER UNLOCKED:", 36, 12, Color3.fromRGB(255, 215, 60))
	label(ability.title, 70, 50, ability.color)
	local stage = Instance.new("Frame") -- the demo area
	stage.BackgroundColor3 = Color3.fromRGB(35, 25, 70)
	stage.Position = UDim2.new(0, 24, 0, 130)
	stage.Size = UDim2.new(1, -48, 0, 110)
	stage.ClipsDescendants = true
	stage.Parent = card
	UiTheme.round(stage, UDim.new(0, 16))
	demo(stage, id, ability.color)
	label(ability.hint, 30, 252, Color3.new(1, 1, 1))

	task.delay(3.4, function()
		TweenService:Create(overlay, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(card, TweenInfo.new(0.3), { Size = UDim2.new(0, 120, 0, 60) }):Play()
		task.wait(0.4)
		overlay:Destroy()
		done()
	end)
end

local function showNext()
	if showing then
		return
	end
	local id = table.remove(queue, 1)
	if not id then
		return
	end
	showing = true
	show(id, function()
		showing = false
		showNext()
	end)
end

local function check()
	local seenValue = player:GetAttribute("UnlocksSeen")
	local rankValue = player:GetAttribute("Rank")
	if type(seenValue) ~= "string" or type(rankValue) ~= "number" then
		return -- the saved data has not loaded yet
	end
	for _, id in ORDER do
		local ability = ABILITIES[id]
		if rankValue >= ability.rank and not string.find("," .. seenValue .. ",", "," .. id .. ",", 1, true) and not table.find(queue, id) then
			table.insert(queue, id)
		end
	end
	showNext()
end

function UnlockCard.init()
	gui = Instance.new("ScreenGui")
	gui.Name = "UnlockCard"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	gui.Parent = player:WaitForChild("PlayerGui")
	remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("UnlockSeen") :: RemoteEvent
end

function UnlockCard.start()
	player:GetAttributeChangedSignal("Rank"):Connect(check)
	player:GetAttributeChangedSignal("UnlocksSeen"):Connect(check)
	check()
end

return UnlockCard
