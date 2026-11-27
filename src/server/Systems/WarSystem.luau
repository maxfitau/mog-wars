--!strict
-- Runs the war cycle: Intermission, then War, forever. Server only. State is published as Workspace
-- attributes (WarPhase, WarPhaseEndsAt, WarNumber, WarWinner, Score1..Score4) for the HUD to display.
-- At the end of each war the bonuses are paid exactly once, then the map resets for the next war.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("EconomyConfig"))
local FactionRules = require(Shared:WaitForChild("FactionRules"))
local WarRules = require(Shared:WaitForChild("WarRules"))
local Pace = require(Shared:WaitForChild("Pace"))
local Stats = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("Stats"))
local BotService = require(script.Parent:WaitForChild("BotService"))
local CaptureSystem = require(script.Parent:WaitForChild("CaptureSystem"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local SeasonService = require(script.Parent:WaitForChild("SeasonService"))

local WarSystem = {}

local warNumber = 0
local resultsRemote: RemoteEvent? = nil
local phase = "Intermission"
local endsAt = 0

local function publishScores()
	local scores = WarRules.scores(CaptureSystem.zoneSummary())
	for id = 1, FactionRules.count() do
		Workspace:SetAttribute("Score" .. id, scores[id] or 0)
	end
end

local function setPhase(name: string)
	phase = name
	endsAt = Workspace:GetServerTimeNow() + WarRules.phaseSeconds(name, WarRules.clampWarSeconds(Config.war.durationSeconds), Config.war.intermissionSeconds)
	Workspace:SetAttribute("WarPhase", name)
	Workspace:SetAttribute("WarPhaseEndsAt", endsAt)
	Workspace:SetAttribute("WarNumber", warNumber)
end

-- Called once per war, when the timer ends. Never called twice for the same war.
local function finishWar()
	CaptureSystem.setActive(false)
	local scores = WarRules.scores(CaptureSystem.zoneSummary())
	local units, captures = CaptureSystem.warTallies()
	local winner = WarRules.winner(scores, captures)

	local results: { [number]: WarRules.PlayerResult } = {}
	for userId, amount in units do
		local player = Players:GetPlayerByUserId(userId)
		local faction = player and player:GetAttribute("Faction")
		if player and type(faction) == "number" then
			results[userId] = { faction = faction, units = amount }
		end
	end
	local bonuses = WarRules.bonuses(winner, results, {
		winnerBonus = Config.war.winnerBonusPoints,
		participantBonus = Config.war.participantBonusPoints,
		minUnits = Config.war.minContributionForBonus,
	})
	for userId, amount in bonuses do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			DataService.addPoints(player, WarRules.applyMultiplier(amount, DataService.rewardMultiplier(player)))
			DataService.recordWar(player) -- count it after paying, so the 9th war is the first reduced one
			local result = results[userId]
			if result and winner ~= 0 and result.faction == winner then
				SeasonService.earn(player, "warWin", 1)
			end
		end
	end

	Workspace:SetAttribute("WarWinner", winner)
	Workspace:SetAttribute("Overtime", false)
	publishScores()
	-- the 5-second results screen: your totals, and the MVP of every faction (real players only)
	local factionResults: { { mvp: string, mogs: number, flags: number, aura: number } } = {}
	for id = 1, FactionRules.count() do
		local entry = { mvp = "-", mogs = 0, flags = 0, aura = 0 }
		local bestScore = -1
		for _, player in Players:GetPlayers() do
			if player:GetAttribute("Faction") == id then
				local tally = Stats.get(player)
				entry.mogs += tally.mogs
				entry.flags += tally.flags
				entry.aura += tally.aura
				local score = tally.mogs * Pace.results.mvpPerMog + tally.flags * Pace.results.mvpPerFlag + tally.assists * Pace.results.mvpPerAssist
				if score > bestScore then
					bestScore = score
					entry.mvp = player.DisplayName
				end
			end
		end
		factionResults[id] = entry
	end
	if resultsRemote then
		for _, player in Players:GetPlayers() do
			local tally = Stats.get(player)
			resultsRemote:FireClient(player, factionResults, { aura = tally.aura, mogs = tally.mogs, assists = tally.assists, flags = tally.flags }, winner, Pace.results.seconds)
		end
	end
	local winnerFaction = FactionRules.byId(winner)
	print(("[mog-wars] war %d over. Winner: %s"):format(warNumber, if winnerFaction then winnerFaction.name else "draw"))
end

local function startWar()
	warNumber += 1
	Stats.reset()
	Workspace:SetAttribute("Overtime", false)
	CaptureSystem.resetWar()
	BotService.onWarStart()
	Workspace:SetAttribute("WarWinner", 0)
	publishScores()
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			if player:GetAttribute("Faction") == nil then
				return -- still being placed on a faction; they spawn when that finishes
			end
			if player:GetAttribute("Island") == "training" then
				return -- training is a side trip: a new war does not pull them out of it
			end
			player:LoadCharacter() -- back to the faction base for a fresh start
		end)
	end
	CaptureSystem.setActive(true)
	setPhase("War")
end

function WarSystem.init()
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	local remote = Instance.new("RemoteEvent")
	remote.Name = "WarResults"
	remote.Parent = folder
	resultsRemote = remote
end

function WarSystem.start()
	Workspace:SetAttribute("WarWinner", 0)
	CaptureSystem.setActive(false) -- no captures during the first intermission; the first war switches zones on
	setPhase("Intermission")
	task.spawn(function()
		while true do
			task.wait(0.5)
			if phase == "War" then
				publishScores()
				local overtime = endsAt - Workspace:GetServerTimeNow() <= Pace.overtime.seconds -- the last 60 seconds: all aura x2
				if Workspace:GetAttribute("Overtime") ~= overtime then
					Workspace:SetAttribute("Overtime", overtime)
				end
			end
			if Workspace:GetServerTimeNow() >= endsAt then
				if phase == "War" then
					finishWar()
					setPhase("Intermission")
				else
					startWar()
				end
			end
		end
	end)
end

return WarSystem
