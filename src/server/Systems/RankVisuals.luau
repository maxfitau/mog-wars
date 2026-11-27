--!strict
-- Your rank only changes how you LOOK, never how strong you are: a glow in the rank's colour, a title and a coloured
-- name floating over your head, and a pop-up when you earn a new rank. Server only (so everyone sees it).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("EconomyConfig"))
local Pace = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Pace"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local PopupSystem = require(script.Parent:WaitForChild("PopupSystem"))
local Events = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("Events"))

local RankVisuals = {}

-- One colour per rank: NPC, Rookie, Sigma, Chadlite, Chad, Gigachad, Mog God.
local COLORS = {
	Color3.fromRGB(170, 170, 180),
	Color3.fromRGB(110, 215, 110),
	Color3.fromRGB(90, 160, 255),
	Color3.fromRGB(80, 225, 225),
	Color3.fromRGB(255, 205, 60),
	Color3.fromRGB(255, 120, 80),
	Color3.fromRGB(195, 105, 255),
}

local function colorFor(rank: number): Color3
	return COLORS[math.clamp(rank, 1, #COLORS)]
end

local function apply(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not head or not head:IsA("BasePart") or not root or not root:IsA("BasePart") or not humanoid then
		return
	end
	local rankValue = player:GetAttribute("Rank")
	local rank = if type(rankValue) == "number" then rankValue else 1
	local color = colorFor(rank)
	local info = Config.ranks[math.clamp(rank, 1, #Config.ranks)]

	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None -- our own name tag replaces Roblox's
	for _, name in { "RankTag", "RankGlow", "RankSparkle" } do
		local old = character:FindFirstChild(name, true)
		if old then
			old:Destroy()
		end
	end

	-- title and name, in the rank colour
	local gui = Instance.new("BillboardGui")
	gui.Name = "RankTag"
	gui.Size = UDim2.new(0, 230, 0, 54)
	gui.StudsOffset = Vector3.new(0, 3.2, 0)
	gui.MaxDistance = 110
	gui.Adornee = head
	gui.Parent = head
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0.42, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = color
	title.TextStrokeColor3 = Color3.fromRGB(35, 25, 60)
	title.TextStrokeTransparency = 0
	title.Text = string.upper(info.name) .. (if type(player:GetAttribute("Title")) == "string" and player:GetAttribute("Title") ~= "" then "  *" .. string.upper(player:GetAttribute("Title") :: string) .. "*" else "")
	title.Parent = gui
	local name = Instance.new("TextLabel")
	name.Position = UDim2.new(0, 0, 0.42, 0)
	name.Size = UDim2.new(1, 0, 0.58, 0)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.FredokaOne
	name.TextScaled = true
	name.TextColor3 = color
	name.TextStrokeColor3 = Color3.fromRGB(35, 25, 60)
	name.TextStrokeTransparency = 0
	name.Text = player.DisplayName
	name.Parent = gui

	-- a glow that grows with the rank (a light, plus a few sparkles from Sigma up)
	local glow = Instance.new("PointLight")
	glow.Name = "RankGlow"
	glow.Color = color
	glow.Range = 5 + rank * 2
	glow.Brightness = 0.8 + rank * 0.15
	glow.Parent = root
	if rank >= 3 then
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Name = "RankSparkle"
		sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkle.Color = ColorSequence.new(color)
		sparkle.LightEmission = 0.8
		sparkle.Rate = 1 + rank * 1.5
		sparkle.Lifetime = NumberRange.new(0.8, 1.4)
		sparkle.Speed = NumberRange.new(1, 3)
		sparkle.SpreadAngle = Vector2.new(180, 180)
		sparkle.Size = NumberSequence.new(0.8, 0)
		sparkle.Parent = root
	end
end

local function watch(player: Player)
	player.CharacterAdded:Connect(function()
		task.wait(0.3) -- let the body finish loading
		apply(player)
	end)
	player:GetAttributeChangedSignal("Rank"):Connect(function()
		apply(player)
	end)
	player:GetAttributeChangedSignal("Title"):Connect(function()
		apply(player)
	end)
	if player.Character then
		task.spawn(apply, player)
	end
end

function RankVisuals.init()
	DataService.onRankUp = function(player: Player, rank: number)
		local info = Config.ranks[rank]
		PopupSystem.send(player, "rankup", rank, if info then info.name else "")
		Events.fire(player, "rank", rank)
	end
	DataService.onLevelUp = function(player: Player, level: number)
		-- a rank-up level gets the big rank-up banner instead
		if (level - 1) % Pace.levels.perRank ~= 0 or level > 6 * Pace.levels.perRank then
			PopupSystem.send(player, "levelup", level, ("x%.2f AURA"):format(Pace.levels.growth))
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

function RankVisuals.start() end

return RankVisuals
