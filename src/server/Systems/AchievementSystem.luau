--!strict
-- ACHIEVEMENTS: about 30 quick ones (src/shared/Achievements.luau), saved per player, some with titles. Watches the event bus
-- and bumps lifetime counters; when a counter reaches an achievement's goal, the achievement unlocks and the player gets a big
-- pop-up card ("AchievementUnlocked"). Server only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Achievements = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Achievements"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local Events = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("Events"))

local AchievementSystem = {}

local remote: RemoteEvent? = nil

local ADD = { -- event kind -> counter that goes up by the event's value
	flag = "flags", territory = "territories", shove_mogling = "shoves", shove_player = "shoves", zipline = "ziplines",
	launch = "launches", yeet = "yeets", bounty = "bounties", war = "wars", mega = "megas", ultra = "ultras", quest = "quests",
}
local RAISE = { -- event kind -> counter raised to at least the event's value
	rank = "rank", maxCombo = "maxCombo", stashCount = "stashFinds",
}

local function check(player: Player, counter: string, value: number)
	for index, achievement in Achievements do
		if achievement.counter == counter and value >= achievement.goal and DataService.unlockAchievement(player, achievement.id) then
			if achievement.title then
				DataService.setTitle(player, achievement.title)
			end
			if index % 5 == 0 then
				DataService.rollWeapon(player, "achievement") -- every 5th achievement also gives a free weapon
			end
			if remote then
				remote:FireClient(player, achievement.name, achievement.desc, achievement.title or "")
			end
		end
	end
end

function AchievementSystem.init()
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	local created = Instance.new("RemoteEvent")
	created.Name = "AchievementUnlocked"
	created.Parent = folder
	remote = created
	Events.on(function(player: Player, kind: string, value: number)
		local add = ADD[kind]
		if add then
			check(player, add, DataService.bumpCounter(player, add, value))
		end
		if kind == "steal" then -- value is the aura stolen
			check(player, "steals", DataService.bumpCounter(player, "steals", 1))
			check(player, "stolen", DataService.bumpCounter(player, "stolen", value))
		end
		local raise = RAISE[kind]
		if raise then
			check(player, raise, DataService.raiseCounter(player, raise, value))
		end
	end)
end

function AchievementSystem.start() end

return AchievementSystem
