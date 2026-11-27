--!strict
-- Slice 2: assigns every player to one of four factions, balanced by head count, and shows it with a Team,
-- a coloured outline on the character, and a "Faction" attribute that other systems read. Server only.
-- A player keeps their faction until they leave (no remote exists to change it). Rejoining reassigns.
-- A joining player is placed on a friend's faction when that keeps the teams within a couple of players;
-- otherwise on the smallest faction. This system also loads characters (and respawns them after a defeat).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("EconomyConfig"))
local FactionRules = require(Shared:WaitForChild("FactionRules"))
local Features = require(Shared:WaitForChild("Features"))
local FriendService = require(script.Parent:WaitForChild("FriendService"))

local FRIEND_LOOKUP_SECONDS = 3 -- the longest a joining player waits for friend lookups before being placed

local assigned: { [Player]: number } = {}
local assigning: { [Player]: boolean } = {}
local FactionSystem = {}

local function counts(): { [number]: number }
	local result: { [number]: number } = {}
	for _, id in assigned do
		result[id] = (result[id] or 0) + 1
	end
	return result
end

local function outline(character: Model, factionId: number)
	local faction = FactionRules.byId(factionId)
	if not faction then
		return
	end
	local old = character:FindFirstChild("FactionOutline")
	if old then
		old:Destroy()
	end
	local highlight = Instance.new("Highlight")
	highlight.Name = "FactionOutline"
	highlight.FillColor = FactionRules.color(faction)
	highlight.OutlineColor = FactionRules.color(faction)
	highlight.FillTransparency = 0.75
	highlight.Parent = character
end

local function respawnLater(player: Player)
	task.delay(Players.RespawnTime, function()
		if player.Parent == Players and assigned[player] then
			player:LoadCharacter()
		end
	end)
end

-- The faction most of this player's friends (already in the server) are on, or nil if none are.
local function friendsFaction(player: Player): number?
	local tally: { [number]: number } = {}
	for other, id in assigned do
		if FriendService.areFriends(player, other) then
			tally[id] = (tally[id] or 0) + 1
		end
	end
	local best, bestCount = nil, 0
	for id = 1, FactionRules.count() do
		if (tally[id] or 0) > bestCount then
			best, bestCount = id, tally[id]
		end
	end
	return best
end

local function assign(player: Player)
	if assigned[player] or assigning[player] then
		return
	end
	assigning[player] = true
	if Features.friendPlacement then
		FriendService.refresh(player, FRIEND_LOOKUP_SECONDS) -- yields; the faction is chosen after this
	end
	assigning[player] = nil
	if player.Parent ~= Players or assigned[player] then
		return
	end

	-- No yielding from here until the faction is stored, so two joiners cannot be counted at the same time.
	local id = FactionRules.pickFaction(counts(), if Features.friendPlacement then friendsFaction(player) else nil, Config.squad.friendTolerance)
	assigned[player] = id
	player:SetAttribute("Faction", id)
	local team = Teams:FindFirstChild(FactionRules.factions[id].name)
	if team and team:IsA("Team") then
		player.Team = team
	end
	player.CharacterAdded:Connect(function(character)
		outline(character, id)
		local humanoid = character:WaitForChild("Humanoid", 5)
		if humanoid and humanoid:IsA("Humanoid") then
			humanoid.Died:Connect(function()
				respawnLater(player)
			end)
		end
	end)
	player:LoadCharacter() -- the first spawn happens only once the faction is known
end

function FactionSystem.init()
	-- Characters are loaded by this system so that nobody spawns before their faction is chosen.
	Players.CharacterAutoLoads = false
	for _, faction in FactionRules.factions do
		local team = Instance.new("Team")
		team.Name = faction.name
		team.TeamColor = BrickColor.new(faction.brickColor)
		team.AutoAssignable = false
		team.Parent = Teams
	end
	Players.PlayerAdded:Connect(assign)
	Players.PlayerRemoving:Connect(function(player)
		assigned[player] = nil
		assigning[player] = nil
	end)
end

function FactionSystem.start()
	for _, player in Players:GetPlayers() do
		task.spawn(assign, player)
	end
end

return FactionSystem
