--!strict
-- Slice 11: the daily box (7-day streak) and barracks income. Server clock only (UTC).
-- Requests carry NO data: "ClaimDailyRequest" and "CollectBarracksRequest". Each is rate limited, then
-- DataService does the check and the change as one step, or nothing. Double claims are impossible: the
-- claim day is saved with the box in the same step. Results go back as "RewardsResult".
-- DAY 7 of the streak also gives a GUARANTEED RARE weapon (DataService.rollWeapon with the "streak" source, whose odds are
-- 100% Rare). It is free only, never sold. It is rolled only when claimDaily said ok, so it can never be given twice for a day.
-- A timer refreshes the DailyReady, DailyDay and BarracksPending attributes the screen displays.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local DataService = require(script.Parent:WaitForChild("DataService"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("EconomyConfig"))

local MIN_INTERVAL = 0.5 -- seconds between requests from one player
local REFRESH_SECONDS = 10

local RewardsSystem = {}
local lastRequest: { [Player]: number } = {}

function RewardsSystem.init()
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	local claim = Instance.new("RemoteEvent")
	claim.Name = "ClaimDailyRequest"
	claim.Parent = folder
	local collect = Instance.new("RemoteEvent")
	collect.Name = "CollectBarracksRequest"
	collect.Parent = folder
	local result = Instance.new("RemoteEvent")
	result.Name = "RewardsResult"
	result.Parent = folder

	local function throttled(player: Player): boolean
		local now = Workspace:GetServerTimeNow()
		if now - (lastRequest[player] or -1000) < MIN_INTERVAL then
			return true
		end
		lastRequest[player] = now
		return false
	end

	claim.OnServerEvent:Connect(function(player: Player)
		if throttled(player) then
			return
		end
		local ok, reason, tier, day = DataService.claimDaily(player)
		local prize = ""
		if ok and day == #Config.dailyStreak.auraRewards then
			local weaponId = DataService.rollWeapon(player, "streak") -- a guaranteed Rare
			prize = weaponId or ""
		end
		result:FireClient(player, ok, reason, "daily", tier, day, prize)
	end)
	collect.OnServerEvent:Connect(function(player: Player)
		if throttled(player) then
			return
		end
		local ok, reason, amount = DataService.collectBarracks(player)
		result:FireClient(player, ok, reason, "barracks", "", amount)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

function RewardsSystem.start()
	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				DataService.syncRewards(player)
			end
			task.wait(REFRESH_SECONDS)
		end
	end)
end

return RewardsSystem
