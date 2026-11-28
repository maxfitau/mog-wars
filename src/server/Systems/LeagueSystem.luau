--!strict
-- THE TEAM LEAGUE: every war a team wins is one point for that team this week (weeks start Monday 00:00 UTC, rules in
-- src/shared/LeagueRules.luau). The tally is shared by every server through a DataStore ("MogLeague", one key per week, saved with
-- UpdateAsync inside pcall). In Studio there is no DataStore access, so a memory table stands in. Everything fails soft: a store
-- error only means the standings update later. After Monday 00:00 UTC, the real players of last week's winning team each get the
-- title "League Champion" and a chest (a free weapon roll and an aura burst), once (data.leagueClaimedWeek).
-- Workspace attributes for the HUD: LeagueWeek, League1..League4 (wars won this week per team), LeagueLastWinner (team id, 0 = none).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FactionRules = require(Shared:WaitForChild("FactionRules"))
local LeagueRules = require(Shared:WaitForChild("LeagueRules"))
local Pace = require(Shared:WaitForChild("Pace"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local PopupSystem = require(script.Parent:WaitForChild("PopupSystem"))

local LeagueSystem = {}

local SETTINGS = {
	title = "League Champion", -- the banner title (24 letters at most)
	rewardAuraSeconds = 240, -- the chest's aura burst: seconds of nominal income (scaled by level in DataService)
	rewardRoll = "weekly", -- the WeaponCatalog.odds source for the chest's weapon
	refreshSeconds = 60, -- how often to read the shared standings and flush pending wins
	claimCheckSeconds = 5, -- how often to look for players who can claim last week's chest
}

type Pending = { week: number, team: number }

local teamCount = FactionRules.count()
local store: DataStore? = nil
local memoryStore: { [string]: any } = {} -- Studio: no DataStore access

local currentWeek = 0
local stored: LeagueRules.Tally = LeagueRules.newTally(teamCount) -- this week as last read from the store
local pending: { Pending } = {} -- wins not yet saved (the store was busy or down)
local lastWinner = 0 -- the winning team of the PREVIOUS week (0 = none)
local lastWinnerKnown = false -- false until the previous week's tally has been read
local lastCountedWar = -1

local function keyFor(week: number): string
	return "week_" .. tostring(week)
end

-- Read a week's tally from the store. Returns nil when the store could not be read.
local function readWeek(week: number): LeagueRules.Tally?
	local key = keyFor(week)
	local current = store
	if RunService:IsStudio() or current == nil then
		return LeagueRules.sanitize(memoryStore[key], teamCount)
	end
	local active: DataStore = current
	local ok, result = pcall(function()
		return active:GetAsync(key)
	end)
	if not ok then
		warn("[mog-wars] league read failed: " .. tostring(result))
		return nil
	end
	return LeagueRules.sanitize(result, teamCount)
end

-- Add one win to a week's saved tally (atomic across servers). Returns the saved tally, or nil on failure.
local function saveWin(week: number, team: number): LeagueRules.Tally?
	local key = keyFor(week)
	local current = store
	if RunService:IsStudio() or current == nil then
		local tally = LeagueRules.sanitize(memoryStore[key], teamCount)
		LeagueRules.addWin(tally, team)
		memoryStore[key] = tally
		return LeagueRules.copy(tally)
	end
	local active: DataStore = current
	local saved: LeagueRules.Tally? = nil
	local ok, err = pcall(function()
		active:UpdateAsync(key, function(old: any)
			local tally = LeagueRules.sanitize(old, teamCount)
			LeagueRules.addWin(tally, team)
			saved = tally
			return tally
		end)
	end)
	if not ok then
		warn("[mog-wars] league save failed (will retry): " .. tostring(err))
		return nil
	end
	return saved
end

-- What the HUD shows: the saved tally plus any wins this server has not managed to save yet.
local function displayTally(): LeagueRules.Tally
	local shown = LeagueRules.copy(stored)
	for _, win in pending do
		if win.week == currentWeek then
			LeagueRules.addWin(shown, win.team)
		end
	end
	return shown
end

local function mirror()
	local shown = displayTally()
	Workspace:SetAttribute("LeagueWeek", currentWeek)
	for team = 1, teamCount do
		Workspace:SetAttribute("League" .. team, shown.wins[team] or 0)
	end
	Workspace:SetAttribute("LeagueLastWinner", lastWinner)
end

local flushing = false -- one flush at a time, so a win is never saved twice

local function flushPending()
	if flushing then
		return
	end
	flushing = true
	local index = 1
	while index <= #pending do
		local win = pending[index]
		local saved = saveWin(win.week, win.team)
		if saved then
			table.remove(pending, index)
			if win.week == currentWeek then
				stored = saved
			end
		else
			index += 1
			if index > 3 then
				break -- the store is struggling: try the rest next time
			end
		end
	end
	flushing = false
end

local function refresh()
	local week = LeagueRules.weekIndex(os.time())
	local rolled = week ~= currentWeek
	if rolled then
		-- save what the old week still owes before moving on
		flushPending()
		currentWeek = week
		stored = LeagueRules.newTally(teamCount)
		lastWinnerKnown = false
	end
	flushPending()
	local now = readWeek(week)
	if now then
		stored = now
	end
	if not lastWinnerKnown then
		local previous = readWeek(week - 1)
		if previous then
			-- wins that were still pending for last week count too
			for _, win in pending do
				if win.week == week - 1 then
					LeagueRules.addWin(previous, win.team)
				end
			end
			lastWinner = LeagueRules.winner(previous)
			lastWinnerKnown = true
			if rolled and lastWinner ~= 0 then
				local info = FactionRules.factions[lastWinner]
				for _, player in Players:GetPlayers() do
					PopupSystem.send(player, "announce", 1, info.name .. " won last week's League!")
				end
			end
		end
	end
	mirror()
end

-- A war ended with this team winning: one point for the current week.
function LeagueSystem.addWin(team: number): boolean
	if type(team) ~= "number" or team < 1 or team > teamCount or team ~= math.floor(team) then
		return false
	end
	table.insert(pending, { week = currentWeek, team = team })
	mirror() -- show it at once
	task.spawn(function()
		local ok, err = pcall(flushPending)
		if not ok then
			warn("[mog-wars] league flush failed: " .. tostring(err))
		end
		mirror()
	end)
	return true
end

-- STUDIO DEBUG ONLY: pretend `team` won last week, so the Monday chest can be tested without waiting a week.
function LeagueSystem.debugSetLastWinner(team: number)
	if not RunService:IsStudio() or type(team) ~= "number" or team < 1 or team > teamCount then
		return
	end
	lastWinner = math.floor(team)
	lastWinnerKnown = true
	mirror()
end

local function claimFor(player: Player)
	if not lastWinnerKnown or lastWinner == 0 then
		return
	end
	local week = currentWeek - 1
	local data = DataService.get(player)
	if not data or data.leagueClaimedWeek == week then
		return
	end
	if player:GetAttribute("Faction") ~= lastWinner then
		return
	end
	data.leagueClaimedWeek = week -- mark first: a second look can never pay twice
	DataService.setTitle(player, SETTINGS.title)
	local shown = DataService.addAura(player, SETTINGS.rewardAuraSeconds * Pace.levels.nominalIncome, false, true, true)
	if shown > 0 then
		PopupSystem.send(player, "aura", shown, "")
	end
	DataService.rollWeapon(player, SETTINGS.rewardRoll)
	local info = FactionRules.factions[lastWinner]
	PopupSystem.send(player, "announce", 1, ("LEAGUE CHAMPION! %s won the week - chest!"):format(info.name))
end

function LeagueSystem.init()
	if not RunService:IsStudio() then
		local ok, result = pcall(function()
			return DataStoreService:GetDataStore("MogLeague")
		end)
		if ok then
			store = result
		end
	end
	currentWeek = LeagueRules.weekIndex(os.time())
	for team = 1, teamCount do
		Workspace:SetAttribute("League" .. team, 0)
	end
	Workspace:SetAttribute("LeagueWeek", currentWeek)
	Workspace:SetAttribute("LeagueLastWinner", 0)
end

function LeagueSystem.start()
	-- each war end: WarSystem sets WarWinner (a team id, 0 = a draw) while WarNumber is still that war's number
	local function onWarWinner()
		local winner = Workspace:GetAttribute("WarWinner")
		local warNumber = Workspace:GetAttribute("WarNumber")
		if type(winner) == "number" and winner >= 1 and type(warNumber) == "number" and warNumber ~= lastCountedWar then
			lastCountedWar = warNumber
			LeagueSystem.addWin(winner)
		end
	end
	Workspace:GetAttributeChangedSignal("WarWinner"):Connect(onWarWinner)
	Workspace:GetAttributeChangedSignal("WarNumber"):Connect(onWarWinner)

	task.spawn(function()
		while true do
			local ok, err = pcall(refresh)
			if not ok then
				warn("[mog-wars] league refresh failed: " .. tostring(err))
			end
			task.wait(SETTINGS.refreshSeconds)
		end
	end)
	-- real players only: bots are never in Players
	task.spawn(function()
		while true do
			task.wait(SETTINGS.claimCheckSeconds)
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(claimFor, player)
				if not ok then
					warn("[mog-wars] league claim failed: " .. tostring(err))
				end
			end
		end
	end)
end

return LeagueSystem
