--!strict
-- Loads each player's save when they join and releases it when they leave. Server only.
-- Other systems use DataService.get(player) and the helpers below; the client never sees the table.
-- The player's points are mirrored to a "Points" attribute so the HUD can display them (read only).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileStore = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("ProfileStore"))
local PlayerData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PlayerData"))

local store = nil :: ProfileStore.Store?
local profiles: { [Player]: ProfileStore.Profile } = {}

local DataService = {}

local function load(player: Player)
	if profiles[player] or not store then
		return
	end
	local profile = store:StartSessionAsync(tostring(player.UserId), {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if not profile then
		player:Kick("Could not load your data. Please rejoin.")
		return
	end
	profile:AddUserId(player.UserId)
	profile:Reconcile()
	if not PlayerData.isValid(profile.Data) then
		-- Never run with data we cannot trust.
		profile:EndSession()
		player:Kick("Your data could not be read. Please rejoin or contact support.")
		return
	end
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		player:Kick("Your data was loaded somewhere else. Please rejoin.")
	end)
	if player.Parent ~= Players then
		profile:EndSession() -- the player left while loading
		return
	end
	profiles[player] = profile
	player:SetAttribute("Points", profile.Data.points)
end

-- The live save table for a player, or nil while loading or after they leave.
function DataService.get(player: Player): PlayerData.Data?
	local profile = profiles[player]
	return if profile then (profile.Data :: any) else nil
end

-- Server-only: add points, keep the attribute in sync. Returns true if points were added.
function DataService.addPoints(player: Player, amount: number): boolean
	local data = DataService.get(player)
	if not data or not PlayerData.addPoints(data, amount) then
		return false
	end
	player:SetAttribute("Points", data.points)
	return true
end

-- Server-only: spend points all or nothing. Returns true if the player could afford it.
function DataService.spendPoints(player: Player, amount: number): boolean
	local data = DataService.get(player)
	if not data or not PlayerData.spendPoints(data, amount) then
		return false
	end
	player:SetAttribute("Points", data.points)
	return true
end

function DataService.init()
	store = ProfileStore.New("MogWarsPlayerData", PlayerData.template() :: any)
	Players.PlayerAdded:Connect(function(player)
		task.spawn(load, player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		local profile = profiles[player]
		if profile then
			profiles[player] = nil
			profile:EndSession()
		end
	end)
end

function DataService.start()
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
end

return DataService
