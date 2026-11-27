--!strict
-- The aura trickle. While a faction holds a whole territory, every member of that faction gets a small amount
-- of aura every minute (more for harder territories: Gold 10, Diamond 20, Ultra 50). Real players only; bots
-- earn nothing. Only during a war, and only for players on War Island. The amounts live in Territories.luau.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Territories = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Territories"))
local CaptureSystem = require(script.Parent:WaitForChild("CaptureSystem"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local PopupSystem = require(script.Parent:WaitForChild("PopupSystem"))

local TerritorySystem = {}

local function trickle()
	if Workspace:GetAttribute("WarPhase") ~= "War" then
		return
	end
	-- add up what each faction earns from every territory it holds
	local perFaction: { [number]: number } = {}
	for _, territory in CaptureSystem.territoryList() do
		if territory.owner ~= 0 then
			local tier = Territories.tiers[territory.tier]
			perFaction[territory.owner] = (perFaction[territory.owner] or 0) + tier.trickle
		end
	end
	for _, player in Players:GetPlayers() do
		local faction = player:GetAttribute("Faction")
		local amount = if type(faction) == "number" then perFaction[faction] else nil
		if amount and player:GetAttribute("Island") ~= "training" then
			local granted = DataService.addAura(player, amount)
			if granted > 0 then
				PopupSystem.send(player, "aura", granted, "")
			end
		end
	end
end

function TerritorySystem.init() end

function TerritorySystem.start()
	task.spawn(function()
		while true do
			task.wait(Territories.trickleSeconds)
			local ok, err = pcall(trickle)
			if not ok then
				warn("[mog-wars] aura trickle error: " .. tostring(err))
			end
		end
	end)
end

return TerritorySystem
