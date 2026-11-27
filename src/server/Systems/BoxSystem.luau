--!strict
-- Slice 9: opening boxes. The client sends "OpenBoxRequest" with only a tier name. The server ignores
-- anything else, limits how fast requests can come, checks the tier exists and the player owns a box, then
-- rolls with the same table the client shows as odds. The outcome goes back as "OpenBoxResult".
-- Boxes are earned only (rank-ups and wars); nothing here or anywhere sells a box for Robux.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local DataService = require(script.Parent:WaitForChild("DataService"))

local MIN_INTERVAL = 0.5 -- seconds between requests from one player

local BoxSystem = {}
local lastRequest: { [Player]: number } = {}
local rng = Random.new()

local function random(): number
	return rng:NextNumber()
end

function BoxSystem.init()
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	local request = Instance.new("RemoteEvent")
	request.Name = "OpenBoxRequest"
	request.Parent = folder
	local result = Instance.new("RemoteEvent")
	result.Name = "OpenBoxResult"
	result.Parent = folder

	request.OnServerEvent:Connect(function(player: Player, tierId: any)
		local now = Workspace:GetServerTimeNow()
		if now - (lastRequest[player] or -1000) < MIN_INTERVAL then
			return
		end
		lastRequest[player] = now
		local outcome = DataService.openBox(player, tierId, random)
		result:FireClient(player, outcome.ok, outcome.reason, outcome.tier, outcome.kind, outcome.id, outcome.amount)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

function BoxSystem.start() end

return BoxSystem
