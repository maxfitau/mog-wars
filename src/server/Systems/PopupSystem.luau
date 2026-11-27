--!strict
-- Sends floating-number pop-ups to a player's screen ("+1,000 aura"). Server only. The client draws them
-- (PopupController); it never decides a number. Only a short fixed set of kinds is allowed: "points" and
-- "aura" carry an amount, "box" carries a count and a box tier id as `detail`. "mogged" is the big MOGGED! pop-up,
-- "announce" a streak banner (the text is `detail`), "combo" the combo multiplier, "rush" AURA RUSH, "knockout" the
-- REDUCED TO NPC banner, "capture" a flag captured (screen punch) and "pickup" a pickup collected (name in `detail`).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Features = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Features"))

local PopupSystem = {}

local remote: RemoteEvent? = nil
local fxRemote: RemoteEvent? = nil

local KINDS = { points = true, aura = true, box = true, mogged = true, announce = true, combo = true, rush = true, knockout = true, capture = true, pickup = true, bonk = true, rankup = true, whoosh = true, crit = true, comboend = true, stolen = true, lost = true, levelup = true }

-- Show a pop-up to one player. Bad kinds and non-positive or non-finite amounts are ignored.
function PopupSystem.send(player: Player, kind: string, amount: number, detail: string)
	if (kind == "points" and not Features.mogPoints) or (kind == "box" and not Features.boxes) then
		return -- the old currency and loot boxes are switched off in the simple game
	end
	if remote == nil or not KINDS[kind] or amount ~= amount or amount <= 0 or amount == math.huge then
		return
	end
	remote:FireClient(player, kind, math.floor(amount), detail)
end

-- A visual effect for everyone (an ability burst, a flag capture burst...): kind, a position and one extra value.
function PopupSystem.fx(kind: string, position: Vector3, extra: any?)
	if fxRemote then
		fxRemote:FireAllClients(kind, position, extra)
	end
end

function PopupSystem.init()
	local created = Instance.new("RemoteEvent")
	created.Name = "WorldFx"
	created.Parent = ReplicatedStorage:FindFirstChild("Remotes") or ReplicatedStorage
	fxRemote = created
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
