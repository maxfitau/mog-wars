--!strict
-- The constant "+X" counter and the announcer. Every second of a war, every player on a team earns aura just for being
-- there (+1), +3 instead while standing on a flag their team is capturing or defending, plus +1 for every territory
-- their team holds. The last minute is double (DataService.auraMultiplier). Pop-ups are small and sit by the aura counter.
-- The same loop announces who is capturing what, and the territory takeovers ("YOUR TEAM took Gigachad Gate!").
-- Server only; the numbers come from Pace.presence.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FactionRules = require(Shared:WaitForChild("FactionRules"))
local Pace = require(Shared:WaitForChild("Pace"))
local CaptureSystem = require(script.Parent:WaitForChild("CaptureSystem"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local PopupSystem = require(script.Parent:WaitForChild("PopupSystem"))
local Stats = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("Stats"))

local PresenceSystem = {}

local lastCapturer: { [Instance]: number } = {}
local lastAnnounced: { [Instance]: number } = {}

local function teamName(id: number): string
	local info = FactionRules.byId(id)
	return if info then string.upper(info.name) else "A TEAM"
end

local function broadcast(text: string)
	for _, player in Players:GetPlayers() do
		PopupSystem.send(player, "announce", 1, text)
	end
end

local function tick()
	local war = Workspace:GetAttribute("WarPhase") == "War"
	if not war then
		return
	end
	-- who owns what: territories held per team
	local held: { [number]: number } = {}
	for _, territory in CaptureSystem.territoryList() do
		if territory.owner ~= 0 then
			held[territory.owner] = (held[territory.owner] or 0) + 1
		end
	end
	for _, player in Players:GetPlayers() do
		local faction = player:GetAttribute("Faction")
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if type(faction) == "number" and humanoid and humanoid.Health > 0 then
			local amount = Pace.presence.base
			local zone = CaptureSystem.zoneAt(player)
			if zone and (zone:GetAttribute("OwnerFaction") == faction or zone:GetAttribute("CapturerFaction") == faction) then
				amount = Pace.presence.onFlag
			end
			amount += (held[faction] or 0) * Pace.presence.perTerritory
			local shown = DataService.addAura(player, amount)
			if shown > 0 then
				Stats.add(player, "aura", shown)
				PopupSystem.send(player, "aura", shown, "")
			end
		end
	end
	-- announcer: a team starts capturing a flag
	local now = Workspace:GetServerTimeNow()
	for _, zone in CollectionService:GetTagged("Zone") do
		local capturer = zone:GetAttribute("CapturerFaction")
		local progress = zone:GetAttribute("Progress")
		if type(capturer) == "number" and capturer ~= 0 and type(progress) == "number" and progress > 0.08 and capturer ~= lastCapturer[zone] then
			if now - (lastAnnounced[zone] or -100) > 20 then
				lastAnnounced[zone] = now
				broadcast(("%s is capturing %s!"):format(teamName(capturer), tostring(zone:GetAttribute("TerritoryName") or "a flag")))
			end
		end
		lastCapturer[zone] = if type(capturer) == "number" then capturer else 0
	end
end

function PresenceSystem.init()
	CaptureSystem.onTerritoryCaptured = function(name: string, winner: number)
		for _, player in Players:GetPlayers() do
			local mine = player:GetAttribute("Faction") == winner
			PopupSystem.send(player, "announce", 1, if mine then ("YOUR TEAM took %s!"):format(name) else ("%s took %s!"):format(teamName(winner), name))
		end
	end
end

function PresenceSystem.start()
	task.spawn(function()
		while true do
			task.wait(1)
			local ok, err = pcall(tick)
			if not ok then
				warn("[mog-wars] PresenceSystem error: " .. tostring(err))
			end
		end
	end)
end

return PresenceSystem
