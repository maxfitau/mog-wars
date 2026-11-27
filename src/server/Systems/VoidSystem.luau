--!strict
-- Falling off an island: you drop into the clouds, a quick "WHOOSH!", and you respawn at your team island after 2 seconds.
-- No damage. Shove can knock people off edges, which is the point. Server only; bots that fall pop back at their base.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Pace = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Pace"))
local BotService = require(script.Parent:WaitForChild("BotService"))
local PopupSystem = require(script.Parent:WaitForChild("PopupSystem"))
local StealSystem = require(script.Parent:WaitForChild("StealSystem"))

local VoidSystem = {}

local falling: { [Player]: boolean } = {}

function VoidSystem.init()
	pcall(function()
		Players.RespawnTime = Pace.void.respawnSeconds
	end)
	Players.PlayerRemoving:Connect(function(player)
		falling[player] = nil
	end)
end

function VoidSystem.start()
	task.spawn(function()
		while true do
			task.wait(0.25)
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 and root.Position.Y < Pace.void.killY and not falling[player] then
					falling[player] = true
					StealSystem.onFall(player) -- if someone pushed you off, they steal some of your war aura
					PopupSystem.send(player, "whoosh", 1, "")
					humanoid.Health = 0 -- FactionSystem puts you back at your team island after the respawn time
					task.delay(Pace.void.respawnSeconds + 1, function()
						falling[player] = nil
					end)
				end
			end
			for _, bot in BotService.list() do
				if bot.root.Position.Y < Pace.void.killY then
					BotService.respawn(bot, 1)
				end
			end
		end
	end)
end

return VoidSystem
