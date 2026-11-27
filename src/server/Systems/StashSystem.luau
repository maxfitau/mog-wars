--!strict
-- The 12 hidden Aura Stashes. Open one for a big +100 burst of aura, once per war per player. The first time ever a
-- stash is opened it counts toward "Stashes found n/12" (saved); finding all 12 earns the Stash Hunter title. Server only:
-- the server checks the distance and that you have not opened this stash yet this war.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Pace = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Pace"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local PopupSystem = require(script.Parent:WaitForChild("PopupSystem"))
local Events = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("Events"))
local Stats = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("Stats"))

local StashSystem = {}

local openedInWar: { [Player]: { [string]: number } } = {}

local function bind(stash: Instance)
	if not stash:IsA("BasePart") then
		return
	end
	local prompt = stash:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		return
	end
	prompt.Triggered:Connect(function(player: Player)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") or (root.Position - stash.Position).Magnitude > 18 then
			return
		end
		local stashId = stash:GetAttribute("StashId")
		if type(stashId) ~= "string" then
			return
		end
		local war = Workspace:GetAttribute("WarNumber")
		local currentWar = if type(war) == "number" then war else 0
		local mine = openedInWar[player] or {}
		openedInWar[player] = mine
		if mine[stashId] == currentWar then
			return -- already opened this war
		end
		mine[stashId] = currentWar
		local shown = DataService.addAura(player, Pace.stash.aura)
		if shown > 0 then
			Stats.add(player, "aura", shown)
			PopupSystem.send(player, "aura", shown, "")
		end
		Events.fire(player, "stash", 1)
		local isNew, found = DataService.recordStash(player, stashId)
		if isNew then
			Events.fire(player, "stashCount", found)
			PopupSystem.send(player, "announce", 1, if found >= 12 then "STASH HUNTER! ALL 12 FOUND!" else ("STASH FOUND %d/12!"):format(found))
		end
	end)
end

function StashSystem.init()
	Players.PlayerRemoving:Connect(function(player)
		openedInWar[player] = nil
	end)
end

function StashSystem.start()
	for _, stash in CollectionService:GetTagged("AuraStash") do
		bind(stash)
	end
	CollectionService:GetInstanceAddedSignal("AuraStash"):Connect(bind)
end

return StashSystem
