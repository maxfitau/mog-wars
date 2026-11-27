--!strict
-- Weekly faction seasons. A season is one UTC week (Monday to Sunday).
--  * Players earn season points for their faction from captures, war wins and mog-off wins.
--  * Each server adds its new points to the shared faction totals (SeasonStore) every few seconds and reads
--    the totals back to show standings. Standings show FACTIONS only, never individual players.
--  * After a week ends, a player who earned enough points for the faction that won gets the cosmetic
--    "Season Champion" title, once. It is only a title: no points, boxes, units or aura (design rule 1).
-- Season points are counted only here and in DataService; clients just display the Workspace attributes
-- SeasonWeek, SeasonEndsAt, SeasonScore1..4 and the player's SeasonPoints.
-- Replies for the end of a season go to the client as "SeasonResult" (kind, week, winnerFaction).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("EconomyConfig"))
local FactionRules = require(Shared:WaitForChild("FactionRules"))
local SeasonRules = require(Shared:WaitForChild("SeasonRules"))
local SeasonStore = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("SeasonStore"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local Features = require(Shared:WaitForChild("Features"))

local CHAMPION_TITLE = "title_season_champion"

local SeasonService = {}

local pending: { [number]: { [number]: number } } = {} -- week, then faction, to points not yet added to the shared totals
local lastStandings: { [number]: number } = {}
local checking: { [Player]: boolean } = {}
local resultRemote: RemoteEvent? = nil

local function currentWeek(): number
	return SeasonRules.weekIndex(os.time())
end

-- Record season points for a player. kind is "capture" (value = zone value), "warWin" or "mogOffWin".
function SeasonService.earn(player: Player, kind: string, value: number)
	if not Features.seasons then
		return -- switched off at launch
	end
	local faction = player:GetAttribute("Faction")
	local points = SeasonRules.pointsFor(kind, value, Config.season)
	if type(faction) ~= "number" or points <= 0 then
		return
	end
	local week = currentWeek()
	if DataService.addSeasonPoints(player, faction, points, week) then
		pending[week] = pending[week] or {}
		pending[week][faction] = (pending[week][faction] or 0) + points
	end
end

-- Send this server's new points to the shared totals. Anything that fails stays pending and is retried.
local function flush()
	for week, byFaction in pending do
		for faction, amount in byFaction do
			if amount > 0 and SeasonStore.add(week, faction, amount) then
				byFaction[faction] = 0
			end
		end
	end
end

local function publish(week: number)
	Workspace:SetAttribute("SeasonWeek", week)
	Workspace:SetAttribute("SeasonEndsAt", SeasonRules.weekEnds(week))
	local unsent = pending[week] or {}
	for faction = 1, FactionRules.count() do
		-- show the shared total plus this server's points that are not added yet
		Workspace:SetAttribute("SeasonScore" .. faction, (lastStandings[faction] or 0) + (unsent[faction] or 0))
	end
end

local function refreshStandings(week: number)
	local standings = SeasonStore.standings(week)
	if standings then
		lastStandings = standings
	end
	publish(week)
end

-- Resolve last week's champion reward for one player, if there is one waiting.
local function checkReward(player: Player)
	if checking[player] then
		return
	end
	local week = currentWeek()
	local season = DataService.rollSeason(player, week)
	if not season or not SeasonRules.hasUnresolvedReward(season) then
		return
	end
	checking[player] = true
	local prevWeek = season.prevWeek
	local standings = SeasonStore.standings(prevWeek) -- may yield
	checking[player] = nil
	if not standings or player.Parent ~= Players then
		return -- unavailable right now; it is tried again next time
	end
	local latest = DataService.get(player)
	if not latest or latest.season.prevWeek ~= prevWeek or latest.season.claimed >= prevWeek then
		return
	end
	local winner = SeasonRules.winner(standings)
	local earned = SeasonRules.eligible(latest.season :: any, winner, Config.season)
	if earned then
		DataService.grantCosmetic(player, CHAMPION_TITLE)
	end
	DataService.markSeasonClaimed(player)
	if winner ~= 0 and resultRemote then
		resultRemote:FireClient(player, if earned then "champion" else "missed", prevWeek, winner)
	end
end

function SeasonService.init()
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	local result = Instance.new("RemoteEvent")
	result.Name = "SeasonResult"
	result.Parent = folder
	resultRemote = result
	Players.PlayerRemoving:Connect(function(player)
		checking[player] = nil
	end)
end

function SeasonService.start()
	if not Features.seasons then
		return -- no season loops, no shared totals and no panel while seasons are switched off
	end
	publish(currentWeek())
	task.spawn(function()
		while true do
			task.wait(Config.season.flushSeconds)
			flush()
		end
	end)
	task.spawn(function()
		while true do
			local week = currentWeek()
			refreshStandings(week)
			for _, player in Players:GetPlayers() do
				task.spawn(checkReward, player)
			end
			task.wait(Config.season.refreshSeconds)
		end
	end)
end

return SeasonService
