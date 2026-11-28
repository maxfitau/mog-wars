--!strict
-- DAILY AND WEEKLY QUESTS. 3 daily quests (reset 00:00 UTC) and 5 weekly quests (reset Monday 00:00 UTC), picked from
-- QuestCatalog so every server agrees. Progress is counted here on the server from the Events bus and saved in
-- data.questState (dailyDay, daily, weeklyWeek, weekly, claimed). A finished quest pays at once: an aura burst (seconds of
-- income, scaled by level inside DataService.addAura) and, for chest quests, a weapon rolled with the "quest" source.
-- The claimed table is set BEFORE paying, so a quest can never pay twice. There is no client request to claim: the client
-- cannot ask for anything. Mirrors the quests to the player attributes DailyQuests and WeeklyQuests ("id|progress|goal|claimed"
-- entries joined by ";") plus DailyResetAt and WeeklyResetAt (unix seconds) for the Quest Board. These are separate from the
-- 3 per-war mini-quests in QuestSystem, which are unchanged.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Pace = require(Shared:WaitForChild("Pace"))
local QuestCatalog = require(Shared:WaitForChild("QuestCatalog"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local PopupSystem = require(script.Parent:WaitForChild("PopupSystem"))
local Events = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("Events"))

local REFRESH_SECONDS = 5

local DailyQuestSystem = {}

type QuestState = { dailyDay: number, daily: { [string]: number }, weeklyWeek: number, weekly: { [string]: number }, claimed: { [string]: boolean } }

-- Start a new day or week when the clock has moved on. Old progress and claims are wiped, so nothing carries over.
local function rollOver(state: QuestState, today: number)
	local week = QuestCatalog.weekIndex(today)
	if state.dailyDay ~= today then
		state.dailyDay = today
		state.daily = {}
		for id in state.claimed do
			if string.sub(id, 1, 2) == "d_" then
				state.claimed[id] = nil
			end
		end
	end
	if state.weeklyWeek ~= week then
		state.weeklyWeek = week
		state.weekly = {}
		for id in state.claimed do
			if string.sub(id, 1, 2) == "w_" then
				state.claimed[id] = nil
			end
		end
	end
end

local function entriesOf(state: QuestState, templates: { QuestCatalog.Template }, store: { [string]: number }): { QuestCatalog.Entry }
	local entries: { QuestCatalog.Entry } = {}
	for _, template in templates do
		table.insert(entries, {
			id = template.id,
			progress = QuestCatalog.clamp(template, store[template.id] or 0),
			goal = template.goal,
			claimed = state.claimed[template.id] == true,
		})
	end
	return entries
end

local function publish(player: Player, state: QuestState)
	local today = state.dailyDay
	player:SetAttribute("DailyQuests", QuestCatalog.encode(entriesOf(state, QuestCatalog.dailyFor(today), state.daily)))
	player:SetAttribute("WeeklyQuests", QuestCatalog.encode(entriesOf(state, QuestCatalog.weeklyFor(state.weeklyWeek), state.weekly)))
	local now = os.time()
	player:SetAttribute("DailyResetAt", QuestCatalog.dailyResetAt(now))
	player:SetAttribute("WeeklyResetAt", QuestCatalog.weeklyResetAt(now))
end

local function stateOf(player: Player): QuestState?
	local data = DataService.get(player)
	if not data then
		return nil
	end
	local state = data.questState :: QuestState
	rollOver(state, QuestCatalog.dayNumber(os.time()))
	return state
end

-- Pay one finished quest. `claimed` is saved first so a second call can never pay again.
local function pay(player: Player, state: QuestState, template: QuestCatalog.Template, weekly: boolean)
	if state.claimed[template.id] then
		return
	end
	state.claimed[template.id] = true
	PopupSystem.send(player, "announce", 1, (if weekly then "WEEKLY QUEST DONE! " else "DAILY QUEST DONE! ") .. template.text)
	local shown = DataService.addAura(player, template.auraSeconds * Pace.levels.nominalIncome)
	if shown > 0 then
		PopupSystem.send(player, "aura", shown, "")
	end
	if template.chest then
		DataService.rollWeapon(player, "quest") -- the weapon reveal card is sent by DataService
	end
end

local function count(player: Player, kind: string, amount: number)
	local state = stateOf(player)
	if not state then
		return
	end
	local function bump(templates: { QuestCatalog.Template }, store: { [string]: number }, weekly: boolean)
		for _, template in templates do
			if QuestCatalog.counts(template, kind) and not state.claimed[template.id] then
				local progress = QuestCatalog.clamp(template, (store[template.id] or 0) + amount)
				store[template.id] = progress
				if QuestCatalog.isComplete(template, progress) then
					pay(player, state, template, weekly)
				end
			end
		end
	end
	bump(QuestCatalog.dailyFor(state.dailyDay), state.daily, false)
	bump(QuestCatalog.weeklyFor(state.weeklyWeek), state.weekly, true)
	publish(player, state)
end

local function onEvent(player: Player, kind: string, _value: number)
	if type(kind) ~= "string" or #kind > 24 then
		return
	end
	count(player, kind, 1) -- each event is one step toward a quest, whatever its value
	if kind == "war" then
		-- WarSystem sets WarWinner just after it fires "war", so look a moment later
		task.delay(1, function()
			if player.Parent ~= Players then
				return
			end
			local winner = Workspace:GetAttribute("WarWinner")
			local faction = player:GetAttribute("Faction")
			if type(winner) == "number" and winner ~= 0 and winner == faction then
				count(player, "war_win", 1)
			end
		end)
	end
end

function DailyQuestSystem.init()
	Events.on(onEvent)
end

function DailyQuestSystem.start()
	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				local state = stateOf(player)
				if state then
					publish(player, state)
				end
			end
			task.wait(REFRESH_SECONDS)
		end
	end)
end

return DailyQuestSystem
