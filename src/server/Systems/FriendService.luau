--!strict
-- Friend lookups for the server. Answers "are these two players Roblox friends?" from a cache, so the
-- squad bonus and faction choice never wait on the network. The cache is filled in the background when a
-- player joins (and on demand with refresh). An unknown pair counts as "not friends". Server only; it adds
-- no way for players to chat or contact each other.

local Players = game:GetService("Players")

local FriendService = {}

local cache: { [number]: { [number]: boolean } } = {}

local function store(a: number, b: number, value: boolean)
	cache[a] = cache[a] or {}
	cache[b] = cache[b] or {}
	cache[a][b] = value
	cache[b][a] = value
end

-- True only if the pair is known to be friends.
function FriendService.areFriends(a: Player, b: Player): boolean
	local known = cache[a.UserId]
	return known ~= nil and known[b.UserId] == true
end

-- Ask Roblox about every pair this player has not been checked against yet, in parallel. Yields for at
-- most `timeoutSeconds`. A failed lookup is simply skipped (the pair stays unknown).
function FriendService.refresh(player: Player, timeoutSeconds: number)
	local pending = 0
	for _, other in Players:GetPlayers() do
		local known = cache[player.UserId]
		if other ~= player and (known == nil or known[other.UserId] == nil) then
			pending += 1
			task.spawn(function()
				local ok, result = pcall(function()
					return player:IsFriendsWith(other.UserId)
				end)
				if ok then
					store(player.UserId, other.UserId, result == true)
				end
				pending -= 1
			end)
		end
	end
	local deadline = os.clock() + timeoutSeconds
	while pending > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
end

function FriendService.init()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(FriendService.refresh, player, 10)
	end)
	Players.PlayerRemoving:Connect(function(player)
		local known = cache[player.UserId]
		if known then
			for otherId in known do
				if cache[otherId] then
					cache[otherId][player.UserId] = nil
				end
			end
		end
		cache[player.UserId] = nil
	end)
end

function FriendService.start()
	for _, player in Players:GetPlayers() do
		task.spawn(FriendService.refresh, player, 10)
	end
end

return FriendService
