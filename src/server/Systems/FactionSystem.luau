--!strict
-- Slice 2: assigns every player to one of four factions, balanced by head count, and shows it with a Team,
-- a coloured outline on the character, and a "Faction" attribute that other systems read. Server only.
-- A player keeps their faction until they leave (no remote exists to change it). Rejoining reassigns.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FactionRules = require(Shared:WaitForChild("FactionRules"))

local assigned: { [Player]: number } = {}
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

local function assign(player: Player)
	if assigned[player] then
		return
	end
	local id = FactionRules.pickFaction(counts()) -- no yield between counting and storing
	assigned[player] = id
	player:SetAttribute("Faction", id)
	local team = Teams:FindFirstChild(FactionRules.factions[id].name)
	if team and team:IsA("Team") then
		player.Team = team
	end
	player.CharacterAdded:Connect(function(character)
		outline(character, id)
	end)
	if player.Character then
		outline(player.Character, id)
	end
end

function FactionSystem.init()
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
	end)
end

function FactionSystem.start()
	for _, player in Players:GetPlayers() do
		assign(player)
	end
end

return FactionSystem
