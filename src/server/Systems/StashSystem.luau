--!strict
-- The free Aura Stash hidden in each territory's secret spot: open it for a little aura (Pace.stash), once a minute per
-- player. Server only: the server checks the distance and the cooldown.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Pace = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Pace"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local PopupSystem = require(script.Parent:WaitForChild("PopupSystem"))

local StashSystem = {}

local lastOpened: { [Player]: { [Instance]: number } } = {}

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
		if not root or not root:IsA("BasePart") or (root.Position - stash.Position).Magnitude > 16 then
			return
		end
		local now = Workspace:GetServerTimeNow()
		local mine = lastOpened[player] or {}
		lastOpened[player] = mine
		if now - (mine[stash] or -1000) < Pace.stash.cooldownSeconds then
			return
		end
		mine[stash] = now
		local shown = DataService.addAura(player, Pace.stash.aura)
		if shown > 0 then
			PopupSystem.send(player, "aura", shown, "")
		end
	end)
end

function StashSystem.init()
	Players.PlayerRemoving:Connect(function(player)
		lastOpened[player] = nil
	end)
end

function StashSystem.start()
	for _, stash in CollectionService:GetTagged("AuraStash") do
		bind(stash)
	end
	CollectionService:GetInstanceAddedSignal("AuraStash"):Connect(bind)
end

return StashSystem
