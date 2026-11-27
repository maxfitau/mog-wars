--!strict
-- Kill feed, top right: "Kodo mogged Nova" with each name in its faction colour. The server sends the names
-- and faction ids; this only draws them. At most 5 lines, each fades after a few seconds.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FactionRules = require(Shared:WaitForChild("FactionRules"))
local UiTheme = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("UiTheme"))

local KillFeed = {}

local MAX_LINES = 5
local LINE_SECONDS = 5

local gui: ScreenGui
local list: Frame
local lines: { TextLabel } = {}

local function escape(text: string): string
	return (text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

local function colored(name: string, faction: number): string
	local info = FactionRules.byId(faction)
	local color = if info then FactionRules.color(info) else Color3.new(1, 1, 1)
	return ('<font color="#%s">%s</font>'):format(color:ToHex(), escape(name))
end

local function add(killer: any, killerFaction: any, victim: any, victimFaction: any)
	if type(killer) ~= "string" or type(victim) ~= "string" or type(killerFaction) ~= "number" or type(victimFaction) ~= "number" then
		return
	end
	while #lines >= MAX_LINES do
		local oldest = table.remove(lines, 1)
		if oldest then
			oldest:Destroy()
		end
	end
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 26)
	label.BackgroundColor3 = UiTheme.panel
	label.BackgroundTransparency = 0.35
	label.RichText = true
	label.Font = UiTheme.font
	label.TextSize = 18
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextXAlignment = Enum.TextXAlignment.Right
	label.Text = ("%s mogged %s "):format(colored(string.sub(killer, 1, 20), killerFaction), colored(string.sub(victim, 1, 20), victimFaction))
	label.LayoutOrder = os.clock() * 1000
	label.Parent = list
	UiTheme.round(label, UDim.new(0, 8))
	table.insert(lines, label)
	task.delay(LINE_SECONDS, function()
		local at = table.find(lines, label)
		if at then
			table.remove(lines, at)
		end
		local tween = TweenService:Create(label, TweenInfo.new(0.4), { BackgroundTransparency = 1, TextTransparency = 1 })
		tween.Completed:Connect(function()
			label:Destroy()
		end)
		tween:Play()
	end)
end

function KillFeed.init()
	gui = Instance.new("ScreenGui")
	gui.Name = "KillFeed"
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	list = Instance.new("Frame")
	list.AnchorPoint = Vector2.new(1, 0)
	list.Position = UDim2.new(1, -12, 0, 240) -- under the Roblox player list
	list.Size = UDim2.new(0, 300, 0, 160)
	list.BackgroundTransparency = 1
	list.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.Parent = list
end

function KillFeed.start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local remote = remotes:WaitForChild("KillFeed") :: RemoteEvent
	remote.OnClientEvent:Connect(add)
end

return KillFeed
