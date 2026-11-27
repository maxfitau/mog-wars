--!strict
-- The daily reward: a small button that appears (top right, under the Shop button) only while a reward is waiting. Display only: the server owns the clock and the data and
-- mirrors DailyReady, DailyDay and BarracksPending onto the player. The buttons just ask.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Features = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Features"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("EconomyConfig"))

local RewardsHud = {}

local player = Players.LocalPlayer
local dailyButton: TextButton
local barracksButton: TextButton
local toast: TextLabel
local toastUntil = 0

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

local function update()
	local ready = attr("DailyReady", false) == true
	local day = attr("DailyDay", 1)
	local reward = Config.dailyStreak.auraRewards[day] or 0
	dailyButton.Visible = ready -- nothing on screen once it has been claimed
	dailyButton.Text = ("Daily reward! +%d aura"):format(reward)
	dailyButton.BackgroundColor3 = Color3.fromRGB(70, 180, 100)
	toast.Visible = Workspace:GetServerTimeNow() < toastUntil
end

function RewardsHud.init()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local claim = remotes:WaitForChild("ClaimDailyRequest") :: RemoteEvent
	local collect = remotes:WaitForChild("CollectBarracksRequest") :: RemoteEvent
	local result = remotes:WaitForChild("RewardsResult") :: RemoteEvent

	local gui = Instance.new("ScreenGui")
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

	toast = Instance.new("TextLabel")
	toast.Text = "" -- never show Roblox's default placeholder text
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0.1, 0)
	toast.Size = UDim2.new(0, 340, 0, 50)
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

	result.OnClientEvent:Connect(function(ok: any, reason: any, action: any, detail: any, amount: any)
		if ok == true then
			if action == "daily" then
				toast.Text = ("Day %d: +%s aura!"):format(if type(amount) == "number" then amount else 1, tostring(detail))
			else
				toast.Text = ("Collected %d Mog Points from the barracks!"):format(if type(amount) == "number" then amount else 0)
			end
		else
			toast.Text = MESSAGES[tostring(reason)] or "That did not work."
		end
		toastUntil = Workspace:GetServerTimeNow() + 3
	end)
end

function RewardsHud.start()
	RunService.RenderStepped:Connect(update)
end

return RewardsHud
