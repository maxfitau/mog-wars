--!strict
-- CHARACTER REACTIONS (server). There are no animation assets, so the poses are made on every CLIENT from the character's
-- Motor6D joints (ReactionController). The server only decides WHEN and tells everyone with Remotes.Reaction (userId, kind):
--   "smug" : everyone who helped when a flag or a territory was captured strikes a smug pose with sunglasses (about 2.5 s)
--   "fall" : a player who falls into the clouds cries and flails, with a "NOOO" over the head (1.5 s)
-- Cheap: nothing runs per frame. Smug is event driven; falls are found by one loop every 0.25 s that looks at each root's height
-- and fires ONCE per fall (VoidSystem is not touched; it kills at Pace.void.killY, this reacts 20 studs earlier). Each kind is
-- rate limited per player. Sounds: Sounds.playAt on the root part (keys "smug" and "noooo"); the client also plays them for the
-- local player. Nothing here ever blocks movement.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Pace = require(Shared:WaitForChild("Pace"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local CaptureSystem = require(script.Parent:WaitForChild("CaptureSystem"))
local Events = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("Events"))

local ReactionSystem = {}

local MIN_GAP = { smug = 4, fall = 3 } :: { [string]: number }
local FALL_HEIGHT = Pace.void.killY + 20 -- -40: react just before the void kills you
local CHECK_SECONDS = 0.25

local remote: RemoteEvent? = nil
local lastFired: { [Player]: { [string]: number } } = {}
local fellThisLife: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Tell every client that `player` reacts. Rate limited per player and kind; bad kinds are ignored.
local function react(player: Player, kind: string)
	if remote == nil or MIN_GAP[kind] == nil or player.Parent ~= Players then
		return
	end
	local root = rootOf(player)
	if not root then
		return
	end
	local times = lastFired[player]
	if not times then
		times = {}
		lastFired[player] = times
	end
	local now = os.clock()
	if now - (times[kind] or -100) < MIN_GAP[kind] then
		return
	end
	times[kind] = now
	remote:FireAllClients(player.UserId, kind)
	Sounds.playAt(root, if kind == "fall" then "noooo" else "smug")
end

local function smugFor(player: Player)
	react(player, "smug")
end

function ReactionSystem.init()
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	local created = Instance.new("RemoteEvent")
	created.Name = "Reaction"
	created.Parent = folder
	remote = created

	-- everyone who helped with a flag (and, via the territory event, with a whole territory)
	Events.on(function(player: Player, kind: string)
		if kind == "flag" or kind == "territory" then
			smugFor(player)
		end
	end)
	-- the whole winning team of a captured territory (players on the war island only)
	table.insert(CaptureSystem.captureListeners, function(_territoryName: string, ownerFactionId: number)
		for _, player in Players:GetPlayers() do
			if player:GetAttribute("Faction") == ownerFactionId and player:GetAttribute("Island") ~= "training" then
				smugFor(player)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastFired[player] = nil
	end)
end

function ReactionSystem.start()
	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = rootOf(player)
				if character and root and root.Position.Y < FALL_HEIGHT and not fellThisLife[character] then
					fellThisLife[character] = true -- once per fall (the respawn is a new character)
					react(player, "fall")
				end
			end
		end
	end)
end

return ReactionSystem
