--!strict
-- MINI-QUESTS. Each war gives every player 3 short quests ("Shove 5 Moglings 0/5", "Capture 2 flags", "Find a stash"...).
-- Finishing one pays an aura burst and is replaced by a new one. The panel under the aura box reads the attributes
-- Quest1..Quest3 ("text|progress|goal") and QuestFlash ("slot:count") for the tick animation. Server only; the pool and the
-- rewards are in Pace.quests.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Pace = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Pace"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local PopupSystem = require(script.Parent:WaitForChild("PopupSystem"))
local Events = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("Events"))

local QuestSystem = {}

type Quest = { def: any, progress: number }

local quests: { [Player]: { Quest } } = {}
local flashCount: { [Player]: number } = {}
local rng = Random.new()

local function textOf(def: any): string
	return if string.find(def.text, "%%d") then string.format(def.text, def.goal) else def.text
end

local function publish(player: Player)
	local list = quests[player]
	if not list then
		return
	end
	for slot = 1, Pace.quests.perWar do
		local quest = list[slot]
		player:SetAttribute("Quest" .. slot, if quest then ("%s|%d|%d"):format(textOf(quest.def), quest.progress, quest.def.goal) else "")
	end
end

local function pick(held: { Quest }): any
	for _ = 1, 20 do
		local def = Pace.quests.pool[rng:NextInteger(1, #Pace.quests.pool)]
		local clash = false
		for _, quest in held do
			if quest.def.id == def.id then
				clash = true
			end
		end
		if not clash then
			return def
		end
	end
	return Pace.quests.pool[1]
end

-- New quests for everyone: called at the start of every war (and when someone joins).
function QuestSystem.assign(player: Player)
	local list: { Quest } = {}
	for _ = 1, Pace.quests.perWar do
		table.insert(list, { def = pick(list), progress = 0 })
	end
	quests[player] = list
	publish(player)
end

function QuestSystem.assignAll()
	for _, player in Players:GetPlayers() do
		QuestSystem.assign(player)
	end
end

local function onEvent(player: Player, kind: string, value: number)
	local list = quests[player]
	if not list then
		return
	end
	for slot, quest in list do
		if quest.def.kind == kind then
			quest.progress = math.min(quest.def.goal, quest.progress + value)
			if quest.progress >= quest.def.goal then
				-- done: tick, aura burst, and a new quest takes the slot
				flashCount[player] = (flashCount[player] or 0) + 1
				player:SetAttribute("QuestFlash", ("%d:%d"):format(slot, flashCount[player]))
				PopupSystem.send(player, "announce", 1, "QUEST DONE! " .. textOf(quest.def))
				local shown = DataService.addAura(player, quest.def.reward)
				if shown > 0 then
					PopupSystem.send(player, "aura", shown, "")
				end
				Events.fire(player, "quest", 1)
				list[slot] = { def = pick(list), progress = 0 }
			end
			publish(player)
		end
	end
end

function QuestSystem.init()
	Events.on(onEvent)
	Players.PlayerAdded:Connect(function(player)
		task.delay(3, function()
			if player.Parent == Players and not quests[player] then
				QuestSystem.assign(player)
			end
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		quests[player] = nil
		flashCount[player] = nil
	end)
end

function QuestSystem.start()
	for _, player in Players:GetPlayers() do
		QuestSystem.assign(player)
	end
end

return QuestSystem
