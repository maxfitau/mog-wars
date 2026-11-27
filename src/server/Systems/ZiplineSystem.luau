--!strict
-- Starts zipline rides. A zipline's start handle (tagged "ZiplineStart") carries a prompt and the cable's two end points
-- (StartPos and EndPos). When a player triggers it, the server checks the rate, that they are alive and close, and then
-- tells THAT player's screen to carry them along the cable ("ZiplineStart"). The end points always come from the server's
-- own data, never from the client.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Pace = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Pace"))

local ZiplineSystem = {}

local remote: RemoteEvent? = nil
local busyUntil: { [Player]: number } = {}

local function bind(handle: Instance)
	if not handle:IsA("BasePart") then
		return
	end
	local prompt = handle:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		return
	end
	prompt.Triggered:Connect(function(player: Player)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local startPos, endPos = handle:GetAttribute("StartPos"), handle:GetAttribute("EndPos")
		if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 or typeof(startPos) ~= "Vector3" or typeof(endPos) ~= "Vector3" then
			return
		end
		local now = Workspace:GetServerTimeNow()
		if now < (busyUntil[player] or 0) or (root.Position - handle.Position).Magnitude > 20 then
			return
		end
		local seconds = (endPos - startPos).Magnitude / Pace.zipline.speed
		busyUntil[player] = now + seconds + Pace.zipline.cooldownSeconds
		if remote then
			remote:FireClient(player, startPos, endPos, Pace.zipline.speed)
		end
	end)
end

function ZiplineSystem.init()
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	local created = Instance.new("RemoteEvent")
	created.Name = "ZiplineStart"
	created.Parent = folder
	remote = created
	Players.PlayerRemoving:Connect(function(player)
		busyUntil[player] = nil
	end)
end

function ZiplineSystem.start()
	for _, handle in CollectionService:GetTagged("ZiplineStart") do
		bind(handle)
	end
	CollectionService:GetInstanceAddedSignal("ZiplineStart"):Connect(bind)
end

return ZiplineSystem
