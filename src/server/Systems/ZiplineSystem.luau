--!strict
-- Rides the ziplines, reliably: the SERVER carries the player. Walk onto a platform (or press E / tap its prompt) and you
-- are attached, slide along the cable automatically, and are let go at the end (jump to let go early). While riding, the
-- server owns your character's physics (SetNetworkOwner nil), so it cannot be fought by lag or by the client. Each end of
-- a zipline is a start (tagged "ZiplineStart"), carrying the cable's StartPos and EndPos. Speed and cooldown: Pace.zipline.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Pace = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Pace"))
local Events = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("Events"))
local PopupSystem = require(script.Parent:WaitForChild("PopupSystem"))

local ZiplineSystem = {}

local startRemote: RemoteEvent? = nil
local busyUntil: { [Player]: number } = {}
local riding: { [Player]: boolean } = {}
local letGo: { [Player]: boolean } = {}

local function ride(player: Player, zone: BasePart)
	local startPos, endPos = zone:GetAttribute("StartPos"), zone:GetAttribute("EndPos")
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if riding[player] or typeof(startPos) ~= "Vector3" or typeof(endPos) ~= "Vector3" or not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		return
	end
	local now = Workspace:GetServerTimeNow()
	if now < (busyUntil[player] or 0) or (root.Position - zone.Position).Magnitude > 22 then
		return
	end
	local length = (endPos - startPos).Magnitude
	local seconds = length / Pace.zipline.speed
	busyUntil[player] = now + seconds + Pace.zipline.cooldownSeconds + 1
	riding[player] = true
	letGo[player] = false
	Events.fire(player, "zipline", 1)
	PopupSystem.fx("zipstart", startPos, nil)
	pcall(function()
		root:SetNetworkOwner(nil) -- the server drives the character while it rides
	end)
	humanoid.PlatformStand = true
	player:SetAttribute("Ziplining", true)
	if startRemote then
		startRemote:FireClient(player, startPos, endPos, Pace.zipline.speed)
	end
	local direction = (endPos - startPos).Unit
	local flat = Vector3.new(direction.X, 0, direction.Z)
	task.spawn(function()
		local travelled = 0
		local last = os.clock()
		-- hop onto the cable first
		while riding[player] and root.Parent and humanoid.Health > 0 and travelled < length and not letGo[player] do
			local t = os.clock()
			travelled += Pace.zipline.speed * (t - last)
			last = t
			local point = startPos + direction * math.min(travelled, length)
			local here = point - Vector3.new(0, 4.2, 0)
			root.CFrame = CFrame.lookAt(here, here + (if flat.Magnitude > 0.01 then flat else Vector3.zAxis))
			root.AssemblyLinearVelocity = Vector3.zero
			task.wait()
		end
		riding[player] = false
		if root.Parent then
			pcall(function()
				root:SetNetworkOwner(player)
			end)
			root.AssemblyLinearVelocity = direction * Pace.zipline.speed * 0.5 + Vector3.new(0, 8, 0)
		end
		humanoid.PlatformStand = false
		player:SetAttribute("Ziplining", false)
	end)
end

local function bind(zone: Instance)
	if not zone:IsA("BasePart") then
		return
	end
	zone.Touched:Connect(function(hit)
		local model = hit:FindFirstAncestorOfClass("Model")
		local player = if model then Players:GetPlayerFromCharacter(model) else nil
		if player then
			ride(player, zone)
		end
	end)
	local prompt = zone:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Triggered:Connect(function(player: Player)
			ride(player, zone)
		end)
	end
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
	startRemote = created
	local letGoRemote = Instance.new("RemoteEvent")
	letGoRemote.Name = "ZiplineLetGo"
	letGoRemote.Parent = folder
	letGoRemote.OnServerEvent:Connect(function(player: Player)
		letGo[player] = true -- jumping lets go early; the loop checks it
	end)
	Players.PlayerRemoving:Connect(function(player)
		busyUntil[player] = nil
		riding[player] = nil
		letGo[player] = nil
	end)
end

function ZiplineSystem.start()
	for _, zone in CollectionService:GetTagged("ZiplineStart") do
		bind(zone)
	end
	CollectionService:GetInstanceAddedSignal("ZiplineStart"):Connect(bind)
end

return ZiplineSystem
