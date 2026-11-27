--!strict
-- Slice 6: the shove ability. The client sends a bare "ShoveRequest" with NO data; the server decides who
-- (if anyone) is shoved, using ShoveRules. Checks run in this order: war running, throttle, cooldown,
-- shover alive and in a faction, then target choice (nearest living enemy in range).
-- Effects: the target is pushed back (the target's own client applies it), pushes at reduced power for a
-- few seconds (server-side attribute read by CaptureSystem), and a shove inside a zone earns the shover
-- a little contribution.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("EconomyConfig"))
local ShoveRules = require(Shared:WaitForChild("ShoveRules"))
local CaptureSystem = require(script.Parent:WaitForChild("CaptureSystem"))

local ShoveSystem = {}

local lastRequest: { [Player]: number } = {}
local lastShove: { [Player]: number } = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function handle(player: Player, knockbackRemote: RemoteEvent)
	local now = Workspace:GetServerTimeNow()

	if Workspace:GetAttribute("WarPhase") ~= "War" then
		return
	end
	if ShoveRules.tooFast(now, lastRequest[player] or -1000, Config.shove) then
		return
	end
	lastRequest[player] = now
	if not ShoveRules.offCooldown(now, lastShove[player] or -1000, Config.shove) then
		return
	end

	local root = rootOf(player)
	local faction = player:GetAttribute("Faction")
	if not root or type(faction) ~= "number" then
		return
	end

	local candidates: { ShoveRules.Candidate } = {}
	local byId: { [number]: Player } = {}
	for _, other in Players:GetPlayers() do
		local otherRoot = rootOf(other)
		local otherFaction = other:GetAttribute("Faction")
		if other ~= player and otherRoot and type(otherFaction) == "number" then
			local position = otherRoot.Position
			table.insert(candidates, {
				id = other.UserId,
				x = position.X,
				y = position.Y,
				z = position.Z,
				faction = otherFaction,
				alive = true,
			})
			byId[other.UserId] = other
		end
	end

	local origin = root.Position
	local targetId = ShoveRules.pickTarget(origin.X, origin.Y, origin.Z, faction, candidates, Config.shove)
	local target = if targetId then byId[targetId] else nil
	local targetRoot = if target then rootOf(target) else nil
	if not target or not targetRoot then
		return -- nothing in range: no cooldown is used
	end

	lastShove[player] = now
	player:SetAttribute("ShoveReadyAt", now + Config.shove.cooldownSeconds)
	target:SetAttribute("PushPenaltyUntil", now + Config.shove.penaltySeconds)

	local dx, dz = ShoveRules.direction(origin.X, origin.Z, targetRoot.Position.X, targetRoot.Position.Z)
	knockbackRemote:FireClient(target, dx, dz, Config.shove.knockbackStuds)
	CaptureSystem.creditShove(player, target)
end

function ShoveSystem.init()
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end

	local request = Instance.new("RemoteEvent")
	request.Name = "ShoveRequest"
	request.Parent = folder
	local knockback = Instance.new("RemoteEvent")
	knockback.Name = "ShoveKnockback"
	knockback.Parent = folder

	request.OnServerEvent:Connect(function(player: Player)
		-- Any arguments the client sent are ignored on purpose.
		handle(player, knockback)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
		lastShove[player] = nil
	end)
end

function ShoveSystem.start() end

return ShoveSystem
