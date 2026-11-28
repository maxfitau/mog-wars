--!strict
-- THE WEEKLY EVENT: METEOR STORM SATURDAY (schedule and length: src/shared/EventSchedule.luau, all UTC).
-- While it is live: everybody earns 2x aura (Workspace attribute EventAuraMultiplier, which DataService already applies) and a
-- meteor falls every 90 seconds (EventSystem storm meteors, they do not need a war). Every real player who captures a flag or helps
-- claim a meteor during the event gets ONE weekly reward: an aura burst and a free "weekly" weapon chest roll.
-- Attributes for the HUD (always set, so the countdown works all week): WeeklyEventName, WeeklyEventLive, WeeklyEventEndsAt,
-- WeeklyEventNextAt (unix seconds, UTC). The server decides everything; the client (EventCountdown) only displays.
-- Studio debug commands (wired by the integrator): WeeklyEventSystem.forceStart(minutes) and WeeklyEventSystem.forceStop().

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EventSchedule = require(Shared:WaitForChild("EventSchedule"))
local Pace = require(Shared:WaitForChild("Pace"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local PopupSystem = require(script.Parent:WaitForChild("PopupSystem"))
local EventSystem = require(script.Parent:WaitForChild("EventSystem"))

local WeeklyEventSystem = {}

local SETTINGS = {
	auraMultiplier = 2, -- everybody's aura, while the event is live
	meteorEverySeconds = 90,
	firstMeteorAfterSeconds = 20, -- the first meteor falls this long after the start
	retrySeconds = 5, -- a meteor that could not start (one is still falling) tries again soon
	noMeteorLastSeconds = 60, -- no new meteor in the last minute of the event
	rewardAuraSeconds = 180, -- the aura burst: this many seconds of nominal income (scaled by level in DataService)
	rewardRoll = "weekly", -- the WeaponCatalog.odds source for the free chest
}

local live = false
local eventId = 0 -- the unix start of the running event (also the key that makes the reward once per event)
local endsAt = 0
local nextMeteorAt = 0
local forcedStart = 0
local forcedEnd = 0 -- unix seconds; 0 = no forced event
local suppressedStart = -1 -- a scheduled window that forceStop ended early (so it does not start again)

local baseline: { [Player]: number } = {} -- lifetimeCaptures when we first saw the player during this event
local taken: { [number]: boolean } = {} -- userIds already rewarded in THIS server for this event
local memoryStore: { [string]: boolean } = {} -- Studio has no DataStore access: remember in memory instead

local store: DataStore? = nil

local function banner(text: string)
	for _, player in Players:GetPlayers() do
		PopupSystem.send(player, "announce", 1, text)
	end
end

local function publish(isLive: boolean, endUnix: number, nextUnix: number)
	Workspace:SetAttribute("WeeklyEventName", EventSchedule.settings.name)
	Workspace:SetAttribute("WeeklyEventLive", isLive)
	Workspace:SetAttribute("WeeklyEventEndsAt", endUnix)
	Workspace:SetAttribute("WeeklyEventNextAt", nextUnix)
end

-- Once per player per event, across every server: a DataStore key per (event, player). Fails soft: when the store cannot be
-- reached the player still gets the reward (once in this server).
local function claimOnce(player: Player): boolean
	local key = ("weekly_%d_%d"):format(eventId, player.UserId)
	if taken[player.UserId] then
		return false
	end
	taken[player.UserId] = true
	local active = store
	if RunService:IsStudio() or active == nil then
		if memoryStore[key] then
			return false
		end
		memoryStore[key] = true
		return true
	end
	local checked: DataStore = active
	local first = true
	local ok, err = pcall(function()
		checked:UpdateAsync(key, function(old: any)
			if old == true then
				first = false
				return nil -- already rewarded in another server: change nothing
			end
			first = true
			return true
		end)
	end)
	if not ok then
		warn("[mog-wars] weekly reward store failed (rewarding anyway): " .. tostring(err))
		return true
	end
	return first
end

local function reward(player: Player)
	if not live or player.Parent ~= Players then
		return
	end
	if not claimOnce(player) then
		return
	end
	local shown = DataService.addAura(player, SETTINGS.rewardAuraSeconds * Pace.levels.nominalIncome, false, true, true)
	if shown > 0 then
		PopupSystem.send(player, "aura", shown, "")
	end
	DataService.rollWeapon(player, SETTINGS.rewardRoll)
	PopupSystem.send(player, "announce", 1, "Meteor Storm reward: free weapon chest!")
end

-- Players who took part: flag captures are seen as a rise in lifetimeCaptures; meteor claims come from EventSystem.onClaim.
local function checkParticipation()
	for _, player in Players:GetPlayers() do
		local data = DataService.get(player)
		if data then
			local seen = baseline[player]
			if seen == nil then
				baseline[player] = data.lifetimeCaptures
			elseif data.lifetimeCaptures > seen then
				baseline[player] = data.lifetimeCaptures
				reward(player)
			end
		end
	end
end

local function begin(startUnix: number, finishUnix: number)
	live = true
	eventId = startUnix
	endsAt = finishUnix
	nextMeteorAt = os.time() + SETTINGS.firstMeteorAfterSeconds
	baseline = {}
	taken = {}
	Workspace:SetAttribute("EventAuraMultiplier", SETTINGS.auraMultiplier)
	banner(("%s! 2x aura and meteors all event!"):format(EventSchedule.settings.name))
	Sounds.playAt(Workspace.Terrain, "event_start")
end

local function finish()
	live = false
	Workspace:SetAttribute("EventAuraMultiplier", 1)
	banner(("%s is over. See you next %s!"):format(EventSchedule.settings.name, EventSchedule.eventDayName()))
	Sounds.playAt(Workspace.Terrain, "event_start")
end

-- Start the storm now for `minutes` (Studio debug). Meteors begin about 20 seconds in.
function WeeklyEventSystem.forceStart(minutes: number?)
	local length = math.clamp(if type(minutes) == "number" then minutes else 10, 1, 180)
	local now = os.time()
	forcedStart = now
	forcedEnd = now + math.floor(length * 60)
	suppressedStart = -1
end

-- End the storm now (Studio debug), whether it was forced or on schedule.
function WeeklyEventSystem.forceStop()
	forcedEnd = 0
	local scheduled = EventSchedule.currentStart(os.time())
	if scheduled then
		suppressedStart = scheduled
	end
end

function WeeklyEventSystem.isLive(): boolean
	return live
end

local function step()
	local now = os.time()
	local startUnix: number? = nil
	local finishUnix = 0
	if forcedEnd > now then
		startUnix, finishUnix = forcedStart, forcedEnd
	else
		forcedEnd = 0
		local scheduled = EventSchedule.currentStart(now)
		if scheduled and scheduled ~= suppressedStart then
			startUnix, finishUnix = scheduled, EventSchedule.endsAt(now) or 0
		end
	end

	if startUnix and not live then
		begin(startUnix, finishUnix)
	elseif not startUnix and live then
		finish()
	end

	local nextAt = EventSchedule.nextStart(now)
	publish(live, if live then finishUnix else 0, nextAt)
	if not live then
		return
	end
	endsAt = finishUnix

	checkParticipation()
	if now >= nextMeteorAt and endsAt - now > SETTINGS.noMeteorLastSeconds then
		if EventSystem.trigger("meteor", true) then
			nextMeteorAt = now + SETTINGS.meteorEverySeconds
		else
			nextMeteorAt = now + SETTINGS.retrySeconds
		end
	end
end

function WeeklyEventSystem.init()
	if not RunService:IsStudio() then
		local ok, result = pcall(function()
			return DataStoreService:GetDataStore("MogWeekly")
		end)
		if ok then
			store = result
		end
	end
	publish(false, 0, EventSchedule.nextStart(os.time()))
	Workspace:SetAttribute("EventAuraMultiplier", 1)
end

function WeeklyEventSystem.start()
	EventSystem.onClaim = function(_faction: number, claimers: { Player })
		for _, player in claimers do
			reward(player)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		baseline[player] = nil
	end)
	task.spawn(function()
		while true do
			local ok, err = pcall(step)
			if not ok then
				warn("[mog-wars] WeeklyEventSystem step failed: " .. tostring(err))
			end
			task.wait(1)
		end
	end)
end

return WeeklyEventSystem
