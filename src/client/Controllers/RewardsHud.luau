--!strict
-- The daily reward: claimed automatically the first time you play each day, and shown as a small pop-up card in the card slot
-- (upper third, one card at a time, via HudSlots.card). The card draws the 7-day streak as seven dots and always names the
-- day-7 prize: a free, guaranteed RARE weapon (never sold). There is no button. Display only: the server owns the clock and
-- the data and mirrors DailyReady, DailyDay and BarracksPending onto the player. The buttons just ask.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local WeaponCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WeaponCatalog"))
local HudSlots = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("HudSlots"))
local UiTheme = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("UiTheme"))

local RewardsHud = {}

local player = Players.LocalPlayer
local gui: ScreenGui
local dailyButton: TextButton
local barracksButton: TextButton
local claimRemote: RemoteEvent
local asked = false

local STREAK_DAYS = 7
local GOLD = Color3.fromRGB(255, 215, 60)
local RARE = Color3.fromRGB(80, 170, 255)

local MESSAGES: { [string]: string } = {
	already_claimed = "Come back tomorrow for the next reward!",
	boxes_full = "Open some boxes first.",
	nothing_to_collect = "Nothing in the barracks yet.",
	not_loaded = "Still loading your data.",
	clock_error = "Something is off with the date. Try later.",
	bad_input = "Something went wrong. Try again.",
}

local function attr(name: string, fallback: any): any
	local value = player:GetAttribute(name)
	return if value ~= nil then value else fallback
end

local function makeLabel(parent: Instance, text: string, position: UDim2, size: UDim2, colour: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = UiTheme.font
	label.TextScaled = true
	label.TextColor3 = colour
	label.TextStrokeColor3 = UiTheme.outline
	label.TextStrokeTransparency = 0
	label.Text = text
	label.Parent = parent
	return label
end

-- One pop-up card, 3.5 seconds, in the card slot. `day` (1 to 7) draws the streak dots; nil is a plain message.
local function showCard(title: string, subtitle: string, day: number?)
	HudSlots.card(function(done)
		local card = Instance.new("Frame")
		card.AnchorPoint = Vector2.new(0.5, 0)
		card.Position = UDim2.new(0.5, 0, 0, HudSlots.cardY) -- the card slot: centred, upper third
		card.Size = UDim2.new(0, 276, 0, if day then 92 else 52)
		card.BackgroundColor3 = UiTheme.panel
		card.BackgroundTransparency = 0.1
		card.Parent = gui
		UiTheme.round(card, UDim.new(0, 14))
		local stroke = Instance.new("UIStroke")
		stroke.Color = GOLD
		stroke.Thickness = 2
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = card
		makeLabel(card, title, UDim2.new(0, 8, 0, 4), UDim2.new(1, -16, 0, 26), GOLD)
		if day then
			for index = 1, STREAK_DAYS do
				local isPrize = index == STREAK_DAYS
				local size = if isPrize then 30 else 24
				local dot = Instance.new("Frame")
				dot.Position = UDim2.new(0, 14 + (index - 1) * 36, 0, 33 + (30 - size) / 2)
				dot.Size = UDim2.new(0, size, 0, size)
				dot.BackgroundColor3 = if index <= day then GOLD elseif isPrize then RARE else Color3.fromRGB(90, 80, 125)
				dot.BackgroundTransparency = if index <= day or isPrize then 0 else 0.2
				dot.Parent = card
				UiTheme.round(dot, UDim.new(1, 0))
				makeLabel(dot, tostring(index), UDim2.new(0, 3, 0, 3), UDim2.new(1, -6, 1, -6), if index <= day then Color3.fromRGB(60, 40, 0) else Color3.new(1, 1, 1))
			end
			makeLabel(card, subtitle, UDim2.new(0, 8, 0, 68), UDim2.new(1, -16, 0, 20), RARE)
		else
			makeLabel(card, subtitle, UDim2.new(0, 8, 0, 30), UDim2.new(1, -16, 0, 18), Color3.new(1, 1, 1))
		end
		task.delay(3.5, function()
			card:Destroy()
			done()
		end)
	end)
end

local function update()
	local ready = attr("DailyReady", false) == true
	dailyButton.Visible = false
	if ready and not asked then
		asked = true
		claimRemote:FireServer() -- the server checks it is really a new day
	elseif not ready then
		asked = false
	end
end

function RewardsHud.init()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local claim = remotes:WaitForChild("ClaimDailyRequest") :: RemoteEvent
	local collect = remotes:WaitForChild("CollectBarracksRequest") :: RemoteEvent
	local result = remotes:WaitForChild("RewardsResult") :: RemoteEvent
	claimRemote = claim

	gui = Instance.new("ScreenGui")
	gui.Name = "RewardsHud"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local function makeButton(offset: number): TextButton
		local button = Instance.new("TextButton")
		button.Text = "" -- never show Roblox's default placeholder text
		button.AnchorPoint = Vector2.new(1, 0)
		button.Position = UDim2.new(1, -16, 0, offset)
		button.Size = UDim2.new(0, 250, 0, 40)
		button.TextColor3 = Color3.new(1, 1, 1)
		button.Font = Enum.Font.GothamBold
		button.TextScaled = true
		button.Parent = gui
		local corner = Instance.new("UICorner")
		corner.Parent = button
		return button
	end
	dailyButton = makeButton(56)
	barracksButton = makeButton(100)
	barracksButton.Visible = false -- barracks are switched off
	dailyButton.Activated:Connect(function()
		claim:FireServer()
	end)
	barracksButton.Activated:Connect(function()
		collect:FireServer()
	end)

	result.OnClientEvent:Connect(function(ok: any, reason: any, action: any, detail: any, amount: any, prize: any)
		if ok == true then
			if action == "daily" then
				local day = if type(amount) == "number" then math.clamp(math.floor(amount), 1, STREAK_DAYS) else 1
				local subtitle = "Day 7: a free RARE weapon!"
				if day == STREAK_DAYS then
					local weapon = if type(prize) == "string" then WeaponCatalog.byId[prize] else nil
					subtitle = if weapon then ("RARE weapon: " .. weapon.name .. "!") else "You earned a free RARE weapon!"
				end
				showCard(("Day %d: +%s aura!"):format(day, tostring(detail)), subtitle, day)
			else
				showCard(("Collected %d Mog Points from the barracks!"):format(if type(amount) == "number" then amount else 0), "", nil)
			end
		else
			showCard(MESSAGES[tostring(reason)] or "That did not work.", "", nil)
		end
	end)
end

function RewardsHud.start()
	RunService.RenderStepped:Connect(update)
end

return RewardsHud
