--!strict
-- Rides the zipline when the server says so: this player's own character glides along the cable (hanging a little below
-- it) at a steady speed, then lets go with some forward momentum. Jump to let go early. Display and movement of your own
-- character only; the server decided that you may ride and where the cable goes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local ZiplineController = {}

local riding = false

function ZiplineController.init() end

function ZiplineController.start()
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ZiplineStart") :: RemoteEvent
	remote.OnClientEvent:Connect(function(startPos: any, endPos: any, speed: any)
		if riding or typeof(startPos) ~= "Vector3" or typeof(endPos) ~= "Vector3" or type(speed) ~= "number" or speed <= 0 or speed > 200 then
			return
		end
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not root or not root:IsA("BasePart") or not humanoid then
			return
		end
		riding = true
		local direction = (endPos - startPos).Unit
		local length = (endPos - startPos).Magnitude
		local travelled = 0
		humanoid.PlatformStand = true
		root.Anchored = true
		local connection: RBXScriptConnection? = nil
		local jump: RBXScriptConnection? = nil
		local function finish()
			if connection then
				connection:Disconnect()
			end
			if jump then
				jump:Disconnect()
			end
			root.Anchored = false
			humanoid.PlatformStand = false
			root.AssemblyLinearVelocity = direction * speed * 0.6 + Vector3.new(0, 10, 0) -- let go with some momentum
			riding = false
		end
		jump = UserInputService.JumpRequest:Connect(finish)
		connection = RunService.Heartbeat:Connect(function(dt)
			if not root.Parent then
				finish()
				return
			end
			travelled += speed * dt
			if travelled >= length then
				finish()
				return
			end
			local point = startPos + direction * travelled
			root.CFrame = CFrame.lookAt(point - Vector3.new(0, 4.2, 0), point - Vector3.new(0, 4.2, 0) + Vector3.new(direction.X, 0, direction.Z))
		end)
	end)
end

return ZiplineController
