--!strict
-- Tells the server you are really playing (a key, a click, a tap or a button), at most every couple of seconds, so you are not
-- marked AFK. It sends nothing else. The server rate limits it and also sees you walk.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Pace = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Pace"))

local ActivityPing = {}

function ActivityPing.init()
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ActivityPing") :: RemoteEvent
	local last = 0
	UserInputService.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseMovement or kind == Enum.UserInputType.Focus then
			return -- a wiggling mouse is not play
		end
		if os.clock() - last >= Pace.afk.pingSeconds then
			last = os.clock()
			remote:FireServer()
		end
	end)
end

function ActivityPing.start() end

return ActivityPing
