--!strict
-- The Training Arena. Treadmill belts (parts tagged "Treadmill") sit just outside each home base. The belt
-- pushes you backward, so you have to keep walking. Once a second, every player who is alive, standing on a
-- treadmill and actually moving earns one stride; strides fill training levels, and each level raises aura
-- power. Counting is server only, limited to 10 minutes a day, and training can never be bought.
-- The "TrainingActive" attribute tells the client whether strides are counting right now.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TrainingRules = require(Shared:WaitForChild("TrainingRules"))
local ZoneGeometry = require(Shared:WaitForChild("ZoneGeometry"))
local DataService = require(script.Parent:WaitForChild("DataService"))

local TICK_SECONDS = 1
local HEADROOM = 6 -- studs above the belt that still count as standing on it

local TrainingSystem = {}

local function onTreadmill(root: BasePart): boolean
	for _, belt in CollectionService:GetTagged("Treadmill") do
		if belt:IsA("BasePart") then
			local offset = belt.CFrame:PointToObjectSpace(root.Position)
			if ZoneGeometry.contains(offset.X, offset.Y, offset.Z, belt.Size.X, belt.Size.Y, belt.Size.Z, HEADROOM) then
				return true
			end
		end
	end
	return false
end

local function setBeltSpeed(belt: Instance)
	if belt:IsA("BasePart") then
		local push = belt:GetAttribute("BeltPush")
		belt.AssemblyLinearVelocity = Vector3.new(0, 0, if type(push) == "number" then push else 0)
	end
end

local function step()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local active = false
		if humanoid and root and root:IsA("BasePart") then
			active = TrainingRules.isRunning(humanoid.MoveDirection.Magnitude, onTreadmill(root), humanoid.Health > 0)
		end
		if active then
			DataService.addTrainingStride(player)
		end
		if player:GetAttribute("TrainingActive") ~= active then
			player:SetAttribute("TrainingActive", active)
		end
	end
end

function TrainingSystem.init()
	for _, belt in CollectionService:GetTagged("Treadmill") do
		setBeltSpeed(belt)
	end
	CollectionService:GetInstanceAddedSignal("Treadmill"):Connect(setBeltSpeed)
end

function TrainingSystem.start()
	task.spawn(function()
		while true do
			task.wait(TICK_SECONDS)
			step()
		end
	end)
end

return TrainingSystem
