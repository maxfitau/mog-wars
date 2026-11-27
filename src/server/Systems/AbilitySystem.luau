--!strict
-- The rank-unlocked abilities. Shove is NPC (ShoveSystem), Dash is Rookie (MovementSystem), and Mog Stare is Sigma, here:
-- a short beam that freezes ONE enemy for a second (cooldown 8 s). The client sends a bare request; the server checks the
-- rank, the cooldown and that you are alive, picks the nearest enemy in front of you, and freezes them. Also records that
-- an unlock card was shown (so it is shown once, saved). Server only; the numbers are in Pace.abilities.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Pace = require(Shared:WaitForChild("Pace"))
local BotService = require(script.Parent:WaitForChild("BotService"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local MovementSystem = require(script.Parent:WaitForChild("MovementSystem"))
local PopupSystem = require(script.Parent:WaitForChild("PopupSystem"))

local AbilitySystem = {}

local lastStare: { [Player]: number } = {}
local lastRequest: { [Player]: number } = {}
local remotes: { [string]: RemoteEvent } = {}

local UNLOCK_RANK = { shove = Pace.abilities.shove.rank, dash = Pace.abilities.dash.rank, stare = Pace.abilities.stare.rank }

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function stare(player: Player)
	local now = Workspace:GetServerTimeNow()
	local rank = player:GetAttribute("Rank")
	local faction = player:GetAttribute("Faction")
	local root = rootOf(player)
	if type(rank) ~= "number" or rank < Pace.abilities.stare.rank or type(faction) ~= "number" or not root then
		return
	end
	if Workspace:GetAttribute("WarPhase") ~= "War" or now - (lastStare[player] or -100) < Pace.abilities.stare.cooldownSeconds then
		return
	end
	-- the nearest enemy within range, in front of you (a wide cone, so it works on a phone too)
	local forward = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if forward.Magnitude < 0.1 then
		return
	end
	forward = forward.Unit
	local bestDistance = Pace.abilities.stare.range
	local bestPlayer: Player? = nil
	local bestBot: BotService.Bot? = nil
	local bestPosition: Vector3? = nil
	local function consider(position: Vector3)
		local flat = Vector3.new(position.X - root.Position.X, 0, position.Z - root.Position.Z)
		local distance = flat.Magnitude
		if distance > 1 and distance < bestDistance and flat.Unit:Dot(forward) > 0.3 then
			bestDistance = distance
			bestPosition = position
			return true
		end
		return false
	end
	for _, other in Players:GetPlayers() do
		local otherRoot = rootOf(other)
		if other ~= player and otherRoot and type(other:GetAttribute("Faction")) == "number" and other:GetAttribute("Faction") ~= faction then
			if consider(otherRoot.Position) then
				bestPlayer, bestBot = other, nil
			end
		end
	end
	for _, bot in BotService.list() do
		if bot.faction ~= faction and consider(bot.root.Position) then
			bestPlayer, bestBot = nil, bot
		end
	end
	if not bestPosition then
		return -- nobody to stare at: no cooldown is used
	end
	lastStare[player] = now
	player:SetAttribute("StareReadyAt", now + Pace.abilities.stare.cooldownSeconds)
	if bestPlayer then
		MovementSystem.freeze(bestPlayer, Pace.abilities.stare.freezeSeconds)
		PopupSystem.send(bestPlayer, "announce", 1, "FROZEN BY A MOG STARE!")
	elseif bestBot then
		BotService.stun(bestBot, Pace.abilities.stare.freezeSeconds)
	end
	if remotes.StareFx then
		remotes.StareFx:FireAllClients(root.Position + Vector3.new(0, 1.5, 0), bestPosition + Vector3.new(0, 1.5, 0))
	end
end

function AbilitySystem.init()
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for _, name in { "StareRequest", "StareFx", "UnlockSeen" } do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		remotes[name] = remote
	end
	remotes.StareRequest.OnServerEvent:Connect(function(player: Player)
		local now = Workspace:GetServerTimeNow()
		if now - (lastRequest[player] or -100) < 0.2 then
			return
		end
		lastRequest[player] = now
		stare(player)
	end)
	remotes.UnlockSeen.OnServerEvent:Connect(function(player: Player, id: any)
		local rank = player:GetAttribute("Rank")
		if type(id) == "string" and UNLOCK_RANK[id] and type(rank) == "number" and rank >= UNLOCK_RANK[id] then
			DataService.markUnlockSeen(player, id)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastStare[player] = nil
		lastRequest[player] = nil
	end)
end

function AbilitySystem.start() end

return AbilitySystem
