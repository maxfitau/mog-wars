--!strict
-- Slice 8: rank-up requests. The client sends a bare "RankUpRequest" with no data. The server checks the
-- request rate, then DataService.tryRankUp decides (enough points, not at the top rank) and changes
-- points, rank and the reward box together, or not at all. The result goes back as "RankUpResult".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local DataService = require(script.Parent:WaitForChild("DataService"))

local MIN_INTERVAL = 0.5 -- seconds between requests from one player; faster ones are ignored

local RankSystem = {}
local lastRequest: { [Player]: number } = {}

function RankSystem.init()
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	local request = Instance.new("RemoteEvent")
	request.Name = "RankUpRequest"
	request.Parent = folder
	local result = Instance.new("RemoteEvent")
	result.Name = "RankUpResult"
	result.Parent = folder

	request.OnServerEvent:Connect(function(player: Player)
		-- No arguments are read.
		local now = Workspace:GetServerTimeNow()
		if now - (lastRequest[player] or -1000) < MIN_INTERVAL then
			return
		end
		lastRequest[player] = now
		local ok, reason = DataService.tryRankUp(player)
		result:FireClient(player, ok, reason or "")
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

function RankSystem.start() end

return RankSystem
