--!strict
-- Sends floating-number pop-ups to a player's screen ("+1,000 aura"). Server only. The client draws them
-- (PopupController); it never decides a number. Only a short fixed set of kinds is allowed: "points" and
-- "aura" carry an amount, "box" carries a count and a box tier id as `detail`.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PopupSystem = {}

local remote: RemoteEvent? = nil

local KINDS = { points = true, aura = true, box = true, splat = true, announce = true }

-- Show a pop-up to one player. Bad kinds and non-positive or non-finite amounts are ignored.
function PopupSystem.send(player: Player, kind: string, amount: number, detail: string)
	if remote == nil or not KINDS[kind] or amount ~= amount or amount <= 0 or amount == math.huge then
		return
	end
	remote:FireClient(player, kind, math.floor(amount), detail)
end

function PopupSystem.init()
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	local popup = Instance.new("RemoteEvent")
	popup.Name = "RewardPopup"
	popup.Parent = folder
	remote = popup
end

function PopupSystem.start() end

return PopupSystem
